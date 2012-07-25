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
    
    if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"collectionSyncOnActivate"] ) {
        if (self.taskCollectionContext != nil) {
            [self startSynchronization];
        }
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
        [self startSynchronization];                
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
    self.getTasksOperation.acceptableContentTypes = [NSSet setWithObjects:@"application/xml", @"text/xml", nil];
    
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
        if ([QLog log].isEnabled) {
            [[QLog log] logOption:kLogOptionNetworkData withFormat:@"Receive XML %@", self.getTasksOperation.responseContent];
        }
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
         @"Successfully synced Task Collection Cache with URL: %@", self.tasksURLString];        
    }
    
    // Prepare for the next run..
    self.parserOperation = nil;
}


@end
