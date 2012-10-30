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

#define kAutoSaveContextChangesTimeInterval 1.0     // 5 secs to auto-save
#define kTimeIntervalToRefreshCollection 600        // 10mins to auto-refresh
#define kMAX_COLLECTION_DURATION 1209600        // 2 weeks or 14 days in Seconds
#define kMAX_REFRESH_INTERVAL 86400             // 1 day in Seconds

@interface MzProductCollection() 

// private properties
@property (nonatomic, copy, readwrite) NSString *collectionURLString;
@property (nonatomic, strong, readwrite)NSEntityDescription *productItemEntity;
@property (nonatomic, strong, readwrite) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, copy, readwrite) NSURL *collectionCachePath;
@property (nonatomic, assign, readwrite) ProductCollectionSyncState stateOfSync;
@property (nonatomic, strong, readwrite) NSTimer *timeToSave;
@property (nonatomic, copy, readwrite) NSDate *dateLastSynced;
@property (nonatomic, copy, readwrite) NSError *errorFromLastSync;
@property (nonatomic, strong, readwrite) RetryingHTTPOperation *getCollectionOperation;
@property (nonatomic, strong, readwrite) MzCollectionParserOperation *parserOperation;

// Property that holds all the MzProductItems associated with this MzProductCollection
// in an NSDictinary whose Key is the collectionCacheName
@property (nonatomic, strong, readwrite) NSDictionary *productItems;

// Dictionary whose Key is the collectionCacheName and Value is the statusOfSync string
@property(nonatomic, strong, readwrite) NSDictionary *cacheSyncStatus;

// Dictionary whose Key is the Search URL and Value is the collectionCacheName
@property(nonatomic, strong, readwrite) NSDictionary *cachePath;

// forward declarations

- (void)startParserOperationWithData:(NSData *)data;
- (void)commitParserResults:(NSArray *)latestResults;

@end

@implementation MzProductCollection

// Synthesize properties
@synthesize collectionURLString;
@synthesize productItemEntity;
//@synthesize productCollectionContext;
@synthesize collectionCachePath;
@synthesize stateOfSync;
@synthesize timeToSave;
@synthesize dateFormatter;
@synthesize dateLastSynced;
@synthesize errorFromLastSync;
@synthesize getCollectionOperation;
@synthesize parserOperation;
//@synthesize pathsOldResults;
//@synthesize variableRelativePath;
//@synthesize timeToRefresh;
@synthesize synchronizing;
@synthesize statusOfSync;
@synthesize managedObjectContext;
@synthesize productItems;
@synthesize cacheSyncStatus;
@synthesize cachePath;


/* Other Getters
-(id)managedObjectContext
{
    return self.productCollectionContext;
} */

/*Override getter and maintain KVC compliance
+ (NSString *)collectionCachePath
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
} */



/* Changes in the productCollectionContext property will trigger
// KVO notifications to observers of managedObjectContext property
+ (NSSet *)keyPathsForValuesAffectingManagedObjectContext
{
    return [NSSet setWithObject:@"productCollectionContext"];
} */

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
        //pathsOldResults = [[NSMutableDictionary alloc] init];
        //assert(pathsOldResults!=nil);
        //self->variableRelativePath = @"default";
                        
        //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        [[QLog log] logWithFormat:@"Collection cache instantiated with URL: %@", self.collectionURLString];
    }
    return self;
}

#pragma mark * Collection CacheDirectory Managemnt

// Returns a path to the CachesDirectory
+ (NSURL *)pathToCachesDirectory
{
    NSURL *cacheDir;
    NSArray *cachesPaths;
    NSFileManager *fileMgr;
    fileMgr = [NSFileManager defaultManager];
    assert(fileMgr != nil);
    
    cachesPaths = [fileMgr URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
    if ( (cachesPaths != nil) && ([cachesPaths count] != 0) ) {
        assert([[cachesPaths objectAtIndex:0] isKindOfClass:[NSURL class]]);
        cacheDir = [cachesPaths objectAtIndex:0];
    }
    
    return cacheDir;
}

// Marks for removal a ProductCollection cache at a given path
+ (void)markForRemoveCollectionCacheAtPath:(NSURL *)collectionPath
{
    assert(collectionPath != nil);
    assert(collectionPath.isFileURL);
    (void) [[NSFileManager defaultManager] removeItemAtURL:[collectionPath URLByAppendingPathComponent:kCollectionFileName] error:NULL];
    [[QLog log] logWithFormat:@"Marked Collection Cache for deletion '%@'", [collectionPath lastPathComponent]];
}

// Method called in the App Delegate's applicationDidEnterBackground method
// Note that because the DELETEOperation is started while in the Background and
// may not run until the applicationDidEnterBackground method exits, we request
// extra time from the system via the beginBackgroundTaskWithExpirationHandler method
+(void)applicationInBackground
{
    NSUserDefaults *userDefaults;
    NSFileManager *fileManager;
    BOOL clearCollectionCaches;
    NSURL *cachesDirectoryPath;
    NSArray *possibleCollectionCacheNames;
    NSMutableArray *collectionCachePathsToDelete;
    //NSMutableArray *    activeCollectionCachePathsAndDates;
    
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
    
    possibleCollectionCacheNames = [fileManager contentsOfDirectoryAtURL:cachesDirectoryPath includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
    assert(possibleCollectionCacheNames != nil);
    
    //activeCollectionCachePathsAndDates = [NSMutableArray array];
    //assert(activeCollectionCachePathsAndDates != nil);
    
    // Enumerate through all the ProductCollection Cache directories
    
    for (NSURL *collectionCacheName in possibleCollectionCacheNames) {
        if ([[collectionCacheName lastPathComponent] hasSuffix:kCollectionExtension]) {
            //NSString *collectionPath;      // ProductCollection cache directory name
            NSURL *collectionInfoFilePath;   // associated plist file
            NSURL *collectionDataFilePath;   // associated Core data file
            
            //collectionPath = [cachesDirectoryPath stringByAppendingPathComponent:collectionCacheName];
            //assert(collectionPath != nil);
            
            collectionInfoFilePath = [collectionCacheName URLByAppendingPathComponent:kCollectionFileName isDirectory:NO];
            assert(collectionInfoFilePath != nil);
            assert(collectionInfoFilePath.isFileURL);
            
            collectionDataFilePath = [collectionCacheName URLByAppendingPathComponent:kCollectionDataFileName isDirectory:NO];
            assert(collectionDataFilePath != nil);
            assert(collectionDataFilePath.isFileURL);
            
            if (clearCollectionCaches) {
                [[QLog log] logWithFormat:@"Clear Collection Cache: '%@'", [collectionCacheName path]];
                (void) [fileManager removeItemAtURL:collectionInfoFilePath error:NULL];
                [collectionCachePathsToDelete addObject:collectionCacheName];
            } else if ( ! [fileManager fileExistsAtPath:[collectionInfoFilePath path]]) {
                [[QLog log] logWithFormat:@"Collection cache already marked for delete: '%@'", [collectionCacheName path]];
                [collectionCachePathsToDelete addObject:collectionCacheName];
            } else {
                
                /*
                 1- Get the modified date of the Core Data file of the surviving Collection
                 caches
                 2- Mark the Collection cache for deletion if setp 1 fails otherwise add the
                 Collection cache's path and modified date to the activeCollectionCachePathsAndDates dictionary
                 */
                NSDate *modifiedDate;
                
                modifiedDate = [[fileManager attributesOfItemAtPath:[collectionDataFilePath path] error:NULL] objectForKey:NSFileModificationDate];
                if (modifiedDate == nil) {
                    [[QLog log] logWithFormat:@"Collection Cache database invalid: '%@'", [collectionCacheName path]];
                    [collectionCachePathsToDelete addObject:collectionCacheName];
                } else {
                    assert([modifiedDate isKindOfClass:[NSDate class]]);
                    if ([modifiedDate timeIntervalSinceNow] <= -kMAX_COLLECTION_DURATION) {
                        [[QLog log] logWithFormat:@"Database in Collection Cache: %@ exceeds Max Duration: %d, will be deleted!", [collectionCacheName path], kMAX_COLLECTION_DURATION];
                        [collectionCachePathsToDelete addObject:collectionCacheName];
                    }                    
                }
            }
        }
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
    
    if ( [collectionCachePathsToDelete count] > 0 ) {
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

/* Method that is called when application is transitioning to the ACTIVE state
- (void)appDidBecomeActive:(NSNotification *)notification
{
#pragma unused(notification)
    
     if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"collectionSyncOnActivate"] ) {
        if ( self.managedObjectContext != nil  self.productCollectionContext != nil ) {
            [self startSynchronization:nil];
        }
    }
} */

#pragma mark * Core Data Management
// Override synthesized Getter for the productItemEntity property
- (NSEntityDescription *)productItemEntity
{
    if (self->productItemEntity == nil) {
        //assert(self.productCollectionContext != nil);
        assert(self.managedObjectContext != nil);
        self->productItemEntity = [NSEntityDescription entityForName:@"MzProductItem" inManagedObjectContext:self.managedObjectContext];
        assert(self->productItemEntity != nil);
    }
    return self->productItemEntity;
}

// Method to return all stored ProductItems (MzProductItem objects)
- (NSFetchRequest *)productItemsFetchRequest
{
    assert(self.productItemEntity != nil);
    NSFetchRequest *    fetchRequest;    
    fetchRequest = [[NSFetchRequest alloc] init];
    assert(fetchRequest != nil);
    
    [fetchRequest setEntity:self.productItemEntity];
    [fetchRequest setFetchBatchSize:20];
    
    return fetchRequest;
}

/* Manual KVO notification
+(BOOL)automaticallyNotifiesObserversOfProductItems
{
    return NO;
}*/

// Retrieve all the ProductItems in the Collection asynchronously. This method will return immediately
//so the caller is expected to use KVO on the productItems property to get notified when the 
// productItems have been fetched
-(void)fetchProductsInCollection
{
    assert(self.collectionURLString != nil);
    NSMutableDictionary *productDict = [NSMutableDictionary dictionary];
    BOOL success;
    __block NSArray *products = nil;
    // Check if we have already set up our NSManagedObjectContext and Cache
    if (self.managedObjectContext == nil) {
        success = [self setupProductCollectionContext];
        if (success) {
            // we can now fetch the products
            assert(self.managedObjectContext != nil);
            assert(self.collectionCachePath != nil);
            
            [self.managedObjectContext performBlockAndWait:^{
                NSError *error = nil;
                NSFetchRequest *fetchRequest = [self productItemsFetchRequest];
                assert(fetchRequest != nil);
                NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                if (fetchResults != nil) {
                    products = [NSArray arrayWithArray:fetchResults];
                    [[QLog log] logWithFormat:@"Fetched %d Products from Collection Cache database at Path: '%@'", [products count], [self.collectionCachePath path ]];
                } else {
                    [[QLog log] logWithFormat:@"Failed to retrieve Products in Collection Cache database at Path: '%@'", [self.collectionCachePath path]];
                }
            }];
        } else {
            [[QLog log] logWithFormat:@"Failed to instantiate ProductCollectionContext for Cache database at Path: '%@'", [self.collectionCachePath path ]];        }
    } else {
        assert(self.collectionCachePath != nil);
        // we already have our NSManagedObjectContext setup
        [self.managedObjectContext performBlockAndWait:^{
            NSError *error = nil;
            NSFetchRequest *fetchRequest = [self productItemsFetchRequest];
            assert(fetchRequest != nil);
            NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            if (fetchResults != nil) {
                products = [NSArray arrayWithArray:fetchResults];
                [[QLog log] logWithFormat:@"Fetched %d Products from Collection Cache database at Path: '%@'", [products count], [self.collectionCachePath path ]];
            } else {
                [[QLog log] logWithFormat:@"Failed to retrieve Products in Collection Cache database at Path: '%@'", [self.collectionCachePath path ]];
            }
        }];
    }
    if (products != nil) {
        [productDict setObject:products forKey:[[self.collectionCachePath path] copy]];
        
        //KVO notify
        //[self willChangeValueForKey:@"productItems"];
        self.productItems = productDict;
        //[self didChangeValueForKey:@"productItems"];
    }    
}

// Finds the associated CollectionCache(Path) given a collectionURLString and
// creates a new CollectionCache if none is found
- (NSURL *)findCacheForCollectionURLString
{
    NSURL *searchResult;
    NSFileManager *fileManager;
    NSURL *cachesDirectory;
    NSArray *possibleCollections;
    NSURL *collectionName;
    
    assert(self.collectionURLString != nil);
    
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    
    cachesDirectory = [[self class] pathToCachesDirectory];
    assert(cachesDirectory != nil);
    
    // Iterate through the Caches Directory and sub-Directories and check each plist
    // file encountered
        
    possibleCollections = [fileManager contentsOfDirectoryAtURL:cachesDirectory includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
    assert(possibleCollections != nil);
    
    searchResult = nil;
    for (collectionName in possibleCollections) {
        if ([[collectionName lastPathComponent] hasSuffix:kCollectionExtension]) {
            
            NSDictionary *collectionInfo;
            NSString *collectionInfoURLString;
            
            collectionInfo = [NSDictionary dictionaryWithContentsOfURL:[collectionName URLByAppendingPathComponent:kCollectionFileName]];
            if (collectionInfo != nil) {
                collectionInfoURLString = [collectionInfo objectForKey:kCollectionKeyCollectionURLString];
                if ( [self.collectionURLString isEqual:collectionInfoURLString] ) {
                    searchResult = collectionName;
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
        
        NSString *newCollectionName = [NSString stringWithFormat:kCollectionNameTemplate, [NSDate timeIntervalSinceReferenceDate], kCollectionExtension];
        assert(newCollectionName != nil);
        
        searchResult = [cachesDirectory URLByAppendingPathComponent:newCollectionName isDirectory:YES];
        success = [fileManager createDirectoryAtURL:searchResult withIntermediateDirectories:NO attributes:NULL error:NULL];
        if (success) {
            NSDictionary *collectionInfoFile;
            
            collectionInfoFile = [NSDictionary dictionaryWithObjectsAndKeys:self.collectionURLString, kCollectionKeyCollectionURLString, nil];
            assert(collectionInfoFile != nil);
            
            success = [collectionInfoFile writeToURL:[searchResult URLByAppendingPathComponent:kCollectionFileName] atomically:YES];
        }
        if (!success) {
            searchResult = nil;
        }
        
        [[QLog log] logWithFormat:@"New Collection Cache created: '%@'", newCollectionName];
    } else {
        assert(collectionName != nil);
        [[QLog log] logWithFormat:@"Found existing Collection Cache '%@'",[collectionName absoluteString]];
    }
    
    return searchResult;
}

/* Private, instance-specific method version of the markForRemoveCollectionCacheAtPath: class method. The CollectionCache marked for deletion will be deleted when the application is moved to the background
 */
- (void)markForRemoveCollectionCacheAtPath:(NSURL *)collectPath
{
    assert(collectPath != nil);
            
    [[self class] markForRemoveCollectionCacheAtPath:collectPath];
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
    NSURL *collectionPath;
    NSURL *productImagesDirectoryPath;
    BOOL isDir;
    NSURL *collectionDbURL;
    NSManagedObjectModel *collectionModel;
    NSPersistentStoreCoordinator *persistentCoordinator;
    
    assert(self.collectionURLString != nil);
    
    [[QLog log] logWithFormat:@"Starting Collection Cache for URL: %@", self.collectionURLString];
    
    error = nil;
    
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    
    // Find and set the Collection Cache directory for this ProductCollection and notify
    // observers of the "cachePath" property
    collectionPath = [self findCacheForCollectionURLString];
    success = (collectionPath != nil);
    if (success) {
        self.collectionCachePath = collectionPath;
        NSMutableDictionary *cacheDict = [NSMutableDictionary dictionaryWithObject:collectionPath forKey:self.collectionURLString];
        assert(cacheDict != nil);
        self.cachePath = cacheDict;
    }
    
    // Create the ProductImages directory if it doesn't already exist.
    
    if (success) {
        productImagesDirectoryPath = [collectionPath URLByAppendingPathComponent:kProductImagesDirectoryName isDirectory:YES];
        assert(productImagesDirectoryPath != nil);
        
        success = [fileManager fileExistsAtPath:[productImagesDirectoryPath path] isDirectory:&isDir] && isDir;
        if (!success) {
            success = [fileManager createDirectoryAtURL:productImagesDirectoryPath withIntermediateDirectories:NO attributes:NULL error:NULL];
        }
    }
    
    // Start up CoreData in the Collection Cache directory.
    
    if (success) {
        NSString *collectionModelPath;
                
        collectionModelPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"MzProductItems" ofType:@"momd"]; // should be @"momd" or @"mom"
        assert(collectionModelPath != nil);
        
        collectionModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:collectionModelPath]];
        success = (collectionModel != nil);
    }
    if (success) {
        
        collectionDbURL = [collectionPath URLByAppendingPathComponent:kCollectionDataFileName];
        assert(collectionDbURL != nil);
        assert(collectionDbURL.isFileURL);
        
        // Set our dateLastSynced property to the last modified date of the database file if it already
        // exists
        if ([fileManager fileExistsAtPath:[collectionDbURL path]]) {
                        
            NSDate *modifiedDate = [[fileManager attributesOfItemAtPath:[collectionDbURL path] error:NULL] objectForKey:NSFileModificationDate];
            if (modifiedDate != nil) {
                self.dateLastSynced = modifiedDate;
            }
        }
        
        // Set up the Persistent Store
        persistentCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:collectionModel];
        success = (persistentCoordinator != nil);
    }
    if (success) {
        
        // Checks if we already have a persistent store and initialize if we do or else create a new
        // persistent store        
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
        success = [persistentCoordinator addPersistentStoreWithType:NSSQLiteStoreType 
                                    configuration:nil 
                                              URL:collectionDbURL
                                          options:options 
                                            error:&error] != nil;
        if (success) {
            error = nil;
        }
    }
    
    // Create a managed Object Context from the created persistent store
    if (success) {
        
        NSManagedObjectContext *collectionContext;
        collectionContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        assert(collectionContext != nil);
        /*MzProductCollectionContext *collectionContext;
        
        collectionContext = [[MzProductCollectionContext alloc] initWithCollectionURLString:self.collectionURLString cachePath:collectionPath];
        assert(collectionContext != nil); */
        
        [collectionContext setPersistentStoreCoordinator:persistentCoordinator];
        //self.productCollectionContext = collectionContext;
        self.managedObjectContext = collectionContext;
        
        // Subscribe to the context changed notification so that we can auto-save.
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(collectionContextChanged:) name:NSManagedObjectContextObjectsDidChangeNotification object:self.managedObjectContext];
        
        [[QLog log] logWithFormat:@"Collection started successfully at Path: '%@' for URL: %@", [self.collectionCachePath path], self.collectionURLString];
        
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
        
        // append the variableRelativePath to collectionURLString happens in the
        // startGetOperation: method
        [self startSynchronization:nil];
        
        /* start the Refresh Timer
        self.timeToRefresh = [NSTimer scheduledTimerWithTimeInterval:kTimeIntervalToRefreshCollection target:self selector:@selector(refreshCollection) userInfo:nil repeats:YES];
        assert([self.timeToRefresh isValid]); */
    } else {
        abort();
    }
}

/* Refresh the collection
 If the dateLastSynced time interval from now is greater than kMAX_REFRESH_INTERVAL then the
 ProductCollection cache is re-synchronized. This method is called by the MzResultListViewController
 which checks the dateLastSynced property of every ProductCollection when we receive a
 UIApplicationDidBecomeActiveNotification
 */
- (void)refreshCollection 
{
    if (self.dateLastSynced != nil && self.managedObjectContext != nil) {
        if ([self.dateLastSynced timeIntervalSinceNow] >= -kMAX_REFRESH_INTERVAL) {
            
            // We can now refresh
            [[QLog log] logWithFormat:@"Start Refresh of Collection Cache with URL: %@", [self.collectionCachePath path]];
            
            // Introduce a random delay so all the Product Collection caches do not all get
            // synchronizing at the same time
            int delay = arc4random() % 100;      // get a number between 1 and 99
            NSTimeInterval delayTime = delay / 10000;
            [self performSelector:@selector(startSynchronization:) withObject:nil afterDelay:delayTime];            
        } else {
            [[QLog log] logWithFormat:@"Too soon to Refresh Collection Cache with URL: %@", [self.collectionCachePath path]];
        }
    } else {
        [[QLog log] logWithFormat:@"Failed to Refresh due to invalid Collection State at Path: %@", [self.collectionCachePath path]];    }
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
    
    /*if ( (self.productCollectionContext != nil) && [self.productCollectionContext hasChanges] ) {
        BOOL success;
        success = [self.productCollectionContext save:&error];
        if (success) {
            error = nil;
        }
    }*/
    
    if (self.managedObjectContext != nil && [self.managedObjectContext hasChanges] ) {
        BOOL success;
        success = [self.managedObjectContext save:&error];
        if (success) {
            error = nil;
        }
    }
    
    // Log the results.
    
    if (error == nil) {
        [[QLog log] logWithFormat:@"Saved Collection Cache with URL: %@", [self.collectionCachePath path]];
    } else {
        [[QLog log] logWithFormat:@"Collection Cache save error: %@ with URL: %@", error, [self.collectionCachePath path ]];
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
    
    if ( self.managedObjectContext != nil /*self.productCollectionContext != nil */) {
        
        // Stop the auto save mechanism and then force a save.
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:self.managedObjectContext];
        
        [self saveCollection];
        
        self.productItemEntity = nil;
        //self.productCollectionContext = nil;
        self.managedObjectContext = nil;
        
        // Invalidate the Refresh Timer
        //[self.timeToRefresh invalidate];
        //self.timeToRefresh = nil;
    }
    [[QLog log] logWithFormat:@"Stopped Collection Cache with URL: %@", [self.collectionCachePath path ]];
}

#pragma mark * Main Synchronization methods

// Register all the dependent properties/keys (on StateOfSync property) to enable
// KVO notifications for changes in any of these dependent properties
+ (NSSet *)keyPathsForValuesAffectingStatusOfSync
{
    return [NSSet setWithObjects:@"stateOfSync", @"errorFromLastSync", @"dateFormatter", @"dateLastSynced", @"getCollectionOperation.retryStateClient", nil];
}

// The observable "cacheSyncStatus" is dependent on the statusOfSync property but we disable
// automatic notifications and do a manual notification after synchronization in the 
// -parserOperationDone: method 
+(BOOL)automaticallyNotifiesObserversOfCacheSyncStatus
{
    return NO;
}

 //Manually notify observers of the "cacheSyncStatus" property
-(void)notifyCacheSyncStatus{
    
    NSString *status = self.statusOfSync;
    NSURL *cacheName = self.collectionCachePath;
    if (status != nil && cacheName != nil) {
        NSMutableDictionary *statusDict = [NSMutableDictionary dictionaryWithObject:status forKey:cacheName];
        assert(statusDict != nil);
        [self willChangeValueForKey:@"cacheSyncStatus"];
        self.cacheSyncStatus = statusDict;
        [self didChangeValueForKey:@"cacheSyncStatus"];
    }
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
    //assert([NSThread isMainThread]);
    
    if (newError != nil) {
        [[QLog log] logWithFormat:@"Collection Cache with URL: %@ got sync error: %@", [self.collectionCachePath path ], newError];
    }
    
    if (newError != self->errorFromLastSync) {
        [self willChangeValueForKey:@"errorFromLastSync"];
        self->errorFromLastSync = [newError copy];
        [self didChangeValueForKey:@"errorFromLastSync"];
    }
}

/* Method to create the URLRequest, */

- (NSMutableURLRequest *)requestToGetCollectionRelativeString:(NSString *)path
{
    NSMutableURLRequest *urlRequest;
    NSURL *url;
    
    //assert([NSThread isMainThread]);
    assert(self.collectionURLString != nil);
    
    urlRequest = nil;
    
    // Construct the URL.
    
    url = [NSURL URLWithString:self.collectionURLString];
    assert(url != nil);
    if (path != nil) {
        url = [NSURL URLWithString:path relativeToURL:url];               
    }
    
    // Call down to the network manager so that it can set up its stuff 
    // (notably the user agent string).
    
    if (url != nil) {
        urlRequest = [[NetworkManager sharedManager] requestToGetURL:url];
        assert(urlRequest != nil);
    }
    
    return urlRequest;
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
    
    //requestURL = [self.productCollectionContext requestToGetCollectionRelativeString:relativePath];
    requestURL = [self requestToGetCollectionRelativeString:relativePath];
    assert(requestURL != nil);
    
    assert(self.getCollectionOperation == nil);
    self.getCollectionOperation = [[RetryingHTTPOperation alloc] initWithRequest:requestURL];
    assert(self.getCollectionOperation != nil);
    
    [self.getCollectionOperation setQueuePriority:NSOperationQueuePriorityNormal];
    self.getCollectionOperation.acceptableContentTypes = [NSSet setWithObjects:@"application/xml", @"text/xml", nil];
    
    [[NetworkManager sharedManager] addNetworkManagementOperation:self.getCollectionOperation finishedTarget:self action:@selector(getCollectionOperationComplete:)];
    
    self.stateOfSync = ProductCollectionSyncStateGetting;
    
    // Notify observers of sync status
    [self notifyCacheSyncStatus];
}

// Starts an operation to parse the product collection's XML when the HTTP GET
// operation completes succesfully
- (void)getCollectionOperationComplete:(RetryingHTTPOperation *)operation
{
    NSError *error;
    
    assert([operation isKindOfClass:[RetryingHTTPOperation class]]);
    assert(operation == self.getCollectionOperation);
    assert(self.stateOfSync == ProductCollectionSyncStateGetting);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Completed HTTP GET operation for Collection Cache with URL: %@", [self.collectionCachePath path ]];
    
    error = operation.error;
    if (error != nil) {
        self.errorFromLastSync = error;
        self.stateOfSync = ProductCollectionSyncStateStopped;
    } else {
        if ([QLog log].isEnabled) {
            [[QLog log] logOption:kLogOptionNetworkData withFormat:@"Receive valid XML "];
        }
        [self startParserOperationWithData:self.getCollectionOperation.responseContent];
    }
    
    self.getCollectionOperation = nil;
    
    [self notifyCacheSyncStatus];
}

- (void)startParserOperationWithData:(NSData *)data
// Starts the operation to parse the gallery's XML.
{
    assert(self.stateOfSync == ProductCollectionSyncStateGetting);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Start parse for Collection Cache with URL: %@", [self.collectionCachePath path ]];
    
    assert(self.parserOperation == nil);
    self.parserOperation = [[MzCollectionParserOperation alloc] initWithXMLData:data];
    assert(self.parserOperation != nil);
    
    [self.parserOperation setQueuePriority:NSOperationQueuePriorityNormal];
    
    [[NetworkManager sharedManager] addCPUOperation:self.parserOperation finishedTarget:self action:@selector(parserOperationDone:)];
    
    self.stateOfSync = ProductCollectionSyncStateParsing;
    
    [self notifyCacheSyncStatus];
}

// Method is called when the Collection ParserOperation completes and if successful
// commits the results to the Core Data database in our Collection Cache.
- (void)parserOperationDone:(MzCollectionParserOperation *)operation
{
    assert([NSThread isMainThread]);
    assert([operation isKindOfClass:[MzCollectionParserOperation class]]);
    assert(operation == self.parserOperation);
    assert(self.stateOfSync == ProductCollectionSyncStateParsing);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Parsing complete for Collection Cache with URL: %@", [self.collectionCachePath path ]];
    
    if (operation.parseError != nil) {
        self.errorFromLastSync = operation.parseError;
        self.stateOfSync = ProductCollectionSyncStateStopped;
    } else {
        //[self commitParserResults:operation.parseResults];
        [self.managedObjectContext performBlock:^{
            [self commitParserResults:operation.parseResults];
        }];
        
        assert(self.errorFromLastSync == nil);
        self.dateLastSynced = [NSDate date];
        self.stateOfSync = ProductCollectionSyncStateStopped;
        [[QLog log] logWithFormat:@"Successfully synced Collection Cache with URL: %@", [self.collectionCachePath path ]];       
        
    }        
    self.parserOperation = nil;
    
    [self notifyCacheSyncStatus];
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
    assert(parserResults != nil);
    
     if ([parserResults count] > 0) {
            
            NSFetchRequest *fetchRequest;
            NSError *fetchError = NULL;
            NSMutableSet *oldParserIDs;
            NSMutableSet *newParserIDs;
            NSMutableSet *updateParserIDs;
            NSMutableSet *deleteParserIDs;
            NSArray *retrievedProducts;
            
            // Retrieve and store the productIDs from the parserResults in a set (avoids duplicates)
            newParserIDs = [NSMutableSet setWithArray:[parserResults valueForKey:kCollectionParserResultProductID]];
            assert(newParserIDs != nil);
            
            // Check for duplicates - the duplicates will be ignored
            if ([newParserIDs count] != [parserResults count]) {
                [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Duplicates in new product Items for Collection Cache at Path: %@", [self.collectionCachePath path ]];
            }
            
            // Get all the productItems from the database
            fetchRequest = [self productItemsFetchRequest];
            assert(fetchRequest != nil);
            retrievedProducts = [self.managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
            assert(retrievedProducts != nil);
            
            // Handle errors, we do not commit the new parserResults if we have errors and we mark ourselves for
            // deletion...the next time we synchronize we shall re-create the Cache and database and commit the
            // parser results
            if (fetchError) {
                [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Error: %@ while fetching from Collection Cache at Path: %@..will mark self for Deletion!", fetchError.localizedDescription, self.collectionCachePath];
                [self markForRemoveCollectionCacheAtPath:self.collectionCachePath];
                return;
            }
                
            // Do the Updates accordingly
            if ([retrievedProducts count] > 0) {
                
                // Retrieve the productIDs from the existing productItems
                oldParserIDs = [NSMutableSet setWithArray:[retrievedProducts valueForKey:kCollectionParserResultProductID]];
                assert(oldParserIDs != nil);
                
                // productIDs to update
                updateParserIDs = [NSMutableSet setWithSet:newParserIDs];
                assert(updateParserIDs != nil);
                [updateParserIDs intersectSet:oldParserIDs];
                
                // productIDs to delete
                deleteParserIDs = [NSMutableSet setWithSet:oldParserIDs];
                assert(deleteParserIDs != nil);
                [deleteParserIDs minusSet:newParserIDs];
                
                // productIDs to insert
                [newParserIDs minusSet:oldParserIDs];
                
                // Iterate through the productItems
                for (MzProductItem *productItem in retrievedProducts ) {
                    assert([productItem isKindOfClass:[MzProductItem class]]);
                    
                    if ( [deleteParserIDs containsObject:productItem.productID] ) {
                        [self.managedObjectContext deleteObject:productItem];
                        
                    } else if ([updateParserIDs containsObject:productItem.productID] ) {
                        
                        // Get the NSDictionary that corresponds to this productID
                       NSUInteger dictMatch = [parserResults indexOfObjectPassingTest:^(NSDictionary *parseResult, NSUInteger idx, BOOL *stop) {                          
                                       if ([productItem.productID isEqualToString:[parseResult objectForKey:kCollectionParserResultProductID]]) {
                                           *stop = YES;
                                           return YES;
                                       } else {
                                           return NO;
                                       }
                                   }];
                        if (dictMatch != NSNotFound) {
                            //Update productItem with new incoming properties.
                            
                            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Update ProductItem: %@ for Collection Cache with URL: %@", productItem.productID, [self.collectionCachePath path ]];
                            [productItem updateWithProperties:[parserResults objectAtIndex:dictMatch]];
                        } else {
                            // Unexpected scenario
                            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Failed to find expected ProductItem: %@ for Collection Cache with URL: %@", productItem.productID, [self.collectionCachePath path ]];                        
                        }
                    }                    
                }
                
                // Insert the new products (Ignores duplicates)
                [newParserIDs enumerateObjectsUsingBlock:^(NSString *productId, BOOL *stop) {
                    
                    // Get the NSDictionary that corresponds to this productID
                    NSUInteger dictMatch = [parserResults indexOfObjectPassingTest:^(NSDictionary *parseResult, NSUInteger idx, BOOL *stop) {                          
                        if ([productId isEqualToString:[parseResult objectForKey:kCollectionParserResultProductID]]) {
                            *stop = YES;
                            return YES;
                        } else {
                            return NO;
                        }
                    }];
                    
                    // Insert the new product
                    if (dictMatch != NSNotFound) {
                        [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Created a ProductItem: %@ for Collection Cache with URL: %@", productId, [self.collectionCachePath path ]];
                        MzProductItem *newProduct = [MzProductItem insertNewMzProductItemWithProperties:[parserResults objectAtIndex:dictMatch] inManagedObjectContext:self.managedObjectContext];
                        assert(newProduct != nil);
                        assert(newProduct.productID != nil);
                        assert(newProduct.localImagePath == nil);
                        assert(newProduct.thumbnail == nil);
                        assert(newProduct.productTimestamp != nil);
                    }
                }];
                
            } else {
                
                // insert all the new productItems
                for (NSDictionary *result in parserResults) {
                                        
                    MzProductItem *newProduct = [MzProductItem insertNewMzProductItemWithProperties:result inManagedObjectContext:self.managedObjectContext];
                    assert(newProduct != nil);
                    assert(newProduct.productID != nil);
                    assert(newProduct.localImagePath == nil);
                    assert(newProduct.thumbnail == nil);
                    assert(newProduct.productTimestamp != nil);
                }
                [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Creating %d ProductItems for Collection Cache with URL: %@", [parserResults count], [self.collectionCachePath path ]];
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
    assert(self.managedObjectContext != nil);
    if ( !self.isSynchronizing ) {
        if (self.stateOfSync == ProductCollectionSyncStateStopped) {
            [[QLog log] logWithFormat:@"Start synchronization for Collection Cache with URL: %@",
             [self.collectionCachePath path ]];
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
        [[QLog log] logWithFormat:@"Stopped synchronization for Collection Cache with URL: %@", [self.collectionCachePath path ]];
    }
}




@end
