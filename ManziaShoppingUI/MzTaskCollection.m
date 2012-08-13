//
//  MzTaskCollection.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskCollection.h"
#import "MzTaskParserOperation.h"
#import "MzTaskCollectionContext.h"
#import "Logging.h"
#import "RecursiveDeleteOperation.h"
#import "RetryingHTTPOperation.h"
#import "NetworkManager.h"
#import "MzTaskCategory.h"
#import "MzTaskType.h"
#import "MzTaskAttribute.h"
#import "MzTaskAttributeOption.h"
#import "MzQueryItem.h"

#define kAutoSaveContextChangesTimeInterval 5.0     // 5 secs to auto-save

@interface MzTaskCollection() 

// private properties
@property (nonatomic, copy, readwrite) NSString *tasksURLString;
@property (nonatomic, retain, readwrite)NSEntityDescription *tasksEntity;
@property (nonatomic, retain, readwrite) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, copy, readwrite) NSString *tasksCachePath;
@property (nonatomic, assign, readwrite) TaskCollectionSyncState stateOfSync;
@property (nonatomic, retain, readwrite) NSTimer *timeToSave;
@property (nonatomic, copy, readwrite) NSDate *dateLastSynced;
@property (nonatomic, copy, readwrite) NSError *errorFromLastSync;
@property (nonatomic, retain, readwrite) RetryingHTTPOperation *getTasksOperation;
@property (nonatomic, retain, readwrite) MzTaskParserOperation *parserOperation;
@property (nonatomic, assign, readwrite) UIBackgroundTaskIdentifier taskCollectionSync;

// This property will hold the value of the relativePath that was appended to
// the collectionURLString to create the NSURLRequest for the HTTP GET
//@property (nonatomic, copy, readwrite) NSString * variableRelativePath;

// Keys are relativePaths and values are an array of old parserResults
// and time parseOperation completed
//@property (retain, readonly) NSMutableDictionary *pathsOldResults;

// forward declarations

- (void)startParserOperationWithData:(NSData *)data;
- (void)commitParserResults:(NSArray *)latestResults;

@end


@implementation MzTaskCollection

// Synthesize properties
@synthesize tasksURLString;
@synthesize tasksEntity;
@synthesize tasksCachePath;
@synthesize stateOfSync;
@synthesize timeToSave;
@synthesize dateFormatter;
@synthesize dateLastSynced;
@synthesize errorFromLastSync;
@synthesize getTasksOperation;
@synthesize parserOperation;
@synthesize synchronizing;
@synthesize statusOfSync;
@synthesize taskCollectionSync;
@synthesize managedObjectContext;


// Changes in the taskCollectionContext property will trigger
// KVO notifications to observers of managedObjectContext property
+ (NSSet *)keyPathsForValuesAffectingManagedObjectContext
{
    return [NSSet setWithObject:@"taskCollectionContext"];
}

// Format for the TaskCollection Cache directory
static NSString * kTaskNameTemplate = @"Tasks%.9f.%@";

// Extension for the ProductCollection Cache directory
static NSString * kTasksExtension    = @"tasks";

/* The TaskCollection Cache directory has the following files
 1- A plist file that indicates whether or not this TaskCollection has been
 abandoned (and thus removed at app startup or terminate).
 
 The plist file has one property(key) defined, which is the URL string used to
 HTTP GET the TaskCollection XML file.
 NOTE: We never actually delete the TaskCollection cache, we only update it every time the App changes
 from the background state to the active state.
 */
static NSString * kTasksFileName = @"TaskCollectionInfo.plist";
static NSString * kTasksKeyTasksURLString = @"tasksURLString";

// 2- A Core Data file that holds the MzTaskCategory, MzTaskType, MzTaskAttribute
// , MzTaskAttributeOption and MzTaskTypeImage model objects
static NSString *kTasksDataFileName    = @"Tasks.db";


#pragma mark * Initialization

// Initialize a MzTaskCollection model object
- (id)initWithTasksURLString:(NSString *)taskURLString
{
    assert(taskURLString != nil);
    
    self = [super init];
    if (self != nil) {
        self.tasksURLString = taskURLString;
        //pathsOldResults = [[NSMutableDictionary alloc] init];
        //assert(pathsOldResults!=nil);
        //self->variableRelativePath = @"default";
        
        // Register to receive a notification when the app becomes active
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        [[QLog log] logWithFormat:@"Collection cache instantiated with URL: %@", self.tasksURLString];
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

// Marks for removal a TaskCollection cache at a given path - we accomplish this by deleting the associated
// plist file
//NOTE: We never actually delete the TaskCollection cache, we only update it every time the App changes
// from the background state to the active state.
+ (void)markForRemoveCollectionCacheAtPath:(NSString *)collectionPath
{
    (void) [[NSFileManager defaultManager] removeItemAtPath:[collectionPath stringByAppendingPathComponent:kTasksFileName] error:NULL];
}

#pragma mark * TaskCollection lifecycle Management


// Method that is called when application is transitioning to the ACTIVE state
// which will lead to synchronization of the TaskCollection cache.
- (void)appDidBecomeActive:(NSNotification *)notification
{
#pragma unused(notification)
        
    //if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"collectionSyncOnActivate"] ) {
        if (self.managedObjectContext != nil) {
            
            // Ensure we complete this task even if we are moved back to BACKGROUND for example the user
            // immediately starts and closes the app
            self.taskCollectionSync = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [self startSynchronization];
            }];
        }
        
    //}
}

/*  Method that will be called by AppDelegate to start the TaskCollection lifecycle, this will
    setup the caches, database etc as needed
    TaskCollection LifeCycle
    1- when the the App is launched for the first time there is no existing TaskCollection cache
    so we create one
    2- On subsequent launches of the App, we always first check to ensure we have an TaskCollection
    cache, if we do, we update it (start synchronization) otherwise we create a new one and start it
    (startCollection method) - both tasks happen on secondary threads and do not block the main Thread
    3- Whenever we are moved from background state to active state (foreground) we update the 
    TaskCollection cache, the reason being that that UI is likely to change alot and we'd like the
    user/App to always have the latest UI setup..this all happens on secondary Threads so the main
    Thread is not blocked during these network I/O events.
*/
- (void)applicationHasLaunched {
    if (self.tasksURLString ) {
            // we can now start the Task Collection
        [self startCollection];
    } 
}

#pragma mark * Core Data Management
// Override synthesized Getter for the tasksEntity property and point to
// the MzTaskCategory entity
- (NSEntityDescription *)tasksEntity
{
    if (self->tasksEntity == nil) {
        assert(self.managedObjectContext != nil);
        self->tasksEntity = [NSEntityDescription entityForName:@"MzTaskCategory" inManagedObjectContext:self.managedObjectContext];
        assert(self->tasksEntity != nil);
    }
    return self->tasksEntity;
}

// Method to return all stored task Categories (MzTaskCategory objects)
- (NSFetchRequest *)taskCategoryFetchRequest
{
    NSFetchRequest *fetchRequest;    
    fetchRequest = [[NSFetchRequest alloc] init];
    assert(fetchRequest != nil);
    
    [fetchRequest setEntity:self.tasksEntity ];
    [fetchRequest setFetchBatchSize:10];
    
    return fetchRequest;
}

// Finds the associated CollectionCache(Path) given a tasksURLString and
// creates a new TaskCollection Cache if none is found
// NOTE that we are searching in CachesDirectory that will contain ProductCollection
// Caches as well.
- (NSString *)findCacheForTasksURLString
{
    NSString *searchResult;
    NSFileManager *fileManager;
    NSString *cachesDirectory;
    NSArray *possibleCollections;
    NSString *collectionName;
    
    assert(self.tasksURLString != nil);
    
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
        if ([collectionName hasSuffix:kTasksExtension]) {
            
            NSDictionary *collectionInfo;
            NSString *collectionInfoURLString;
            
            // Read the contents of the tasks Collection plist file
            collectionInfo = [NSDictionary dictionaryWithContentsOfFile:[[cachesDirectory stringByAppendingPathComponent:collectionName] stringByAppendingPathComponent:kTasksFileName]];
            
            if (collectionInfo != nil) {
                collectionInfoURLString = [collectionInfo objectForKey:kTasksKeyTasksURLString];
                if ( [self.tasksURLString isEqual:collectionInfoURLString] ) {
                    searchResult = [cachesDirectory stringByAppendingPathComponent:collectionName];
                    break;
                }
            }
        }
    }
    // The Caches Directories and sub-directories do not contain a Task Collection Cache
    // corresponding to the given tasksURLString, so create a new Task Collection Cache
    // and associate it with the given tasksURLString
    
    if (searchResult == nil) {
        BOOL success;
        
        collectionName = [NSString stringWithFormat:kTaskNameTemplate, [NSDate timeIntervalSinceReferenceDate], kTasksExtension];
        assert(collectionName != nil);
        
        // Create the new Task Collection Cache Directory
        searchResult = [cachesDirectory stringByAppendingPathComponent:collectionName];
        success = [fileManager createDirectoryAtPath:searchResult withIntermediateDirectories:NO attributes:NULL error:NULL];
        
        // Create the associated plist file
        if (success) {
            NSDictionary *collectionInfoFile;
            
            collectionInfoFile = [NSDictionary dictionaryWithObjectsAndKeys:self.tasksURLString, kTasksKeyTasksURLString, nil];
            assert(collectionInfoFile != nil);
            
            success = [collectionInfoFile writeToFile:[searchResult stringByAppendingPathComponent:kTasksFileName] atomically:YES];
        }
        if (!success) {
            searchResult = nil;
        }
        
        [[QLog log] logWithFormat:@"New Collection Cache created: '%@'", collectionName];
    } else {
        assert(collectionName != nil);
        [[QLog log] logWithFormat:@"Found existing Collection Cache '%@'",collectionName];
    }
    
    // Set our tasksCache property
    self.tasksCachePath = searchResult;
    
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
 Start up the Collection Cache for the tasksURLString property. This method also sets
 the taskCollectionContext and collectionCachePath properties to point to the Task Collection Cache started up 
 */
- (BOOL)setupTaskCollectionContext
{
    BOOL success;
    NSError *error;
    NSFileManager *fileManager;
    NSString *collectionPath;
    NSURL *collectionDbURL;
    NSManagedObjectModel *collectionModel;
    NSPersistentStoreCoordinator *persistentCoordinator;
    
    assert(self.tasksURLString != nil);
    
    [[QLog log] logWithFormat:@"Starting Collection Cache for URL: %@", self.tasksURLString];
    
    error = nil;
    
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    
    // Find the Collection Cache directory for this ProductCollection.
    
    collectionPath = [self findCacheForTasksURLString];
    success = (collectionPath != nil);
    
       
    // Start up CoreData in the Collection Cache directory.
    
    if (success) {
        
        NSString *collectionModelPath;
        
        collectionModelPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"MzTasksModel" ofType:@"momd"]; // should be @"momd" or @"mom"
        assert(collectionModelPath != nil);
        
        collectionModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:collectionModelPath]];
        success = (collectionModel != nil);
    }
    if (success) {
        collectionDbURL = [NSURL fileURLWithPath:[collectionPath stringByAppendingPathComponent:kTasksDataFileName]];
        assert(collectionDbURL != nil);
        
        persistentCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:collectionModel];
        success = (persistentCoordinator != nil);
    }
    if (success) {
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
        
        collectionContext = [[NSManagedObjectContext alloc] init];
        assert(collectionContext != nil);
        
        [collectionContext setPersistentStoreCoordinator:persistentCoordinator];
        self.managedObjectContext = collectionContext;
        
        // Subscribe to the context changed notification so that we can auto-save.
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(collectionContextChanged:) name:NSManagedObjectContextObjectsDidChangeNotification object:self.managedObjectContext];
        
                             
        [[QLog log] logWithFormat:@"Task Collection started successfully at Path: '%@' for URL: %@", [self.tasksCachePath lastPathComponent], self.tasksURLString];
    } else {
        
        // Log the error and return NO.
        
        if (error == nil) {
            [[QLog log] logWithFormat:@"Error starting Task Collection Cache with URL: %@", self.tasksURLString];
        } else {
            [[QLog log] logWithFormat:@"Logged error starting Collection Cache %@ with URL: %@", error, self.tasksURLString];
        }
        
        //Delete Collection caches that we tried and failed to start-up
        
        if (collectionPath != nil) {
            //[self markForRemoveCollectionCacheAtPath:collectionPath];
            /*
             As a final step:
             1- start an NSOperation to delete the Task Collection cache
             2- the DELETE operation is run on secondary Thread 
             3- On completion the DELETE operation will just quit
            */
            
            NSArray *collectionCachesToDelete = [NSArray arrayWithObject:collectionPath];
            
                static NSOperationQueue *collectionDeleteQueue;
                RecursiveDeleteOperation *operation;
                
                collectionDeleteQueue = [[NSOperationQueue alloc] init];
                assert(collectionDeleteQueue != nil);
                
                operation = [[RecursiveDeleteOperation alloc] initWithPaths:collectionCachesToDelete];
                assert(operation!= nil);
                
                if ( [operation respondsToSelector:@selector(setThreadPriority:)] ) {
                    [operation setThreadPriority:0.1];
                }
            [[QLog log] logWithFormat:@"Will delete Task Collection Cache with URL: %@", self.tasksURLString];
                
            [collectionDeleteQueue addOperation:operation];
        }
        
    }
    return success;
}

// Start the Collection Cache, create any needed files/directories if necessary
- (void)startCollection
{
    BOOL success;
    
    assert(self.tasksURLString != nil);
    
    // Start up the Collection Cache.  Abandon the Collection, and retry once more
    // on initial failure
    
    success = [self setupTaskCollectionContext];
    if ( ! success ) {
        [[QLog log] logWithFormat:@"Retry startup of Task Collection Cache with URL: %@", self.tasksURLString];
        success = [self setupTaskCollectionContext];
    }
    
    // Start the synchronization process otherwise the application is dead 
    // and we crash.
    
    if (success) {
        [self startSynchronization:nil];                
    } else {
        [[QLog log] logWithFormat:@"Failed startup of Task Collection Cache with URL: %@", self.tasksURLString];
        abort();
    }
}

// Save the Collection Cache
- (void)saveCollection
{
    NSError *error = nil;
    NSArray *errorObjects;
    
    // Typically this instance method will be called automatically after a preset
    // time interval in response to taskCollectionContext changes, so we disable the 
    // auto-save before actually saving the Collection Cache.
    
    [self.timeToSave invalidate];
    self.timeToSave = nil;
    
    // Now save.
    if ( (self.managedObjectContext != nil) && [self.managedObjectContext hasChanges] ) {
        BOOL success;
        success = [self.managedObjectContext save:&error];
        if (success) {
            error = nil;
        }
    }
    
    // Log the results.
    if (error == nil) {
        [[QLog log] logWithFormat:@"Saved Task Collection Cache with URL: %@", self.tasksURLString];
    } else {
        [[QLog log] logWithFormat:@"Task Collection Cache save Error: %@ with URL: %@", [error localizedDescription], self.tasksURLString];
        errorObjects = [[error userInfo] objectForKey:NSDetailedErrorsKey];
        for (NSError *errors in errorObjects) {
            NSLog(@"Error: %@", [errors description]);
        }
    }
}

// When the managed object context changes we start an automatic NSTimer to fire in
// kAutoSaveContextChangesTimeInterval seconds..this prevents us from saving too
// many times in too short an interval
- (void)collectionContextChanged:(NSNotification *)note
{
#pragma unused(note)
    if (self.timeToSave != nil) {
        [self.timeToSave invalidate];
    }
    self.timeToSave = [NSTimer scheduledTimerWithTimeInterval:kAutoSaveContextChangesTimeInterval target:self selector:@selector(saveCollection) userInfo:nil repeats:NO];
}

// Closes access to the Collection Cache when the application is moved to the background
- (void)stopCollection
{
    [self stopSynchronization];
    
    // Shut down the managed object context.
    
    if (self.managedObjectContext != nil) {
        
        // Stop the auto save mechanism and then force a save.
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:self.managedObjectContext];
                
        [self saveCollection];
        
        self.tasksEntity = nil;
        self.managedObjectContext = nil;
        
    }
    [[QLog log] logWithFormat:@"Stopped Collection Cache with URL: %@", self.tasksURLString];
}

#pragma mark * Main Synchronization methods

// Register all the dependent properties/keys (on StatusOfSync property) to enable
// KVO notifications for changes in any of these dependent properties
+ (NSSet *)keyPathsForValuesAffectingStatusOfSync
{
    return [NSSet setWithObjects:@"stateOfSync", @"errorFromLastSync", @"dateFormatter", @"dateLastSynced", @"getTasksOperation.retryStateClient", nil];
}

// Override getter for the KVO-observable and User-Visible StatusOfSync property
- (NSString *)statusOfSync
{
    NSString *  syncResult;
    
    if (self.errorFromLastSync == nil) {
        switch (self.stateOfSync) {
            case TaskCollectionSyncStateStopped: {
                if (self.dateLastSynced == nil) {
                    syncResult = @"Not updated";
                } else {
                    syncResult = [NSString stringWithFormat:@"Updated: %@", [self.dateFormatter stringFromDate:self.dateLastSynced]];
                }
            } break;
            default: {
                if ( (self.getTasksOperation != nil) && (self.getTasksOperation.retryStateClient == kRetryingHTTPOperationStateWaitingToRetry) ) {
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
        [[QLog log] logWithFormat:@"Task Collection Cache with URL: %@ got Sync Error: %@", self.tasksURLString, newError];
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
    
    assert([NSThread isMainThread]);
    assert(self.tasksURLString != nil);
    
    urlRequest = nil;
    
    // Construct the URL.
    
    url = [NSURL URLWithString:self.tasksURLString];
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


/* Method that starts an HTTP GET operation to retrieve the task collection's
 XML file.  */
- (void)startGetOperation:(NSString *)relativePath
{
    NSMutableURLRequest *requestURL;
    
    assert(self.stateOfSync == TaskCollectionSyncStateStopped);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Start HTTP GET for Task Collection Cache with URL %@", self.tasksURLString];
    
    requestURL = [self requestToGetCollectionRelativeString:relativePath];
    assert(requestURL != nil);
    
    assert(self.getTasksOperation == nil);
    self.getTasksOperation = [[RetryingHTTPOperation alloc] initWithRequest:requestURL];
    assert(self.getTasksOperation != nil);
    
    [self.getTasksOperation setQueuePriority:NSOperationQueuePriorityNormal];
    self.getTasksOperation.acceptableContentTypes = [NSSet setWithObjects:@"application/atom+xml", @"application/xml", @"text/xml", nil];
    
    [[NetworkManager sharedManager] addNetworkManagementOperation:self.getTasksOperation finishedTarget:self action:@selector(getCollectionOperationComplete:)];
    
    // Update the synchronization state
    self.stateOfSync = TaskCollectionSyncStateGetting;    
}

// Starts an operation to parse the product collection's XML when the HTTP GET
// operation completes succesfully
- (void)getCollectionOperationComplete:(RetryingHTTPOperation *)operation
{
    NSError *error;
    
    assert([operation isKindOfClass:[RetryingHTTPOperation class]]);
    assert(operation == self.getTasksOperation);
    assert(self.stateOfSync == TaskCollectionSyncStateGetting);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:
     @"Completed HTTP GET operation for Task Collection Cache with URL: %@", self.tasksURLString];
    
    error = operation.error;
    if (error != nil) {
        self.errorFromLastSync = error;
        self.stateOfSync = TaskCollectionSyncStateStopped;
    } else {
       /* Can dump XML contents if required by uncommenting the if block below!!! 
        if ([QLog log].isEnabled) {
            [[QLog log] logOption:kLogOptionNetworkData withFormat:@"Receive XML %@", self.getTasksOperation.responseContent];
        } */
        [self startParserOperationWithData:self.getTasksOperation.responseContent];
    }
    
    // Prepare for the next run...
    self.getTasksOperation = nil;
}

- (void)startParserOperationWithData:(NSData *)data
// Starts the operation to parse the Task Collection's XML.
{
    assert(self.stateOfSync == TaskCollectionSyncStateGetting);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Start parse for Task Collection Cache with URL: %@", self.tasksURLString];
    
    assert(self.parserOperation == nil);
    self.parserOperation = [[MzTaskParserOperation alloc] initWithXMLData:data];
    assert(self.parserOperation != nil);
    
    [self.parserOperation setQueuePriority:NSOperationQueuePriorityNormal];
    
    [[NetworkManager sharedManager] addCPUOperation:self.parserOperation finishedTarget:self action:@selector(parserOperationDone:)];
    
    self.stateOfSync = TaskCollectionSyncStateParsing;
}

// Method is called when the Collection ParserOperation completes and if successful
// commits the results to the Core Data database in our Collection Cache.
- (void)parserOperationDone:(MzTaskParserOperation *)operation
{
    assert([NSThread isMainThread]);
    assert([operation isKindOfClass:[MzTaskParserOperation class]]);
    assert(operation == self.parserOperation);
    assert(self.stateOfSync == TaskCollectionSyncStateParsing);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:
     @"Start commit of Parse Results for Task Collection Cache with URL: %@", self.tasksURLString];
    
    if (operation.parseError != nil) {
        self.errorFromLastSync = operation.parseError;
        self.stateOfSync = TaskCollectionSyncStateStopped;
    } else {
        [self commitParserResults:operation.parseResults];
        
        assert(self.errorFromLastSync == nil);
        self.dateLastSynced = [NSDate date];
        self.stateOfSync = TaskCollectionSyncStateStopped;
        [[QLog log] logWithFormat:
         @"Finished commit of Parse Results for Task Collection Cache with URL: %@", self.tasksURLString];        
    }
    
    // Prepare for the next run..
    self.parserOperation = nil;
}

// Commit the parseResults to the Core Data database
- (void)commitParserResults:(NSArray *)parserResults {
    
    assert(parserResults != nil);
    BOOL databaseIsPopulated = NO;
    
    // Update, delete, insert the new task categories, types and attributes accordingly
    
    /*
     Algorithm
     1- create a dictionary where keys are categoryIds and values are all MzTaskCategory
     objects in the database
     2- create an array with the unique categoryIds from the parserResults
      - create a dictionary with unique categoryIds as keys and unique NSDictionary's from the
     parserResults as values
     3- create a set whose values are all the keys in the dictionary in step 1
     4- if a categoryId is in the array (step 2) and not in the dictionary -> insert a new
     MzTaskCategory object + update this object with dictionary in the parserResults
     5- if a categoryId is in both the array and dictionary above -> update the MzTaskCategory
     object
     6- if a categoryId is in the dictionary but not in the array -> delete the associated
     MzTaskCategory object (delete operations are cascade in the managedobject model)
             
     */
        
    if ([parserResults count] > 0) {
        
        NSMutableSet *taskCategorySet;      // set of CategoryId's from parserResults
        NSArray *retrievedCategory;         // array of MzTaskCategory objects from database
        NSError *fetchCategoryError;        // error from fetching from the database
        NSArray * taskCategory;             // array of CategoryId's from parserResults
        NSMutableDictionary *categoryDict;
        NSMutableSet *categorySet;
        NSMutableDictionary *uniqueTasks;
        MzTaskCategory *insertCategory;
        NSMutableArray *insertArray;
                       
        // create an array with the unique categoryIds and dictionary
        NSString *categoryId;
        NSString *uniqueCategoryId;
        uniqueCategoryId = [NSString string];
        assert(uniqueCategoryId != nil);
        uniqueTasks = [NSMutableDictionary dictionary];
        assert(uniqueTasks != nil);
        taskCategorySet = [NSMutableSet set];
        assert(taskCategorySet != nil);
        insertArray = [NSMutableArray array];
        assert(insertArray != nil);        
        
        for (NSDictionary *task in parserResults) {
            
            // category
            categoryId = [task objectForKey:kTaskParserResultCategoryId];
            assert([categoryId isKindOfClass:[NSString class]]);
            
            if ([categoryId isEqualToString:uniqueCategoryId]) {
                
                // we've seen this before so skip it...                
                
            } else {
                // we use a an NSMutableSet so we absolutely ensure have no duplicates
                [uniqueTasks setObject:task forKey:categoryId];
                [taskCategorySet addObject:categoryId];
                uniqueCategoryId = categoryId;  // keep track of the "old" value of categoryId
            }                       
        }
        
        // convert to array for performance reasons
        assert([taskCategorySet count] > 0);
        taskCategory = [taskCategorySet allObjects];
        assert(taskCategory != nil);
        
        // Get the taskCategory objects from the database & create the dictionary
        categoryDict = [NSMutableDictionary dictionary];
        assert(categoryDict != nil);
        
        NSFetchRequest *fetchCategory = [self taskCategoryFetchRequest];
        assert(fetchCategory != nil);
        [fetchCategory setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"taskTypes"]];
        retrievedCategory = [self.managedObjectContext executeFetchRequest:fetchCategory error:&fetchCategoryError];
        assert(retrievedCategory != nil);
                
        if ([retrievedCategory count] > 0) {
            
            // Log and notify
            databaseIsPopulated = YES;
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:
             @"Number of Categories in DB is: %d for Task Collection Cache with URL: %@", [retrievedCategory count] ,self.tasksURLString];
            
            for (MzTaskCategory *category in retrievedCategory) {
                [categoryDict setObject:category forKey:category.categoryId];
            }
            
            // create the array of all keys
            categorySet = [NSMutableSet setWithArray:[categoryDict allKeys]];
            assert(categorySet != nil);
            
            // do the deletes
            [categorySet enumerateObjectsUsingBlock:^(NSString *str, BOOL *stop) {
                if ([taskCategorySet member:str] == nil) {
                                      
                    [self.managedObjectContext deleteObject:[categoryDict objectForKey:str]];
                    
                }
            }];                        
            
            // check for inserts, updates, deletes
            NSUInteger count = 0;
            for (NSString *strCategory in taskCategory) {
                
                if ([categoryDict objectForKey:strCategory] != nil) {
                    
                    // update the exiting TaskCategory objects
                    for (NSDictionary *task in parserResults) {
                        
                        [[categoryDict objectForKey:strCategory] updateWithProperties:task inManagedObjectContext:self.managedObjectContext];
                    } 
                    
                    // check if we need to delete some TaskTypes or TaskAttributes of this
                    // TaskCategory
                    //[self checkToDeleteTaskTypesAttributes:[categoryDict objectForKey:strCategory] withResults:parserResults];
                    
                } else {
                    
                    // do the insert the non-existent TaskCategory
                    insertCategory = [MzTaskCategory insertNewMzTaskCategoryWithProperties:[uniqueTasks objectForKey:strCategory] inManagedObjectContext:self.managedObjectContext];
                    assert(insertCategory != nil);
                    [insertArray addObject:[insertCategory objectID]];
                    count++;
                }
            }
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:
             @" %d New Categories added to DB: for Task Collection Cache with URL: %@", count ,self.tasksURLString];
            
        } else {
            
            // we have an empty database
            NSArray *tasks;            
                        
            // create an intial MzTaskCategory object with 1 MzTaskType child that also has 1
            // MzTaskAttribute child that has a set of MzAttributeOptions for unique CategoryId
            // identified in the parserResults
            if ([uniqueTasks count] > 0) {
                tasks = [uniqueTasks allValues];
                for (NSDictionary * task in tasks) {
                    
                    insertCategory = [MzTaskCategory insertNewMzTaskCategoryWithProperties:task inManagedObjectContext:self.managedObjectContext];
                    assert(insertCategory != nil);
                    [insertArray addObject:[insertCategory objectID]];     //use ObjectIDs
                }
                databaseIsPopulated = YES;
                [[QLog log] logOption:kLogOptionSyncDetails withFormat:
                 @" %d New initial categories inserted in DB: for Task Collection Cache with URL: %@", [uniqueTasks count] ,self.tasksURLString];
                
            }
        }
        
        // Retrieve the MzTaskCategory objects inserted above and update them and then save all the changes
        // Note that we have to follow the insert operation with an update operation because each NSDictionary
        // in the NSArray of parserResults represents one branch of the taskCategory tree - refer to the 
        // relevant XML schema...so we update to add all branches to complete the taskCategory tree
        NSError *error = NULL;
        MzTaskCategory *categoryResult;
        
        if ([insertArray count] > 0) {
             for (NSManagedObjectID *insertId in insertArray) {
                 
                 categoryResult = (MzTaskCategory *)[self.managedObjectContext existingObjectWithID:insertId error:&error];
                 assert(categoryResult != nil);
                 
                 // update the MzTaskCategory object to build out object graph
                 if (!error) {
                     for (NSDictionary *parse in parserResults) {
                         
                         [categoryResult updateWithProperties:parse inManagedObjectContext:self.managedObjectContext];
                     }

                 } else {
                     [[QLog log] logOption:kLogOptionSyncDetails withFormat:
                      @"Error retrieving TaskCategory with ObjectID with error: %@", error.localizedDescription];
                 }
                
            }            

        }
        
        // Finally, we update the MzQueryItems and delete as required
        // Test Database State
        if (databaseIsPopulated) {
            
            [self checkDatabase];   // testing purposes only
            [self updateMzQueryItemEntity];
            [self deleteTaskTypesAndAttributesForResults:parserResults inManagedObjectContext:self.managedObjectContext];
        }       
       
    } else {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Empty Parse Results array for Task Collection Cache with URL: %@", self.tasksURLString];
    }
    
}

// Method checks the MzTaskType and MzTaskAttribute objects 
// in the database against the parserResults and deletes the
// objects in the database if they do not match the parserResults
// Note that this method will only be called if the database is populated.
- (void) deleteTaskTypesAndAttributesForResults:(NSArray *)parseResult inManagedObjectContext:context
{
    /*1- create a set with all the taskTypeIds in the parserResults for each categoryId
        i) get all the taskType objects for each categoryId in the database
        iii) delete all taskType objects in the database but not in the set
      2- create a set with all the taskAttributeIds in the parserResults for each categoryId
        i) get all the taskAttribute objects for a set of taskTypeId's in the database
        ii) delete all taskAttribute objects in the database but not in the set */
    
    assert(parseResult != nil);
    assert(context != nil);
    
    NSMutableSet *taskTypeSet;
    NSMutableSet *taskAttributeSet;
    NSArray *taskTypeArray;
    NSArray *taskAttributeArray;
    
    // Initialize the sets
    taskTypeSet = [NSMutableSet set];
    taskAttributeSet = [NSMutableSet set];
    assert(taskTypeSet != nil);
    assert(taskAttributeSet != nil);
    
    NSString *taskTypeId;
    NSString *uniqueTaskTypeId = [NSString string];
    assert(uniqueTaskTypeId != nil);
    NSString *taskAttributeId;
    NSString *uniqueAttributeId = [NSString string];
        
    // Create the sets of unique taskTypeIds and taskAttributeIds from the parseResult
    for (NSDictionary *task in parseResult) {
        
        // taskType
        taskTypeId = [task objectForKey:kTaskParserResultTaskTypeId];
        assert([taskTypeId isKindOfClass:[NSString class]]);
        
        if ([taskTypeId isEqualToString:uniqueTaskTypeId]) {
            
            // do nothing, we've seen this taskTypeId before, so skip...
        } else {
            // we use a an NSMutableSet so we have no duplicates
            [taskTypeSet addObject:taskTypeId];
            uniqueTaskTypeId = taskTypeId;  // keep track of the "old" value of taskTypeId
        }
        
        // taskAttribute
        taskAttributeId = [task objectForKey:kTaskParserResultTaskAttributeId];
        assert(taskAttributeId != nil);
        
        if ([taskAttributeId isEqualToString:uniqueAttributeId]) {
            
            // do nothing, we've seen this taskAttributeId before, so skip...
        } else {
            // we use a an NSMutableSet so we have no duplicates
            [taskAttributeSet addObject:taskAttributeId];
            uniqueAttributeId = taskAttributeId;  // keep track of the "old" value of taskAttributeId
        }

    }
    // convert to array
    taskTypeArray = [taskTypeSet allObjects];
    assert(taskTypeArray != nil);
    taskAttributeArray = [taskAttributeSet allObjects];
    assert(taskAttributeArray != nil);
        
    if ([taskTypeArray count] == 0) {
        
        // return, we have nothing to do
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"No taskTypeIds found in parseResults for Task Collection with URL: %@", self.tasksURLString];
        return;
    }
    
    /* Retrieve the MzTaskType objects from the database */
    NSError *fetchTaskError = NULL;
    NSError *fetchAttributeError = NULL;
    NSArray *retrievedTasks;
    NSArray *retrievedAttributes;
    
    // TaskType Fetches
    NSFetchRequest *fetchTaskTypes = [NSFetchRequest fetchRequestWithEntityName:@"MzTaskType"];
    assert(fetchTaskTypes != nil);
    retrievedTasks = [context executeFetchRequest:fetchTaskTypes error:&fetchTaskError];
    assert(retrievedTasks != nil);
    
    // TaskAttributes Fetches
    NSFetchRequest *fetchAttributes = [NSFetchRequest fetchRequestWithEntityName:@"MzTaskAttribute"];
    assert(fetchAttributes != nil);
    retrievedAttributes = [context executeFetchRequest:fetchAttributes error:&fetchAttributeError];
    assert(retrievedAttributes != nil);
             
     // Log any errors
     if (fetchTaskError) {
     [[QLog log] logOption:kLogOptionSyncDetails withFormat:
     @"Encountered error: %@ during taskType fetch for Task Collection with URL: %@",[fetchTaskError localizedDescription] ,self.tasksURLString];
         return;
     }
    if (fetchAttributeError) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Encountered error: %@ during taskAttribute fetch for Task Collection with URL: %@",[fetchAttributeError localizedDescription] ,self.tasksURLString];
        return;
    }
    
    // Create dictionaries for the retrieved Managed Objects which we use
    // to check which objects to delete
    NSMutableDictionary *taskDict;
    NSMutableDictionary *attributeDict;
    NSMutableSet *taskTypeToRemove;
    NSMutableSet *attributeToRemove;
    
    // Iterate over the retrieved TaskTypes
    if ([retrievedTasks count] > 0) {
        taskDict = [NSMutableDictionary dictionary];
        assert(taskDict != nil);
        
        for (MzTaskType *task in retrievedTasks) {
            [taskDict setObject:task forKey:task.taskTypeId];
        }
        taskTypeToRemove = [NSMutableSet setWithArray:[taskDict allKeys]];
        assert(taskTypeToRemove != nil);
    }
    
    // Iterate over the retrieved TaskAttributes
    if ([retrievedAttributes count] > 0) {
        attributeDict = [NSMutableDictionary dictionary];
        assert(attributeDict != nil);
        
        for (MzTaskAttribute *attribute in retrievedAttributes) {
            [attributeDict setObject:attribute forKey:attribute.taskAttributeId];
        }
        attributeToRemove = [NSMutableSet setWithArray:[attributeDict allKeys]];
        assert(attributeToRemove != nil);
    }
    
    // We are now ready to do the deletes
    __block NSUInteger countTasks = 0;
    __block NSUInteger countAttributes = 0;
    if ([taskTypeToRemove count] > 0) {
        [taskTypeToRemove enumerateObjectsUsingBlock:
         ^(NSString *taskString, BOOL *stop) {
             
             if ([taskTypeSet member:taskString] == nil) {
                 [context deleteObject:[taskDict objectForKey:taskString]];
                 countTasks++;
             }
         }];
    }
    
    if ([attributeToRemove count] > 0) {
        [attributeToRemove enumerateObjectsUsingBlock:
         ^(NSString *attributeString, BOOL *stop) {
             
             if ([taskAttributeSet member:attributeString] == nil) {
                 [context deleteObject:[attributeDict objectForKey:attributeString]];
                 countAttributes++;
             }
         }];
    }
    
    // Log
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:
     @"Deleted %d MzTaskType objects in database for Task Collection with URL: %@", countTasks, self.tasksURLString];
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:
     @"Deleted %d MzTaskAttribute objects in database for Task Collection with URL: %@", countAttributes, self.tasksURLString];   
   
}

// Updates, inserts, deletes MzQueryItem objects in the MzQueryItem entity, this method is
// called when our managedObjectContext sends a ...NSManagedObjectContextDidSaveNotification
-(void)updateMzQueryItemEntity
{    
    assert(self.managedObjectContext != nil);
    
    // Update the MzQueryItems
    [MzQueryItem updateMzQueryItemsInManagedObjectContext:self.managedObjectContext];
            
    // Log
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:
     @"Finished update of QueryItems in database for Task Collection Cache with URL: %@" ,self.tasksURLString];    
    
}

-(void)checkDatabase
{
    // Testing code
    NSArray *retrievedTasks;
    NSError *tasksError;
    NSFetchRequest *request;
    NSFetchRequest *requestAttribute;
    NSArray *retrievedAttributes;
    NSError *attributeError;
    
    // Check number of TaskTypes
    request = [[NSFetchRequest alloc] initWithEntityName:@"MzTaskType"];
    assert(request != nil);
    [request setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"taskAttributes"]];
    
    retrievedTasks = [self.managedObjectContext executeFetchRequest:request error:&tasksError];
    assert(retrievedTasks != nil);
    [[QLog log] logWithFormat:@"No of TaskTypes: %d saved in Task Collection Cache with URL: %@", [retrievedTasks count], self.tasksURLString];
    
    // Testing code
    for (MzTaskType *task in retrievedTasks) {
        NSLog(@"TaskType name: %@", task.taskTypeName);
        //assert(task.taskCategory != nil);
    }

   // check number of TaskAttributes
    requestAttribute =[[NSFetchRequest alloc] initWithEntityName:@"MzTaskAttribute"];
    assert(requestAttribute != nil);
    retrievedAttributes = [self.managedObjectContext executeFetchRequest:requestAttribute error:&attributeError];
    assert(retrievedAttributes != nil);
    [[QLog log] logWithFormat:@"No of TaskAttributes: %d saved in Task Collection Cache with URL: %@", [retrievedAttributes count], self.tasksURLString];   
}


// Register the isSyncing as a dependent key for KVO notifications
+ (NSSet *)keyPathsForValuesAffectingSynchronizing
{
    return [NSSet setWithObject:@"stateOfSync"];
}

// Getter for isSyncing property
- (BOOL)isSynchronizing
{
    return (self->stateOfSync > TaskCollectionSyncStateStopped);
}

+ (BOOL)automaticallyNotifiesObserversOfStateOfSync
{
    return NO;
}

// Setter for the stateOfSync property, this property is KVO-observable
- (void)setStateOfSync:(TaskCollectionSyncState)newValue
{
    if (newValue != self->stateOfSync) {
        BOOL    isSyncingChanged;
        
        isSyncingChanged = (self->stateOfSync > TaskCollectionSyncStateStopped) != (newValue > TaskCollectionSyncStateStopped);
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
        if (self.stateOfSync == TaskCollectionSyncStateStopped) {
            [[QLog log] logWithFormat:@"Start synchronization for Task Collection Cache with URL: %@",
             self.tasksURLString];
            assert(self.getTasksOperation == nil);
            self.errorFromLastSync = nil;
            [self startGetOperation:relativePath];
        }
    }
}

// Method that stops the synchronization process
- (void)stopSynchronization
{
    if (self.isSynchronizing) {
        if (self.getTasksOperation != nil) {
            [[NetworkManager sharedManager] cancelOperation:self.getTasksOperation];
            self.getTasksOperation = nil;
        }
        if (self.parserOperation) {
            [[NetworkManager sharedManager] cancelOperation:self.parserOperation];
            self.parserOperation = nil;
        }
        self.errorFromLastSync = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
        self.stateOfSync = TaskCollectionSyncStateStopped;
        [[QLog log] logWithFormat:@"Stopped synchronization for Collection Cache with URL: %@", self.tasksURLString];
    }
}



@end
