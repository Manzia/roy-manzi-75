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
-(NSManagedObjectContext *)managedObjectContext
{
    return self.productCollectionContext;
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

// Initialize a MzProductCollection model object
- (id)initWithCollectionURLString:(NSString *)collectURLString
{
    assert(collectURLString != nil);
        
    self = [super init];
    if (self != nil) {
        self.collectionURLString = collectURLString;
                
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(collectionDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        [[QLog log] logWithFormat:@"Collection cache instantiated with URL: %@", collectURLString];
    }
    return self;
}


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

// Method that is called when application is transitioning to the ACTIVE state
- (void)didBecomeActive:(NSNotification *)notification
{
#pragma unused(notification)
    
     if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"collectionSyncOnActivate"] ) {
        if (self.productCollectionContext != nil) {
            [self startSynchronization];
        }
    }
}


@end
