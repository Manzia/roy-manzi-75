//
//  MzProductCollection.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 5/30/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzProductCollection.h"
#import "Logging.h"
#import "RecursiveDeleteOperation.h"
#import "RetryingHTTPOperation.h"
#import "MzProductCollectionContext.h"
#import "NetworkManager.h"
#import "MzCollectionParserOperation.h"
#import "MzProductItem.h"

#define kActiveCollectionCachesLimit 2              // Max no of collections
#define kAutoSaveContextChangesTimeInterval 5.0     // 5 secs to auto-save
#define kTimeIntervalToRefreshCollection 600        // 10mins to auto-refresh
#define kDefaultRelativePath "default"

@interface MzProductCollection() 

// private properties
@property (nonatomic, copy, readwrite) NSString *collectionURLString;
@property (nonatomic, retain, readwrite)NSEntityDescription *productItemEntity;
@property (nonatomic, retain, readwrite)MzProductCollectionContext* productCollectionContext;
@property (nonatomic, copy, readonly) NSString *collectionCachePath;
@property (nonatomic, assign, readwrite) ProductCollectionSyncState stateOfSync;
@property (nonatomic, retain, readwrite) NSTimer *timeToSave;
@property (nonatomic, retain, readwrite) NSTimer *timeToRefresh;
@property (nonatomic, copy, readwrite) NSDate *dateLastSynced;
@property (nonatomic, copy, readwrite) NSError *errorFromLastSync;
@property (nonatomic, retain, readwrite) RetryingHTTPOperation *getCollectionOperation;
@property (nonatomic, retain, readwrite) MzCollectionParserOperation *parserOperation;

// This property will hold the value of the relativePath that was appended to
// the collectionURLString to create the NSURLRequest for the HTTP GET
@property (nonatomic, copy, readwrite) NSString * variableRelativePath;

// Keys are relativePaths and values are an array of old parserResults
// and time parseOperation completed
@property (retain, readonly) NSMutableDictionary *pathsOldResults;

// forward declarations

- (void)startParserOperationWithData:(NSData *)data;
- (void)commitParserResults:(NSArray *)latestResults;

@end

@implementation MzProductCollection

// Synthesize properties
@synthesize collectionURLString;
@synthesize productItemEntity;
@synthesize productCollectionContext;
@synthesize collectionCachePath;
@synthesize stateOfSync;
@synthesize timeToSave;
@synthesize dateFormatter;
@synthesize dateLastSynced;
@synthesize errorFromLastSync;
@synthesize getCollectionOperation;
@synthesize parserOperation;
@synthesize pathsOldResults;
@synthesize variableRelativePath;
@synthesize timeToRefresh;
@synthesize synchronizing;


// Other Getters
-(id)managedObjectContext
{
    return self.productCollectionContext;
}

//Override getter and maintain KVC compliance
- (NSString *)collectionCachePath
{
    assert(self.productCollectionContext != nil);
    return self.productCollectionContext.collectionCachePath;
}



// Changes in the productCollectionContext property will trigger
// KVO notifications to observers of managedObjectContext property
+ (NSSet *)keyPathsForValuesAffectingManagedObjectContext
{
    return [NSSet setWithObject:@"productCollectionContext"];
}

// Format for the ProductCollection Cache directory
static NSString * kCollectionNameTemplate = @"Collection%.9f.%@";

// Extension for the ProductCollection Cache directory
static NSString * kCollectionExtension    = @"collection";

/* Each ProductCollection Cache directory has the following files
 1- A plist file that indicates whether or not this ProductCollection has been
 abandoned (and thus removed at app startup or terminate).

 The plist file has one property defined, which is the last URL string used to
 GET the ProductCollection XML file. There may be hundreds of ProductItems within
 a ProductCollection but each downloaded XML file has a fixed number of 12 ProductItems.
 - A new GETOperation is executed to get the another XML file with the next batch of
 12 ProductItems using a URL string with a COUNTER parameter that is incremented with
 each GETOperation
 - with each GETOperation the URL string in this plist file is overidden as such the value
 of the single plist file property will always be the last URL string the GETOperation
 executed or the initial URL String prior to any GETOperation.
 */
static NSString * kCollectionFileName = @"ProductCollectionInfo.plist";
static NSString * kCollectionKeyCollectionURLString = @"collectionURLString";

// 2- A Core Data file that holds the ProductItem and ThumbNail model objects
static NSString * kCollectionDataFileName    = @"Collection.db";

// 3- A directory containing the full-size Product Images
NSString * kProductImagesDirectoryName = @"ProductImages";

#pragma mark * Initialization

// Initialize a MzProductCollection model object
- (id)initWithCollectionURLString:(NSString *)collectURLString
{
    assert(collectURLString != nil);
        
    self = [super init];
    if (self != nil) {
        self.collectionURLString = collectURLString;
        pathsOldResults = [[NSMutableDictionary alloc] init];
        assert(pathsOldResults!=nil);
        self->variableRelativePath = @"default";
                        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        [[QLog log] logWithFormat:@"Collection cache instantiated with URL: %@", collectURLString];
    }
    return self;
}

#pragma mark * Collection CacheDirectory Managemnt

// Returns a path to the CachesDirectory
+ (NSString *)pathToCachesDirectory
{
    NSString *cacheDir;
    NSArray *cachesPaths;
    
    cacheDir = nil;
    cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ( (cachesPaths != nil) && ([cachesPaths count] != 0) ) {
        assert([[cachesPaths objectAtIndex:0] isKindOfClass:[NSString class]]);
        cacheDir = [cachesPaths objectAtIndex:0];
    }
    return cacheDir;
}

// Marks for removal a ProductCollection cache at a given path
+ (void)markForRemoveCollectionCacheAtPath:(NSString *)collectionPath
{
    (void) [[NSFileManager defaultManager] removeItemAtPath:[collectionPath stringByAppendingPathComponent:kCollectionFileName] error:NULL];
}

// Method called in the App Delegate's applicationDidEnterBackground method
// Note that because the DELETEOperation is started while in the Background and
// may not run until the applicationDidEnterBackground method exits, we request
// extra time from the system via the beginBackgroundTaskWithExpirationHandler method
+(void)applicationInBackground
{
    NSUserDefaults *    userDefaults;
    NSFileManager *     fileManager;
    BOOL                clearCollectionCaches;
    NSString *          cachesDirectoryPath;
    NSArray *           possibleCollectionCacheNames;
    NSMutableArray *    collectionCachePathsToDelete;
    NSMutableArray *    activeCollectionCachePathsAndDates;
    
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    
    userDefaults = [NSUserDefaults standardUserDefaults];
    assert(userDefaults != nil);
    
    cachesDirectoryPath = [self pathToCachesDirectory];
    assert(cachesDirectoryPath != nil);
    
    // Check if the user has selected the clear all caches option.
    
    clearCollectionCaches = [userDefaults boolForKey:@"collectionClearCache"];
    if (clearCollectionCaches) {
        [[QLog log] logWithFormat:@"Clear Collection caches"];
        
        [userDefaults removeObjectForKey:@"collectionClearCache"];
        
        // write modifications to disk
        [userDefaults synchronize]; 
    }
    
    /*
     Add all the ProductCollection cache directory to the array of caches to
     delete if user had selected the Clear Caches option or else
     1- enumerate through all the Collection cache directories
     2- add any Collection cache directory missing the corresponding plist file
     to the array of caches to delete
     3- create a list with the paths and modified dates for the remaining
     Collection cache directories
     */
    
    collectionCachePathsToDelete = [NSMutableArray array];
    assert(collectionCachePathsToDelete != nil);
    
    possibleCollectionCacheNames = [fileManager contentsOfDirectoryAtPath:cachesDirectoryPath error:NULL];
    assert(possibleCollectionCacheNames != nil);
    
    activeCollectionCachePathsAndDates = [NSMutableArray array];
    assert(activeCollectionCachePathsAndDates != nil);
    
    // Enumerate through all the ProductCollection Cache directories
    
    for (NSString * collectionCacheName in possibleCollectionCacheNames) {
        if ([collectionCacheName hasSuffix:kCollectionExtension]) {
            NSString *collectionPath;      // ProductCollection cache directory name
            NSString *collectionInfoFilePath;   // associated plist file
            NSString *collectionDataFilePath;   // associated Core data file
            
            collectionPath = [cachesDirectoryPath stringByAppendingPathComponent:collectionCacheName];
            assert(collectionPath != nil);
            
            collectionInfoFilePath = [collectionPath stringByAppendingPathComponent:kCollectionFileName];
            assert(collectionInfoFilePath != nil);
            
            collectionDataFilePath = [collectionPath stringByAppendingPathComponent:kCollectionDataFileName];
            assert(collectionDataFilePath != nil);
            
            if (clearCollectionCaches) {
                [[QLog log] logWithFormat:@"Clear Collection Cache: '%@'", collectionCacheName];
                (void) [fileManager removeItemAtPath:collectionInfoFilePath error:NULL];
                [collectionCachePathsToDelete addObject:collectionPath];
            } else if ( ! [fileManager fileExistsAtPath:collectionInfoFilePath]) {
                [[QLog log] logWithFormat:@"Collection cache already marked for delete: '%@'", collectionCacheName];
                [collectionCachePathsToDelete addObject:collectionPath];
            } else {
                
                /*
                 1- Get the modified date of the Core Data file of the surviving Collection
                 caches
                 2- Mark the Collection cache for deletion if setp 1 fails otherwise add the
                 Collection cache's path and modified date to the activeCollectionCachePathsAndDates dictionary
                 */
                NSDate *modifiedDate;
                
                modifiedDate = [[fileManager attributesOfItemAtPath:collectionDataFilePath error:NULL] objectForKey:NSFileModificationDate];
                if (modifiedDate == nil) {
                    [[QLog log] logWithFormat:@"Collection Cache database invalid: '%@'", collectionCacheName];
                    [collectionCachePathsToDelete addObject:collectionPath];
                } else {
                    assert([modifiedDate isKindOfClass:[NSDate class]]);
                    [activeCollectionCachePathsAndDates addObject:
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         collectionPath, @"collectionPath", modifiedDate, @"modifiedDate",nil]];
                }
            }
        }
    }
    
    // Mark the oldest Collection cache directories for deletion until we are under the
    // Collection Cache limit - kActiveCollectionCachesLimit
    
    [activeCollectionCachePathsAndDates sortUsingDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"modifiedDate" ascending:YES]]];
    while ([activeCollectionCachePathsAndDates count] > kActiveCollectionCachesLimit) {
        
        NSString *collectionPath;
        collectionPath = [[activeCollectionCachePathsAndDates objectAtIndex:0] objectForKey:@"collectionPath"];
        assert([collectionPath isKindOfClass:[NSString class]]);
        
        [[QLog log] logWithFormat:@"Stale Collection Cache marked for delete: '%@'", [collectionPath lastPathComponent]];
        
        [self markForRemoveCollectionCacheAtPath:collectionPath];
        [collectionCachePathsToDelete addObject:collectionPath];
        [activeCollectionCachePathsAndDates removeObjectAtIndex:0];
    }
    
    /*
     As a final step:
     1- start an NSOperation to delete the marked Collection caches
     2- the DELETE operation is run on secondary Thread when the App is moved to
     the Background
     3- On completion the DELETE operation will just quit
     4- While in Background, we have 5 seconds to complete the DELETE operation so in
     order to be a good memory citizen we ask the system for more time since there is 
     a chance the secondary thread will not run until the App Delegate's 
     applicationDidEnterBackground method exits.
     5- Collections caches not deleted on the first pass will be deleted the next time
     the app is moved into the Background.
     */
    
    if ( [collectionCachePathsToDelete count] != 0 ) {
        static NSOperationQueue *collectionDeleteQueue;
        RecursiveDeleteOperation *operation;
        
        collectionDeleteQueue = [[NSOperationQueue alloc] init];
        assert(collectionDeleteQueue != nil);
        
        operation = [[RecursiveDeleteOperation alloc] initWithPaths:collectionCachePathsToDelete];
        assert(operation!= nil);
        
        if ( [operation respondsToSelector:@selector(setThreadPriority:)] ) {
            [operation setThreadPriority:0.1];
        }
        
        [collectionDeleteQueue addOperation:operation];
    }
  
}

#pragma mark * ProductCollection lifecycle Management

// Method that is called when application is transitioning to the ACTIVE state
- (void)appDidBecomeActive:(NSNotification *)notification
{
#pragma unused(notification)
    
     if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"collectionSyncOnActivate"] ) {
        if (self.productCollectionContext != nil) {
            [self startSynchronization:variableRelativePath];
        }
    }
}

#pragma mark * Core Data Management
// Override synthesized Getter for the productItemEntity property
- (NSEntityDescription *)productItemEntity
{
    if (self->productItemEntity == nil) {
        assert(self.productCollectionContext != nil);
        self->productItemEntity = [NSEntityDescription entityForName:@"MzProductItem" inManagedObjectContext:self.productCollectionContext];
        assert(self->productItemEntity != nil);
    }
    return self->productItemEntity;
}

// Method to return all stored ProductItems (MzProductItem objects)
- (NSFetchRequest *)productItemsFetchRequest
{
    NSFetchRequest *    fetchRequest;    
    fetchRequest = [[NSFetchRequest alloc] init];
    assert(fetchRequest != nil);
    
    [fetchRequest setEntity:self.productItemEntity];
    [fetchRequest setFetchBatchSize:20];
    
    return fetchRequest;
}

// Finds the associated CollectionCache(Path) given a CollectionURLString and
// creates a new CollectionCache if none is found
- (NSString *)findCacheForCollectionURLString
{
    NSString *searchResult;
    NSFileManager *fileManager;
    NSString *cachesDirectory;
    NSArray *possibleCollections;
    NSString *collectionName;
    
    assert(self.collectionURLString != nil);
    
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    
    cachesDirectory = [[self class] pathToCachesDirectory];
    assert(cachesDirectory != nil);
    
    // Iterate through the Caches Directory and sub-Directories and check each plist
    // file encountered
        
    possibleCollections = [fileManager contentsOfDirectoryAtPath:cachesDirectory error:NULL];
    assert(possibleCollections != nil);
    
    searchResult = nil;
    for (collectionName in possibleCollections) {
        if ([collectionName hasSuffix:kCollectionExtension]) {
            
            NSDictionary *collectionInfo;
            NSString *collectionInfoURLString;
            
            collectionInfo = [NSDictionary dictionaryWithContentsOfFile:[[cachesDirectory stringByAppendingPathComponent:collectionName] stringByAppendingPathComponent:kCollectionFileName]];
            if (collectionInfo != nil) {
                collectionInfoURLString = [collectionInfo objectForKey:kCollectionKeyCollectionURLString];
                if ( [self.collectionURLString isEqual:collectionInfoURLString] ) {
                    searchResult = [cachesDirectory stringByAppendingPathComponent:collectionName];
                    break;
                }
            }
        }
    }
    // The Caches Directories and sub-directories do not contain a CollectionCache
    // corresponding to the given CollectionURLString, so create a new CollectionCache
    // and associate it with the given CollectionURLString
    
    if (searchResult == nil) {
        BOOL success;
        
        collectionName = [NSString stringWithFormat:kCollectionNameTemplate, [NSDate timeIntervalSinceReferenceDate], kCollectionExtension];
        assert(collectionName != nil);
        
        searchResult = [cachesDirectory stringByAppendingPathComponent:collectionName];
        success = [fileManager createDirectoryAtPath:searchResult withIntermediateDirectories:NO attributes:NULL error:NULL];
        if (success) {
            NSDictionary *collectionInfoFile;
            
            collectionInfoFile = [NSDictionary dictionaryWithObjectsAndKeys:self.collectionURLString, kCollectionKeyCollectionURLString, nil];
            assert(collectionInfoFile != nil);
            
            success = [collectionInfoFile writeToFile:[searchResult stringByAppendingPathComponent:kCollectionFileName] atomically:YES];
        }
        if (!success) {
            searchResult = nil;
        }
        
        [[QLog log] logWithFormat:@"New Collection Cache created: '%@'", collectionName];
    } else {
        assert(collectionName != nil);
        [[QLog log] logWithFormat:@"Found existing Collection Cache '%@'",collectionName];
    }
    
    return searchResult;
}

/* Private, instance-specific method version of the markForRemoveCollectionCacheAtPath: class method. The CollectionCache marked for deletion will be deleted when the application is moved to the background
 */
- (void)markForRemoveCollectionCacheAtPath:(NSString *)collectionPath
{
    assert(collectionPath != nil);
    
    [[QLog log] logWithFormat:@"Mark Collection Cache for deletion '%@'", [collectionPath lastPathComponent]];
    
    [[self class] markForRemoveCollectionCacheAtPath:collectionPath];
}

/*
 Start up the Collection Cache for the collectionURLString property. This method also sets
 the productCollectionContext and collectionCachePath properties to point to the Collection Cache started up 
 */
- (BOOL)setupProductCollectionContext
{
    BOOL success;
    NSError *error;
    NSFileManager *fileManager;
    NSString *collectionPath;
    NSString *productImagesDirectoryPath;
    BOOL isDir;
    NSURL *collectionDbURL;
    NSManagedObjectModel *collectionModel;
    NSPersistentStoreCoordinator *persistentCoordinator;
    
    assert(self.collectionURLString != nil);
    
    [[QLog log] logWithFormat:@"Starting Collection Cache for URL: %@", self.collectionURLString];
    
    error = nil;
    
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    
    // Find the Collection Cache directory for this ProductCollection.
    
    collectionPath = [self findCacheForCollectionURLString];
    success = (collectionPath != nil);
    
    // Create the ProductImages directory if it doesn't already exist.
    
    if (success) {
        productImagesDirectoryPath = [collectionPath stringByAppendingPathComponent:kProductImagesDirectoryName];
        assert(productImagesDirectoryPath != nil);
        
        success = [fileManager fileExistsAtPath:productImagesDirectoryPath isDirectory:&isDir] && isDir;
        if (!success) {
            success = [fileManager createDirectoryAtPath:productImagesDirectoryPath withIntermediateDirectories:NO attributes:NULL error:NULL];
        }
    }
    
    // Start up CoreData in the Collection Cache directory.
    
    if (success) {
        NSString *collectionModelPath;
        
        collectionModelPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"ProductItems" ofType:@"mom"];
        assert(collectionModelPath != nil);
        
        collectionModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:collectionModelPath]];
        success = (collectionModel != nil);
    }
    if (success) {
        collectionDbURL = [NSURL fileURLWithPath:[collectionPath stringByAppendingPathComponent:kCollectionDataFileName]];
        assert(collectionDbURL != nil);
        
        persistentCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:collectionModel];
        success = (persistentCoordinator != nil);
    }
    if (success) {
        success = [persistentCoordinator addPersistentStoreWithType:NSSQLiteStoreType 
                                    configuration:nil 
                                              URL:collectionDbURL
                                          options:nil 
                                            error:&error] != nil;
        if (success) {
            error = nil;
        }
    }
    
    // Create a managed Object Context from the created persistent store
    if (success) {
        MzProductCollectionContext *collectionContext;
        
        collectionContext = [[MzProductCollectionContext alloc] initWithCollectionURLString:self.collectionURLString cachePath:collectionPath];
        assert(collectionContext != nil);
        
        [collectionContext setPersistentStoreCoordinator:persistentCoordinator];
        self.productCollectionContext = collectionContext;
        
        // Subscribe to the context changed notification so that we can auto-save.
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(collectionContextChanged:) name:NSManagedObjectContextObjectsDidChangeNotification object:self.managedObjectContext];
        
        [[QLog log] logWithFormat:@"Collection started successfully at Path: '%@' for URL: %@", [self.collectionCachePath lastPathComponent], self.collectionURLString];
    } else {
        
        // Log the error and return NO.
        
        if (error == nil) {
            [[QLog log] logWithFormat:@"Error starting Collection Cache with URL: %@", self.collectionURLString];
        } else {
            [[QLog log] logWithFormat:@"Logged error starting Collection Cache %@ with URL: %@", error, self.collectionURLString];
        }
        
        //Mark for deletion Collection caches that we tried and failed to start-up
        
        if (collectionPath != nil) {
            [self markForRemoveCollectionCacheAtPath:collectionPath];
        }
    }
    return success;
}

// Start the Collection Cache, create any needed files/directories if necessary
- (void)startCollection
{
    BOOL success;
    
    assert(self.collectionURLString != nil);
    
    // Start up the Collection Cache.  Abandon the Collection, and retry once more
    // on initial failure
        
    success = [self setupProductCollectionContext];
    if ( ! success ) {
        [[QLog log] logWithFormat:@"Retry startup of Collection Cache with URL: %@", self.collectionURLString];
        success = [self setupProductCollectionContext];
    }
    
    // Start the synchronization process otherwise the application is dead 
    // and we crash.
    
    if (success) {
        [self startSynchronization:self.variableRelativePath];
        
        // start the Refresh Timer
        self.timeToRefresh = [NSTimer scheduledTimerWithTimeInterval:kTimeIntervalToRefreshCollection target:self selector:@selector(refreshCollection) userInfo:nil repeats:YES];
        assert([self.timeToRefresh isValid]);
    } else {
        abort();
    }
}

// Refresh the collection - method called by RefreshTimer
- (void)refreshCollection 
{
    /*
     Because the RefreshTimer is set to fire after 10mins, productItems will be
     refreshed in database in the time range > 10 minutes. We simply choose the "oldest"
     relativePath (i.e, the relativePath associated with the oldest parserResults)
     for the refresh operation. We also check that the relativePath is at least 10mins
     "old" before we hit the network.
     
     NOTE: Its likely most users will not keep a particular collection active for more
     than 10 mins, but if they do we need to refresh the collection since productItem
     attributes like price and availability change very quickly and often.
     */
    
    //Refresh only if we are not already syncing to avoid potential conflict with
    // the MzProductCollectionViewController - checked in startSynchronization method
    
    assert(pathsOldResults != nil);
    
    // Check that we have more than 1 entry in the pathsOldResults map. If only 1 entry,
    // don't bother looking for the "oldest" and just refresh that entry
    if ([pathsOldResults count] > 1) {
        
        [[QLog log] logWithFormat:@"Start Refresh of Collection Cache with URL: %@", self.collectionURLString];
        
        NSString *pathToRefresh;
        NSArray * pathsValues;
        NSString *pathKey;
        NSArray *oldestKey;
        
        //keep track of which dates associate with which paths
        NSMutableDictionary *pathsToDates;             
        pathsToDates = [NSMutableDictionary dictionary];
        assert(pathsToDates != nil);
        
                                
        //Enumerate and create a relativePath to date map
        NSEnumerator *pathEnumerator;
        pathEnumerator = [pathsOldResults keyEnumerator];
        assert(pathEnumerator != nil);
        
        while (pathKey = [pathEnumerator nextObject]) {
            [pathsToDates setObject:[[pathsOldResults objectForKey:pathKey] lastObject] forKey:pathKey];
            
        }
        
        // Sort by the Date values
        pathsValues = [pathsToDates allValues];
        assert(pathsValues != nil);
        assert([pathsValues count] > 0);
        [pathsValues sortedArrayUsingComparator:^(id obj1, id obj2) {
            return [obj1 compare:obj2];
        }];
        
        // Check that the oldest Date value is more than kTimeIntervalToRefreshCollection
        // so we do not waste time hitting the network
        NSDate *currentTime;
        currentTime = [NSDate date];
        assert(currentTime!= nil);
        
        if ([currentTime timeIntervalSinceDate:[pathsValues objectAtIndex:0]] > kTimeIntervalToRefreshCollection) {
            
            // Get the "oldest" key - associated with earliest parserResult
            oldestKey = [pathsToDates allKeysForObject:[pathsValues objectAtIndex:0]];
            assert(oldestKey != nil);
            assert([oldestKey count] == 1);
            pathToRefresh = [oldestKey objectAtIndex:0];
            assert(pathToRefresh!= nil);
            
            // we can now start synchronization to Refresh
            [self startSynchronization:pathToRefresh];

        } else {
            // Ignore the Refresh
            [[QLog log] logWithFormat:@"Too soon to Refresh Collection Cache with URL: %@", self.collectionURLString];
        }
        
        
    } else {
        // We have 0 or 1 entry in the pathsOldResults map
        if ([pathsOldResults count] > 0) {
            
            [[QLog log] logWithFormat:@"Start Refresh of Collection Cache with URL: %@", self.collectionURLString];
            
            NSString * pathToRefresh;
            NSArray *pathKeys;
            pathKeys = [pathsOldResults allKeys];
            assert(pathKeys != nil);
            pathToRefresh = [pathKeys lastObject];
            assert(pathToRefresh != nil);
            
            // Refresh
            [self startSynchronization:pathToRefresh];
        } else {
            
            // Ignore Refresh
            [[QLog log] logWithFormat:@"Cannot Refresh Collection Cache with URL: %@", self.collectionURLString];
            return;
        }
        
    }
    
        
}

// Save the Collection Cache
- (void)saveCollection
{
    NSError *error = nil;
    
    // Typically this instance method will be called automatically after a preset
    // time interval in response to productCollectionContext changes, so we disable the 
    // auto-save before actually saving the Collection Cache.
    
    [self.timeToSave invalidate];
    self.timeToSave = nil;
    
    // Now save.
    
    if ( (self.productCollectionContext != nil) && [self.productCollectionContext hasChanges] ) {
        BOOL success;
        success = [self.productCollectionContext save:&error];
        if (success) {
            error = nil;
        }
    }
    
    // Log the results.
    
    if (error == nil) {
        [[QLog log] logWithFormat:@"Saved Collection Cache with URL: %@", self.collectionURLString];
    } else {
        [[QLog log] logWithFormat:@"Collection Cache save error: %@ with URL: %@", error, self.collectionURLString];
    }
}

// When the managed object context changes we start an automatic NSTimer to fire in
// kAutoSaveContextChangesTimeInterval
- (void)collectionContextChanged:(NSNotification *)note
{
#pragma unused(note)
    if (self.timeToSave != nil) {
        [self.timeToSave invalidate];
    }
    self.timeToSave = [NSTimer scheduledTimerWithTimeInterval:kAutoSaveContextChangesTimeInterval target:self selector:@selector(saveCollection) userInfo:nil repeats:NO];
}

// Closes access to the Collection Cache when a user switches to another ProductCollection
// or when the application is moved to the background
- (void)stopCollection
{
    [self stopSynchronization];
    
    // Shut down the managed object context.
    
    if (self.productCollectionContext != nil) {
        
        // Stop the auto save mechanism and then force a save.
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:self.productCollectionContext];
        
        [self saveCollection];
        
        self.productItemEntity = nil;
        self.productCollectionContext = nil;
        
        // Invalidate the Refresh Timer
        [self.timeToRefresh invalidate];
        self.timeToRefresh = nil;
    }
    [[QLog log] logWithFormat:@"Stopped Collection Cache with URL: %@", self.collectionURLString];
}

#pragma mark * Main Synchronization methods

// Register all the dependent properties/keys (on StateOfSync property) to enable
// KVO notifications for changes in any of these dependent properties
+ (NSSet *)keyPathsForValuesAffectingStatusOfSync
{
    return [NSSet setWithObjects:@"stateOfSync", @"errorFromLastSync", @"dateFormatter", @"dateLastSynced", @"getCollectionOperation.retryStateClient", nil];
}

// Override getter for the KVO-observable and User-Visible StatusOfSync property
- (NSString *)statusOfSync
{
    NSString *  syncResult;
    
    if (self.errorFromLastSync == nil) {
        switch (self.stateOfSync) {
            case ProductCollectionSyncStateStopped: {
                if (self.dateLastSynced == nil) {
                    syncResult = @"Not updated";
                } else {
                    syncResult = [NSString stringWithFormat:@"Updated: %@", [self.dateFormatter stringFromDate:self.dateLastSynced]];
                }
            } break;
            default: {
                if ( (self.getCollectionOperation != nil) && (self.getCollectionOperation.retryStateClient == kRetryingHTTPOperationStateWaitingToRetry) ) {
                    syncResult = @"Waiting for network";
                } else {
                    syncResult = @"Updating…";
                }
            } break;
        }
    } else {
        if ([[self.errorFromLastSync domain] isEqual:NSCocoaErrorDomain] && [self.errorFromLastSync code] == NSUserCancelledError) {
            syncResult = @"Update cancelled";
        } else {
            // At this point self.lastSyncError contains the actual error. 
            // However, we ignore that and return a very generic error status. 
            // Users don't understand "Connection reset by peer" anyway (-:
            syncResult = @"Update failed";
        }
    }
    return syncResult;
}

// Getter for the dateFormatter property that will change/update based on changes
// in the locale and timezone of the user - standard NSDateFormatter operations
- (NSDateFormatter *)dateFormatter
{
    if (self->dateFormatter == nil) {
        self->dateFormatter = [[NSDateFormatter alloc] init];
        assert(self->dateFormatter != nil);
        
        [self->dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [self->dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDateFormatter:) name:NSCurrentLocaleDidChangeNotification  object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDateFormatter:) name:NSSystemTimeZoneDidChangeNotification object:nil];
    }
    return self->dateFormatter;
}

// Called when either the current locale or the current time zone changes. 
- (void)updateDateFormatter:(NSNotification *)note
{
#pragma unused(note)
    NSDateFormatter *localDateFormatter;
    
    localDateFormatter = self.dateFormatter;
    [self willChangeValueForKey:@"dateFormatter"];
    [localDateFormatter setLocale:[NSLocale currentLocale]];
    [localDateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    [self didChangeValueForKey:@"dateFormatter"];
}

// Turn off auto-KVO notifications for the errorFromLastSync property
+ (BOOL)automaticallyNotifiesObserversOfErrorFromLastSync
{
    return NO;
}

// Override setter in order to log error
- (void)setErrorFromLastSync:(NSError *)newError
{
    assert([NSThread isMainThread]);
    
    if (newError != nil) {
        [[QLog log] logWithFormat:@"Collection Cache with URL: %@ got sync error: %@", self.collectionURLString, newError];
    }
    
    if (newError != self->errorFromLastSync) {
        [self willChangeValueForKey:@"errorFromLastSync"];
        self->errorFromLastSync = [newError copy];
        [self didChangeValueForKey:@"errorFromLastSync"];
    }
}

/* Method that starts an HTTP GET operation to retrieve the product collection's
 XML file. The method has a relativePath argument whose value will be  
 appended to the product collection's collectionURLString for the HTTP GET.
 
 The relativePath is primarily used by the MzProductCollectionViewController
 to HTTP GET more product items from the same product collection. Each HTTP GET
 operation will retrieve an XML file with details for 20 items, depending on the user's browsing, more items may need to be retrieved by passing a fileNumber=X paramter
 in the relativePath string that's appended to the collectionURLString.
 */

- (void)startGetOperation:(NSString *)relativePath
{
    NSMutableURLRequest *requestURL;
    
    assert(self.stateOfSync == ProductCollectionSyncStateStopped);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Start HTTP GET for Collection Cache with URL %@", self.collectionURLString];
    
    requestURL = [self.productCollectionContext requestToGetCollectionRelativeString:relativePath];
    assert(requestURL != nil);
    
    assert(self.getCollectionOperation == nil);
    self.getCollectionOperation = [[RetryingHTTPOperation alloc] initWithRequest:requestURL];
    assert(self.getCollectionOperation != nil);
    
    [self.getCollectionOperation setQueuePriority:NSOperationQueuePriorityNormal];
    self.getCollectionOperation.acceptableContentTypes = [NSSet setWithObjects:@"application/xml", @"text/xml", nil];
    
    [[NetworkManager sharedManager] addNetworkManagementOperation:self.getCollectionOperation finishedTarget:self action:@selector(getCollectionOperationComplete:)];
    
    self.stateOfSync = ProductCollectionSyncStateGetting;
    
    // Set the variableRelativePath property to keep track of the relativePaths
    self.variableRelativePath = relativePath;
}

// Starts an operation to parse the product collection's XML when the HTTP GET
// operation completes succesfully
- (void)getCollectionOperationComplete:(RetryingHTTPOperation *)operation
{
    NSError *error;
    
    assert([operation isKindOfClass:[RetryingHTTPOperation class]]);
    assert(operation == self.getCollectionOperation);
    assert(self.stateOfSync == ProductCollectionSyncStateGetting);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Completed HTTP GET operation for Collection Cache with URL: %@", self.collectionURLString];
    
    error = operation.error;
    if (error != nil) {
        self.errorFromLastSync = error;
        self.stateOfSync = ProductCollectionSyncStateStopped;
    } else {
        if ([QLog log].isEnabled) {
            [[QLog log] logOption:kLogOptionNetworkData withFormat:@"Receive XML %@", self.getCollectionOperation.responseContent];
        }
        [self startParserOperationWithData:self.getCollectionOperation.responseContent];
    }
    
    self.getCollectionOperation = nil;
}

- (void)startParserOperationWithData:(NSData *)data
// Starts the operation to parse the gallery's XML.
{
    assert(self.stateOfSync == ProductCollectionSyncStateGetting);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Start parse for Collection Cache with URL: %@", self.collectionURLString];
    
    assert(self.parserOperation == nil);
    self.parserOperation = [[MzCollectionParserOperation alloc] initWithXMLData:data];
    assert(self.parserOperation != nil);
    
    [self.parserOperation setQueuePriority:NSOperationQueuePriorityNormal];
    
    [[NetworkManager sharedManager] addCPUOperation:self.parserOperation finishedTarget:self action:@selector(parserOperationDone:)];
    
    self.stateOfSync = ProductCollectionSyncStateParsing;
}

// Method is called when the Collection ParserOperation completes and if successful
// commits the results to the Core Data database in our Collection Cache.
- (void)parserOperationDone:(MzCollectionParserOperation *)operation
{
    assert([NSThread isMainThread]);
    assert([operation isKindOfClass:[MzCollectionParserOperation class]]);
    assert(operation == self.parserOperation);
    assert(self.stateOfSync == ProductCollectionSyncStateParsing);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Parsing complete for Collection Cache with URL: %@", self.collectionURLString];
    
    if (operation.parseError != nil) {
        self.errorFromLastSync = operation.parseError;
        self.stateOfSync = ProductCollectionSyncStateStopped;
    } else {
        [self commitParserResults:operation.parseResults];
        
        assert(self.errorFromLastSync == nil);
        self.dateLastSynced = [NSDate date];
        self.stateOfSync = ProductCollectionSyncStateStopped;
        [[QLog log] logWithFormat:@"Successfully synced Collection Cache with URL: %@", self.collectionURLString];
        
                      
    }
    
    self.parserOperation = nil;
}

/*
 This method is called when the collectionRefreshTimer fires (every 5 minutes). The Timer
 is created and start in the startCollection method and removed in the stopCollection method
 The method does the following;
 1- iterates through all the stored relativePaths that were used to HTTP GET all the
 stored parserResults
 2- For each relativePath, lookup the Time the ParserOperation completed. If this Time is
 greater than 5 minutes ago, hit the network again and HTTP GET new parseResult using the
 same relativePath
 3- compare the new parseResult to the old parseResult, if there is no change, do nothing
 else, update, delete, insert productItem attributes accordingly
 4- Replace the old parseResult with the new parseResult and associate with the relativePath
 5- update the Time for the ParseOperation completion
 */


// Commit the parseResults to the Core Data database
- (void)commitParserResults:(NSArray *)parserResults
{
    /*
     At this point in the proceedings it is safe to assume that the value of variableRelativePath property corresponds to the parserResults we are being
     passed so we associate/map the relativePath to the parserResults & timestamp in
     either the pathsOldResults or pathsNewResults dictionaries depending on whether
     we seen this relativePath before.
     
     This enables us to periodically refresh the parserResults (after every 5-10 minutes)
     */
    
    assert(self.variableRelativePath != nil);
    assert(self.pathsOldResults != nil);
        
    NSArray *oldKeys = [pathsOldResults allKeys];
    assert(oldKeys != nil);
        
    /*
     We now do the following:
     1- check if there are any relative paths in BOTH the pathsOldResult and the pathsNewResult dictionaries AND the time interval between the creation time of the old and new parserResults > 5mins, if none, just commit the parserResults
     2- If step 1, get all the productItems corresponding to the productID's in the old parserResults (oldSet) from the Core Data database
     - parse and get all the productID's in the new parserResults (newSet)
     - Update the attributes of any productItems that are in both the oldSet and the newSet
     - Delete the productItems that are in the oldSet but not in the newSet
     - Insert the productItems that are not in oldSet but are in the newSet
     */
    
    // create the array with a parseResult and timestamp
    
    if ([oldKeys containsObject:self.variableRelativePath]){
        NSDictionary *pathsNewResults;
        NSArray * newResult = [NSArray arrayWithObjects:parserResults,[NSDate date], nil];
        assert(newResult != nil);
        pathsNewResults = [NSDictionary dictionaryWithObject:newResult forKey:self.variableRelativePath];
        assert(pathsNewResults != nil);          
            
        // compare the times for the parserResults
        NSDate *oldparserTime;
        NSDate *newparserTime;
        NSTimeInterval parserUpdateInterval;
        
        oldparserTime = [NSDate dateWithTimeInterval:0 sinceDate:[[pathsOldResults objectForKey:self.variableRelativePath] lastObject]];
        assert(oldparserTime != nil);
        newparserTime = [NSDate dateWithTimeInterval:0 sinceDate:[[pathsNewResults objectForKey:self.variableRelativePath] lastObject]];
        assert(newparserTime != nil);
        
        parserUpdateInterval = [newparserTime timeIntervalSinceDate:oldparserTime];
        
        // Update, delete, insert the new product items accordingly since we are sure
        // we have likely seen these productItems and need to refresh them
        
        if (parserUpdateInterval > kTimeIntervalToRefreshCollection) {
            
            NSFetchRequest *fetchRequest;
            NSError *fetchError;
            NSMutableSet *oldParserIDs;
            NSMutableSet *newParserIDs;
            MzProductItem * newProduct;
            NSPredicate *existingProducts;
            NSArray *retrievedProducts;
            
            oldParserIDs = [NSMutableSet set];
            assert(oldParserIDs != nil);
            newParserIDs = [NSMutableSet set];
            assert(newParserIDs != nil);
            
            // Parse the old parserResults and store the productIDs
            NSArray *oldparserResults = [NSArray arrayWithArray:[[pathsOldResults objectForKey:self.variableRelativePath] objectAtIndex:0]];
            assert(oldparserResults != nil);
            
            for (NSDictionary * oldParserResult in oldparserResults) {
                NSString *productID;
                
                productID  = [oldParserResult objectForKey:kCollectionParserResultProductID];
                assert([productID isKindOfClass:[NSString class]]);
                
                // Check for duplicates.
                
                if ([oldParserIDs containsObject:productID]) {
                    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Collection Cache with URL %@ contains duplicate productItem %@", self.collectionURLString, productID];
                } else {
                    
                    [oldParserIDs addObject:productID];
                }
                
                // Get all the productItems from the database that correspond to the productID's in the
                // old parserResults
                
                fetchRequest = [[NSFetchRequest alloc] init];
                assert(fetchRequest != nil);
                existingProducts = [NSPredicate predicateWithFormat:@"productID IN %@", oldParserIDs];
                assert(existingProducts != nil);
                
                [fetchRequest setEntity:self.productItemEntity];
                [fetchRequest setFetchBatchSize:20];
                [fetchRequest setPredicate:existingProducts];
                retrievedProducts = [self.productCollectionContext executeFetchRequest:fetchRequest error:&fetchError];
                assert(retrievedProducts != nil);    
                
                //Update, insert, delete the retrieved productItems based on the properties of the new
                // parserResults
                
                if (retrievedProducts != nil) {
                    NSMutableSet *productsToRemove;
                    NSMutableDictionary *productIDToRetrievedProduct;
                    MzProductItem *existingProduct;
                    
                    // productsToRemove starts as the set of all productItems we retrieved
                    productsToRemove = [NSMutableSet setWithArray:retrievedProducts];
                    assert(productsToRemove != nil);
                    
                    // create the map from productID to productItem
                    productIDToRetrievedProduct = [NSMutableDictionary dictionary];
                    assert(productIDToRetrievedProduct != nil);
                    
                    for (existingProduct in retrievedProducts) {
                        assert([existingProduct isKindOfClass:[MzProductItem class]]);
                        
                        [productIDToRetrievedProduct setObject:existingProduct forKey:existingProduct.productID];
                    }
                    
                    // Iterate through the incoming XML results, processing each one in turn
                    for (NSDictionary * parserResult in parserResults) {
                        NSString *productID;
                        
                        productID  = [parserResult objectForKey:kCollectionParserResultProductID];
                        assert([productID isKindOfClass:[NSString class]]);
                        
                        // Check for duplicates.
                        
                        if ([newParserIDs containsObject:productID]) {
                            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Collection Cache with URL %@ contains duplicate productItem %@", self.collectionURLString, productID];
                        } else {
                            NSDictionary *properties;
                            
                            [newParserIDs addObject:productID];
                            
                            // Build a properties dictionary to create new MzProductItem.
                            
                            properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                          productID,                                                        @"productID",
                                          [parserResult objectForKey:kCollectionParserResultTitle],           @"productTitle", 
                                          [parserResult objectForKey:kCollectionParserResultDetailsPath],           @"productDetailPath", 
                                          [parserResult objectForKey:kCollectionParserResultImagePath],      @"remoteImagePath", 
                                          [parserResult objectForKey:kCollectionParserResultThumbNailPath],  @"remoteThumbnailPath",
                                          [parserResult objectForKey:kCollectionParserResultDescription], @"productDescription",
                                          [parserResult objectForKey:kCollectionParserResultLanguage],           @"productLanguage",
                                          [parserResult objectForKey:kCollectionParserResultCountry],           @"productCountry",
                                          [parserResult objectForKey:kCollectionParserResultClassID],           @"productClassID",
                                          [parserResult objectForKey:kCollectionParserResultSubClassID],           @"productSubClassID",
                                          [parserResult objectForKey:kCollectionParserResultPriceUnit],           @"productPriceUnit",
                                          [parserResult objectForKey:kCollectionParserResultPriceAmount],           @"productPriceAmount",
                                          [parserResult objectForKey:kCollectionParserResultBrand],           @"productBrand",
                                          [parserResult objectForKey:kCollectionParserResultCondition],           @"productCondition",
                                          [parserResult objectForKey:kCollectionParserResultAvailability],           @"productAvailability",
                                          nil
                                          ];
                            assert(properties != nil);
                            
                            // check for existing productItem and update or insert accordingly
                            existingProduct = [productIDToRetrievedProduct objectForKey:productID];
                            
                            if (existingProduct != nil) {
                                
                                //Update productItem with new incoming properties.
                                
                                [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Update ProductItem: %@ for Collection Cache with URL: %@", productID, self.collectionURLString];
                                [productsToRemove removeObject:existingProduct];
                                [existingProduct updateWithProperties:properties];
                                
                            } else {
                                //Create a new ProductItem with the specified properties.
                                
                                [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Create  ProductItem: %@ for Collection Cache with URL: %@", productID, self.collectionURLString];
                                newProduct = [MzProductItem insertNewMzProductItemWithProperties:properties inManagedObjectContext:self.productCollectionContext];
                                assert(newProduct != nil);
                                assert(newProduct.productID != nil);
                                assert(newProduct.localImagePath == nil);
                                assert(newProduct.thumbnail == nil);
                                assert(newProduct.productTimestamp != nil);
                            }
                            
                        }
                    }
                    // Remove any products not in the newParserResults.
                    
                    for (existingProduct in productsToRemove) {
                        [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Delete ProductItem: %@ for Collection Cache with URL %@", existingProduct.productID, self.collectionURLString];
                        [self.productCollectionContext deleteObject:existingProduct];
                    }
                }
            }

        } else {
            
            // In this case we do nothing....
            [[QLog log] logWithFormat:@"Ignored Refresh for Collection Cache with URL: %@", self.collectionURLString];
            
        }
        
    } else {
        
        // Update the the oldpathResults dictionary
        NSArray * oldResult = [NSArray arrayWithObjects:parserResults,[NSDate date], nil];
        assert(oldResult != nil);
        [pathsOldResults setValue:oldResult forKey:variableRelativePath];
        
        // commit the new parserResults, there is no need to check the database since
        // we are sure we have not seen the relativePath that generated these parserResults
        // so these should all be new productItems.
        
        NSMutableSet *newParserIDs;
        MzProductItem *newProduct;
        newParserIDs = [NSMutableSet set];
        assert(newParserIDs != nil);
        
        // Iterate through the incoming XML results, processing each one in turn
        for (NSDictionary * parserResult in parserResults) {
            NSString *productID;
            
            productID  = [parserResult objectForKey:kCollectionParserResultProductID];
            assert([productID isKindOfClass:[NSString class]]);
            
            // Check for duplicates.
            
            if ([newParserIDs containsObject:productID]) {
                [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Collection Cache with URL %@ contains duplicate productItem %@", self.collectionURLString, productID];
            } else {
                NSDictionary *properties;
                
                [newParserIDs addObject:productID];
                
                // Build a properties dictionary to create new MzProductItem.
                
                properties = [NSDictionary dictionaryWithObjectsAndKeys:
                              productID,                                                        @"productID",
                              [parserResult objectForKey:kCollectionParserResultTitle],           @"productTitle", 
                              [parserResult objectForKey:kCollectionParserResultDetailsPath],           @"productDetailPath", 
                              [parserResult objectForKey:kCollectionParserResultImagePath],      @"remoteImagePath", 
                              [parserResult objectForKey:kCollectionParserResultThumbNailPath],  @"remoteThumbnailPath",
                              [parserResult objectForKey:kCollectionParserResultDescription], @"productDescription",
                              [parserResult objectForKey:kCollectionParserResultLanguage],           @"productLanguage",
                              [parserResult objectForKey:kCollectionParserResultCountry],           @"productCountry",
                              [parserResult objectForKey:kCollectionParserResultClassID],           @"productClassID",
                              [parserResult objectForKey:kCollectionParserResultSubClassID],           @"productSubClassID",
                              [parserResult objectForKey:kCollectionParserResultPriceUnit],           @"productPriceUnit",
                              [parserResult objectForKey:kCollectionParserResultPriceAmount],           @"productPriceAmount",
                              [parserResult objectForKey:kCollectionParserResultBrand],           @"productBrand",
                              [parserResult objectForKey:kCollectionParserResultCondition],           @"productCondition",
                              [parserResult objectForKey:kCollectionParserResultAvailability],           @"productAvailability",
                              nil
                              ];
                assert(properties != nil);
                
                  //Create a new ProductItem with the specified properties.
                    
                    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Create  ProductItem: %@ for Collection Cache with URL: %@", productID, self.collectionURLString];
                    newProduct = [MzProductItem insertNewMzProductItemWithProperties:properties inManagedObjectContext:self.productCollectionContext];
                    assert(newProduct != nil);
                    assert(newProduct.productID != nil);
                    assert(newProduct.localImagePath == nil);
                    assert(newProduct.thumbnail == nil);
                    assert(newProduct.productTimestamp != nil);
                }
                
        }

    }
     
                   
#if ! defined(NDEBUG)
   // [self checkDatabase];
#endif
}

// Register the isSyncing as a dependent key for KVO notifications
+ (NSSet *)keyPathsForValuesAffectingSynchronizing
{
    return [NSSet setWithObject:@"stateOfSync"];
}

// Getter for isSyncing property
- (BOOL)isSynchronizing
{
    return (self->stateOfSync > ProductCollectionSyncStateStopped);
}

+ (BOOL)automaticallyNotifiesObserversOfStateOfSync
{
    return NO;
}

// Setter for the stateOfSync property, this property is KVO-observable
- (void)setStateOfSync:(ProductCollectionSyncState)newValue
{
    if (newValue != self->stateOfSync) {
        BOOL    isSyncingChanged;
        
        isSyncingChanged = (self->stateOfSync > ProductCollectionSyncStateStopped) != (newValue > ProductCollectionSyncStateStopped);
        [self willChangeValueForKey:@"stateOfSync"];
        if (isSyncingChanged) {
            [self willChangeValueForKey:@"synchronizing"];
        }
        self->stateOfSync = newValue;
        if (isSyncingChanged) {
            [self didChangeValueForKey:@"synchronizing"];
        }
        [self didChangeValueForKey:@"stateOfSync"];
    }
}

// Key method that starts the synchronization process
- (void)startSynchronization:(NSString *)relativePath
{
    if ( !self.isSynchronizing ) {
        if (self.stateOfSync == ProductCollectionSyncStateStopped) {
            [[QLog log] logWithFormat:@"Start synchronization for Collection Cache with URL: %@",
             self.collectionURLString];
            assert(self.getCollectionOperation == nil);
            self.errorFromLastSync = nil;
            [self startGetOperation:relativePath];
        }
    }
}

// Method that stops the synchronization process
- (void)stopSynchronization
{
    if (self.isSynchronizing) {
        if (self.getCollectionOperation != nil) {
            [[NetworkManager sharedManager] cancelOperation:self.getCollectionOperation];
            self.getCollectionOperation = nil;
        }
        if (self.parserOperation) {
            [[NetworkManager sharedManager] cancelOperation:self.parserOperation];
            self.parserOperation = nil;
        }
        self.errorFromLastSync = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
        self.stateOfSync = ProductCollectionSyncStateStopped;
        [[QLog log] logWithFormat:@"Stopped synchronization for Collection Cache with URL: %@", self.collectionURLString];
    }
}




@end
