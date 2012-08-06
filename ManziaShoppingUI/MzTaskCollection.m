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
@property (nonatomic, retain, readwrite)MzTaskCollectionContext* taskCollectionContext;
@property (nonatomic, copy, readonly) NSString *tasksCachePath;
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
@synthesize taskCollectionContext;
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

// Other Getters
-(id)managedObjectContext
{
    return self.taskCollectionContext;
}

//Override getter and maintain KVC compliance
- (NSString *)tasksCachePath
{
    assert(self.taskCollectionContext != nil);
    return self.taskCollectionContext.tasksCachePath;
}

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
static NSString * kTasksDataFileName    = @"Tasks.db";


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
        if (self.taskCollectionContext != nil) {
            
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
        assert(self.taskCollectionContext != nil);
        self->tasksEntity = [NSEntityDescription entityForName:@"MzTaskCategory" inManagedObjectContext:self.taskCollectionContext];
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
        MzTaskCollectionContext *collectionContext;
        
        collectionContext = [[MzTaskCollectionContext alloc] initWithTasksURLString:self.tasksURLString cachePath:collectionPath];
        assert(collectionContext != nil);
        
        [collectionContext setPersistentStoreCoordinator:persistentCoordinator];
        self.taskCollectionContext = collectionContext;
        
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
    
    // Typically this instance method will be called automatically after a preset
    // time interval in response to taskCollectionContext changes, so we disable the 
    // auto-save before actually saving the Collection Cache.
    
    [self.timeToSave invalidate];
    self.timeToSave = nil;
    
    // Now save.
    if ( (self.taskCollectionContext != nil) && [self.taskCollectionContext hasChanges] ) {
        BOOL success;
        success = [self.taskCollectionContext save:&error];
        if (success) {
            error = nil;
        }
    }
    
    // Log the results.
    if (error == nil) {
        [[QLog log] logWithFormat:@"Saved Task Collection Cache with URL: %@", self.tasksURLString];
    } else {
        [[QLog log] logWithFormat:@"Task Collection Cache save Error: %@ with URL: %@", error, self.tasksURLString];
    }
}

// When the managed object context changes we start an automatic NSTimer to fire in
// kAutoSaveContextChangesTimeInterval seconds
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
    
    if (self.taskCollectionContext != nil) {
        
        // Stop the auto save mechanism and then force a save.
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:self.taskCollectionContext];
        
        [self saveCollection];
        
        self.tasksEntity = nil;
        self.taskCollectionContext = nil;
        
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

/* Method that starts an HTTP GET operation to retrieve the task collection's
 XML file.  */
- (void)startGetOperation:(NSString *)relativePath
{
    NSMutableURLRequest *requestURL;
    
    assert(self.stateOfSync == TaskCollectionSyncStateStopped);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Start HTTP GET for Task Collection Cache with URL %@", self.tasksURLString];
    
    requestURL = [self.taskCollectionContext requestToGetCollectionRelativeString:relativePath];
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
     @"Parsing complete for Task Collection Cache with URL: %@", self.tasksURLString];
    
    if (operation.parseError != nil) {
        self.errorFromLastSync = operation.parseError;
        self.stateOfSync = TaskCollectionSyncStateStopped;
    } else {
        [self commitParserResults:operation.parseResults];
        
        assert(self.errorFromLastSync == nil);
        self.dateLastSynced = [NSDate date];
        self.stateOfSync = TaskCollectionSyncStateStopped;
        [[QLog log] logWithFormat:
         @"Start commit of Parse Results for Task Collection Cache with URL: %@", self.tasksURLString];        
    }
    
    // Prepare for the next run..
    self.parserOperation = nil;
}

// Commit the parseResults to the Core Data database
- (void)commitParserResults:(NSArray *)parserResults {
    
    assert(parserResults != nil);
    
    // Update, delete, insert the new task categories, types and attributes accordingly
    
    /*
     Algorithm
     1- create a set with all the categoryIds in the parserResults
        i) get all the taskCategory objects in the database
        ii) compare each categoryId from parserResults to that from database
        iii) return, insert, delete accordingly based on comparison result above
             
     */
    
    if ([parserResults count] > 0) {
        
        NSMutableSet *taskCategorySet;      // set of CategoryId's from parserResults
        NSArray *retrievedCategory;         // array of MzTaskCategory objects from database
        NSError *fetchCategoryError;        // error from fetching from the database
        NSMutableArray *categoryToRemove;   // MzTaskCategory objects not reflected in the parserResults
        NSArray * taskCategory;             // array of CategoryId's from parserResults
                       
        // Get the taskCategory objects from the database
        NSFetchRequest *fetchCategory = [self taskCategoryFetchRequest];
        assert(fetchCategory != nil);
        retrievedCategory = [self.managedObjectContext executeFetchRequest:fetchCategory error:&fetchCategoryError];
        assert(retrievedCategory != nil);
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Number of Categories in DB is: %d for Task Collection Cache with URL: %@", [retrievedCategory count] ,self.tasksURLString];
        
        // Create the set of categoryIds we got from the parserResults
        taskCategorySet = [NSMutableSet set];
        assert(taskCategorySet != nil);
        NSString *categoryId;
        NSString *uniqueCategoryId;
        uniqueCategoryId = [NSString string];
        assert(uniqueCategoryId != nil);
        
        for (NSDictionary *task in parserResults) {
                                               
            // category
            categoryId = [task objectForKey:kTaskParserResultCategoryId];
            assert([categoryId isKindOfClass:[NSString class]]);
                        
            if ([categoryId isEqualToString:uniqueCategoryId]) {
                
                // do nothing, we've seen this categoryId before, so skip...
            } else {
                // we use a an NSMutableSet so we have no duplicates
                [taskCategorySet addObject:categoryId];
                uniqueCategoryId = categoryId;  // keep track of the "old" value of categoryId
            }                       
        }
        
        // convert to array for performance reasons
        assert([taskCategorySet count] > 0);
        taskCategory = [taskCategorySet allObjects];
        assert(taskCategory != nil); 
        
        // find all the taskCategory objects in database not in the set created from parserResults
        categoryToRemove = [NSMutableArray array];
        if ([retrievedCategory count] > 0) {
            BOOL foundCategory = NO;
            
            // May need to revisit this block of code its N^3 (cubic) loop but fortunately N is likely to be
            // very small, 1 to 5.
            for (MzTaskCategory *existingCategory in retrievedCategory) {
                for (NSString *category in taskCategory) {
                    if ([existingCategory.categoryId isEqualToString:category]) {
                        
                        /* This looks untidy but the its warranted by the nature of the task i.e, we need to be able to automatically update existing taskCategory's but I'm not seeing a really efficient way of determining when to update !!!! */
                        for (NSDictionary *task in parserResults) {
                            if ([existingCategory.categoryId isEqualToString:[task objectForKey:kTaskParserResultCategoryId]]) {
                                [existingCategory updateWithProperties:task inManagedObjectContext:self.managedObjectContext];
                            }
                        }                        
                        foundCategory = YES;
                        break;          // no need to continue
                    }
                }
                // we remove those taskCategory's in the database not in our new categoryId array
                if (!foundCategory) {
                    [categoryToRemove addObject:existingCategory];
                } else {
                    
                    // Check if we need to delete the taskTypes or taskAttributes of
                    // any of the existing taskCategory's
                    [self checkToDeleteTaskTypesAttributes:existingCategory withResults:parserResults];
                }
                foundCategory = NO;         // reset
            }
            // delete
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:
             @"Number of Categories deleted is: %d for Task Collection Cache with URL: %@", [categoryToRemove count] ,self.tasksURLString];
            
            if ([categoryToRemove count] > 0) {
                for (MzTaskCategory *deleteCategory in categoryToRemove) {
                    [self.managedObjectContext deleteObject:deleteCategory];                     
                }
            
            }
        } else {
             // we have an empty database so we populate with all the parseResults, one taskCategory
            // at a time. Most likely we are populating the database for the first time
                        // Insert the new TaskCategory's
            if ([taskCategory count] > 0) {
                for (NSDictionary *categoryDict in parserResults) {
                    [MzTaskCategory insertNewMzTaskCategoryWithProperties:categoryDict inManagedObjectContext:self.managedObjectContext];                    
                }
                [[QLog log] logOption:kLogOptionSyncDetails withFormat:
                 @" %d New Categories inserted in DB: %@ for Task Collection Cache with URL: %@", [taskCategory count] ,self.tasksURLString];
                
            } else {
                
                // weird scenario - we have no TaskCategory's in the database and none in the parseResults
                [[QLog log] logOption:kLogOptionSyncDetails withFormat:
                 @"Weird Case - No Category in Database or Parse Results for Task Collection Cache with URL: %@", self.tasksURLString];                
            }           
                                             
            
            // Retrieve the MzTaskCategory objects inserted above and update them and then save all the changes
            // Note that we have to follow the insert operation with an update operation because each NSDictionary
            // in the NSArray of parserResults represents one branch of the taskCategory tree - refer to the 
            // relevant XML schema...so we update to add all branches to complete the taskCategory tree
            NSSet *insertedCategories;
            insertedCategories = [self.managedObjectContext insertedObjects];
            assert(insertedCategories != nil);
            if ([insertedCategories count] > 0) {
                
                [insertedCategories enumerateObjectsUsingBlock:^(id category, BOOL *stop) {
                    if ([category isKindOfClass:[MzTaskCategory class]]) {
                        for (NSDictionary *task in parserResults) {
                                [category updateWithProperties:task inManagedObjectContext:self.managedObjectContext];                            
                        }                            
                    }
                    
                }];
            } else {
                [[QLog log] logOption:kLogOptionSyncDetails withFormat:
                 @"Empty initial Task Collection with URL: %@", self.tasksURLString];
            }
        }        
        
    } else {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Empty Parse Results array for Task Collection Cache with URL: %@", self.tasksURLString];
    }
}

// Method checks the MzTaskType and MzTaskAttribute objects associated with
// a MzTaskCategory in the database against the parserResults and deletes the
// objects in the database if they do not match the parserResults
- (void) checkToDeleteTaskTypesAttributes:(MzTaskCategory *)taskCategory withResults:(NSArray *)parseResult
{
    /*1- create a set with all the taskTypeIds in the parserResults for each categoryId
        i) get all the taskType objects for each categoryId in the database
        iii) delete all taskType objects in the database but not in the set
      2- create a set with all the taskAttributeIds in the parserResults for each categoryId
        i) get all the taskAttribute objects for a set of taskTypeId's in the database
        ii) delete all taskAttribute objects in the database but not in the set */
    
    assert(taskCategory != nil);
    assert(parseResult != nil);
    assert(taskCategory.taskTypes != nil);
    
    NSMutableSet *taskTypeSet;
    NSMutableSet *taskAttributeSet;
    //NSError *fetchTaskError;
    //NSArray *retrievedTasks;
    NSMutableArray *taskTypeToKeep;
    NSArray *taskTypeArray;
    NSArray *taskAttributeArray;
    
    // Initialize the sets
    taskTypeSet = [NSMutableSet set];
    taskAttributeSet = [NSMutableSet set];
    assert(taskTypeSet != nil);
    assert(taskAttributeSet != nil);
    
    //NSString *taskTypeProperty = @"taskCategory.categoryId";
    //NSString *taskTypeValue = taskCategory.categoryId;
    //NSString *taskAttributeProperty = @"taskType.taskTypeId";
    //NSString *taskAttributeValue;
    NSString *taskTypeId;
    NSString *uniqueTaskTypeId = [NSString string];
    assert(uniqueTaskTypeId != nil);
    NSString *taskAttributeId;
    NSString *uniqueAttributeId = [NSString string];
    NSIndexSet *result;
    NSIndexSet *resultAttribute;
    
    /* Retrieve the MzTaskType objects from the database
    fetchTaskError = NULL;
    NSPredicate *taskTypePredicate = [NSPredicate predicateWithFormat:@"%K like %@", taskTypeProperty, taskTypeValue];
    NSFetchRequest *fetchTaskTypes = [NSFetchRequest fetchRequestWithEntityName:@"MzTaskType"];
    assert(fetchTaskTypes != nil);
    [fetchTaskTypes setPredicate:taskTypePredicate];
    [fetchTaskTypes setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"taskAttributes"]];
    
    retrievedTasks = [self.taskCollectionContext executeFetchRequest:fetchTaskTypes error:&fetchTaskError];
    assert(retrievedTasks != nil);
    
    // Log any error
    if (fetchTaskError) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Encountered error: %@ during taskType fetch for Task Collection with URL: %@",[fetchTaskError localizedDescription] ,self.tasksURLString];
    } */
    
    // Create the sets from the parseResult
    for (NSDictionary *task in parseResult) {
        
        // taskType
        taskTypeId = [task objectForKey:kTaskParserResultTaskTypeId];
        assert([taskTypeId isKindOfClass:[NSString class]]);
        
        if ([taskTypeId isEqualToString:uniqueTaskTypeId]) {
            
            // do nothing, we've seen this taskTypeId before, so skip...
        } else {
            // we use a an NSMutableSet so we have no duplicates
            [taskTypeSet addObject:taskTypeId];
            uniqueTaskTypeId = taskTypeId;  // keep track of the "old" value of categoryId
        }
        
        // taskAttribute
        taskAttributeId = [task objectForKey:kTaskParserResultTaskAttributeId];
        assert(taskAttributeId != nil);
        
        if ([taskAttributeId isEqualToString:uniqueAttributeId]) {
            
            // do nothing, we've seen this taskAttributeId before, so skip...
        } else {
            // we use a an NSMutableSet so we have no duplicates
            [taskAttributeSet addObject:taskAttributeId];
            uniqueAttributeId = taskAttributeId;  // keep track of the "old" value of categoryId
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
    
    // find all the taskType objects in database not in the set created from parserResults
    // if we got no TaskType objects from the database we do nothing, this scenario is covered in the 
    // commitParserResults instance method...so no worries
    // Iterate over all the taskType objects
    
    taskTypeToKeep = [NSMutableArray array];   // array of MzTaskType object to keep
    
    if ([taskCategory.taskTypes count] > 0) {
        for (NSString *taskString in taskTypeArray) {
            result = [taskCategory.taskTypes indexesOfObjectsPassingTest:
                      ^(MzTaskType *obj, NSUInteger idx, BOOL *stop) {
                          if ([obj.taskTypeId isEqualToString:taskString]) {
                              
                              [taskTypeToKeep addObject:obj];
                              return NO;   // keep looking
                          } else {
                              
                              //Update the MzQueryItems
                              [MzQueryItem deleteAllQueryItemsForTaskType:obj inManagedObjectContext:self.managedObjectContext];
                              return  YES;   // found non-match
                          }    
                      }];
        }
        
        if ([result firstIndex] != NSNotFound) {
            // we can safely delete the TaskType objects that did not match
            [taskCategory removeTaskTypesAtIndexes:result];                        
        }
    }
    
    // Repeat for the TaskAttributes
    if ([taskTypeToKeep count] == 0) {
        
        // nothing to do..
        return;
    } else {
        // check taskAttributes
        for (MzTaskType *task in taskTypeToKeep) {
            
            for (NSString *attributeString in taskAttributeArray) {
                resultAttribute = [task.taskAttributes indexesOfObjectsPassingTest:
                                   ^(MzTaskAttribute *attribute, NSUInteger idx, BOOL *stop) {
                                       if ([attribute.taskAttributeId isEqualToString:attributeString]) {
                                           
                                           return NO;   // keep looking
                                       } else {
                                           return YES;  // found non-match
                                       }
                                   }];
                                   
            }
            if ([resultAttribute firstIndex] != NSNotFound) {
                // we can safely delete the TaskAttribute objects
                [task removeTaskAttributesAtIndexes:resultAttribute];
            }
            resultAttribute = nil;  // reset
        }
        
    }


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
