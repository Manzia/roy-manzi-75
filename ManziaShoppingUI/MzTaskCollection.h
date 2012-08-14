//
//  MzTaskCollection.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
/*
 CLASS DESCRIPTION:
 This model class represents the tasks that a user can set up in the application. The
 tasks are stored in a Core Data database
 
 OPERATION:
 1- A task collection XML file is downloaded from the Manzia servers whenever the application
 moves from the background state to the active state. The download operation is conducted on
 a secondary thread/queue so as not to block the main thread.
 
 2- The task collection XML file is associated with a specific URL (on the Manzia servers). The XML
 file is downloaded and parsed on secondary threads using the NSOperation class and the 
 NSOperationQueue class to encapsulate and execute these operations.
 
 3- The task categories, types, attributes and attribute options described in the XML file
 are downloaded and stored in a Core Data database within the CachesDirectory. If an XML file
 already exists only the changes if any are committed to the database.
 
 4- The thumbNail image data for each task type and category is stored in a separate entity within 
 the same Core Data database in the CachesDirectory
 
 5- A background process is run on application startup and termination to clean up the 
 CachesDirectory and delete "abandoned" databases. The same background process will activate 
 during low memory situations and warnings
 
 6- The user has the ability to clear all caches in Settings
 
 7- The user has the ability to set the logging level - important for networking based apps
 
 8- This class exports the NSManagedObjectContext and TaskEntity required by the
 MzTaskCategoryViewController, MzTaskTypeViewController, MzTaskAttributeViewConroller
 and MzTaskAttributeOptionsViewController that update their views
 in response to NSManagedObjectContext changes
  
 */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskCollectionContext;
@class RetryingHTTPOperation;
@class MzTaskParserOperation;

enum TaskCollectionSyncState {
    
    TaskCollectionSyncStateStopped, 
    TaskCollectionSyncStateGetting, 
    TaskCollectionSyncStateParsing, 
    TaskCollectionSyncStateCommitting
};
typedef enum TaskCollectionSyncState TaskCollectionSyncState;

@interface MzTaskCollection : NSObject {
    NSString *tasksURLString;
    NSEntityDescription *tasksEntity;       // MzTaskCategory entity
    NSDate *dateLastSynced;
    TaskCollectionSyncState stateOfSync;
    NSError *errorFromLastSync;
    NSTimer *timeToSave;
    RetryingHTTPOperation *getTasksOperation;
    MzTaskParserOperation *parserOperation;
    UIBackgroundTaskIdentifier taskCollectionSync;
}

// Properties related to Data Management
@property(nonatomic, copy, readonly) NSString *tasksURLString;
@property(nonatomic, retain, readonly)NSManagedObjectContext *managedObjectContext;
@property(nonatomic, retain, readonly)NSEntityDescription *tasksEntity;

// Properties that enable the control of the syncing process
@property (nonatomic, assign, readonly, getter=isSynchronizing) BOOL synchronizing;
@property (nonatomic, assign, readonly) TaskCollectionSyncState  stateOfSync;
@property (nonatomic, copy, readonly) NSString *statusOfSync;                 
@property (nonatomic, copy, readonly) NSDate *dateLastSynced;               
@property (nonatomic, copy, readonly) NSError *errorFromLastSync;              
@property (nonatomic, copy, readonly) NSDateFormatter *dateFormatter;
@property (nonatomic, assign, readonly) UIBackgroundTaskIdentifier taskCollectionSync;



// Initialize a MzTaskCollection model object
- (id)initWithTasksURLString:(NSString *)taskURLString;
 
// Method that manages TaskCollection LifeCycle
- (void)applicationHasLaunched;

// Returns our PersistentStoreCoordinator or nil if not initialized
+(NSPersistentStoreCoordinator *)taskCollectionCoordinator;

// methods to manage the product collection startup, stop and save processes
-(void)startCollection;
-(void)stopCollection;
-(void)saveCollection;

// methods to control the synchronization process
-(void)startSynchronization;
-(void)stopSynchronization;

@end







                                                                                    