//
//  MzReviewCollection.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 1/31/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

/*
 * The MzReviewCollection class abstracts a collection of MzReviewItems (Reviews) and
 * manages the Networking and Core Data tasks involved in retrieving and persisting
 * the Reviews XML files downloaded from the Manzia Servers. Note that:
 * 1- A MzReviewCollection only exists and MUST be associated with one and only one
 * MzProductCollection
 * 2- Data management via Core Data is done using the NSManagedObjectContext of the
 * associated MzProductCollection
 * 3- The MzReviewCollection utilizes the same NSManagedObjectModel, NSPersistenceStore,
 * NSPersistenceStoreCoordinator as its associated MzProductCollection
 * 4- Synchronization of a MzReviewCollection (i.e downloading of Reviews XML files) utilizes
 * requires the productID values from a specific MzProductItem in a specific MzProductCollection
 */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class RetryingHTTPOperation;
@class MzReviewParserOperation;
@class MzProductItem;

enum ReviewCollectionSyncState {
    
    ReviewCollectionSyncStateStopped,
    ReviewCollectionSyncStateGetting,
    ReviewCollectionSyncStateParsing,
    ReviewCollectionSyncStateCommitting
};
typedef enum ReviewCollectionSyncState ReviewCollectionSyncState;


@interface MzReviewCollection : NSObject {
    
}

// Properties
@property(nonatomic, copy, readonly) NSString *collectionURLString;
@property(nonatomic, strong, readonly)NSManagedObjectContext *managedObjectContext;
@property(nonatomic, strong, readonly)NSEntityDescription *reviewItemEntity;
@property(nonatomic, copy, readonly) NSURL *collectionCachePath;

// KVO properties
@property(nonatomic, strong, readonly) NSDictionary *reviewItems;
@property(nonatomic, strong, readonly) NSDictionary *cacheSyncStatus;
@property(nonatomic, strong, readonly) NSDictionary *cachePath;

// Properties that enable the control of the syncing process
@property (nonatomic, assign, readonly, getter=isSynchronizing) BOOL synchronizing;
@property (nonatomic, assign, readonly) ReviewCollectionSyncState  stateOfSync;
@property (nonatomic, copy, readonly) NSString *statusOfSync;
@property (nonatomic, copy, readonly) NSDate *dateLastSynced;
@property (nonatomic, copy, readonly) NSError *errorFromLastSync;
@property (nonatomic, copy, readonly) NSDateFormatter *dateFormatter;


// Class method to manage the ProductCollection Cache directories
+(void)applicationInBackground;

// Marks for removal a ProductCollection cache at a given path
+ (void)markForRemoveCollectionCacheAtPath:(NSURL *)collectionPath;

// initialize
-(id)initWithCollectionURLString:(NSString *)collectionURLString andProductItem:(MzProductItem *)productItem;

// Retrieve all Reviews in Collection
-(void)fetchReviewsInCollection;

// methods to manage the product collection startup, stop and save processes
-(void)startCollection;
-(void)stopCollection;
-(void)saveCollection;

// methods to control the synchronization process
-(void)startSynchronization:(NSString *)relativePath;
-(void)stopSynchronization;


@end
