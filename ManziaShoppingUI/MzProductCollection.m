//
//  MzProductCollection.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 5/30/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzProductCollection.h"
#import "QLog.h"
#import "RecursiveDeleteOperation.h"

#define kActiveCollectionCachesLimit 4

@interface MzProductCollection() 

// private properties
    @property (nonatomic, copy, readwrite) NSString *collectionURLString;
    @property (nonatomic, retain, readwrite)NSEntityDescription *productItemEntity;
    @property (nonatomic, retain, readwrite)MzProductCollectionContext* productCollectionContext;
    @property (nonatomic, copy, readonly) NSString *collectionCachePath;
    @property (nonatomic, retain, readwrite) NSTimer *timeToSave;
    @property (nonatomic, copy,   readwrite) NSDate *dateLastSynced;
    @property (nonatomic, copy,   readwrite) NSError *errorFromLastSync;

@end

@implementation MzProductCollection

// Synthesize properties
@synthesize collectionURLString;
@synthesize productItemEntity;
@synthesize productCollectionContext;
@synthesize collectionCachePath;
@synthesize timeToSave;
@synthesize dateFormatter;
@synthesize dateLastSynced;
@synthesize errorFromLastSync;

// Other Getters
-(id)managedObjectContext
{
    return self.productCollectionContext;
}

//Override getter and maintain KVC compliance
- (NSString *)collectionPath
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
+ (void)markForRemoveCollectionCacheAtPath:(NSString *)collectionCachePath
{
    (void) [[NSFileManager defaultManager] removeItemAtPath:[collectionCachePath stringByAppendingPathComponent:kCollectionFileName] error:NULL];
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
            NSString *collectionCachePath;      // ProductCollection cache directory name
            NSString *collectionInfoFilePath;   // associated plist file
            NSString *collectionDataFilePath;   // associated Core data file
            
            collectionCachePath = [cachesDirectoryPath stringByAppendingPathComponent:collectionCacheName];
            assert(collectionCachePath != nil);
            
            collectionInfoFilePath = [collectionCachePath stringByAppendingPathComponent:kCollectionFileName];
            assert(collectionInfoFilePath != nil);
            
            collectionDataFilePath = [collectionCachePath stringByAppendingPathComponent:kCollectionDataFileName];
            assert(collectionDataFilePath != nil);
            
            if (clearCollectionCaches) {
                [[QLog log] logWithFormat:@"Clear Collection Cache: '%@'", collectionCacheName];
                (void) [fileManager removeItemAtPath:collectionInfoFilePath error:NULL];
                [collectionCachePathsToDelete addObject:collectionCachePath];
            } else if ( ! [fileManager fileExistsAtPath:collectionInfoFilePath]) {
                [[QLog log] logWithFormat:@"Collection cache already marked for delete: '%@'", collectionCacheName];
                [collectionCachePathsToDelete addObject:collectionCachePath];
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
                    [collectionCachePathsToDelete addObject:collectionCachePath];
                } else {
                    assert([modifiedDate isKindOfClass:[NSDate class]]);
                    [activeCollectionCachePathsAndDates addObject:
                        [NSDictionary dictionaryWithObjectsAndKeys:
                         collectionCachePath, @"collectionPath", modifiedDate, @"modifiedDate",nil]];
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
            [self startSynchronization];
        }
    }
}

#pragma mark * Core Data Management
// Override synthesized Getter for the productItemEntity property
- (NSEntityDescription *)productItemEntity
{
    if (self->productItemEntity == nil) {
        assert(self.productCollectionContext != nil);
        self->productItemEntity = [NSEntityDescription entityForName:@"ProductItems" inManagedObjectContext:self.productCollectionContext];
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
    
    [[QLog log] logWithFormat:@"Starting Collection Cache"];
    
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
        
        [[QLog log] logWithFormat:@"Collection started successfully: '%@'", [self.collectionCachePath lastPathComponent]];
    } else {
        
        // Log the error and return NO.
        
        if (error == nil) {
            [[QLog log] logWithFormat:@"Error starting Collection Cache"];
        } else {
            [[QLog log] logWithFormat:@"Logged error starting Collection Cahce %@", error];
        }
        
        //Mark for deletion Collection caches that we tried and failed to start-up
        
        if (collectionPath != nil) {
            [self markForRemoveCollectionCacheAtPath:collectionPath];
        }
    }
    return success;
}


@end
