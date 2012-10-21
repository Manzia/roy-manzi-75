/*
  MzProductCollection.h
  ManziaShoppingUI

  Created by Roy Manzi Tumubweinee on 5/30/12.
  Copyright (c) 2012 Manzia Corporation. All rights reserved.
*/

/*
 CLASS DESCRIPTION:
 This model class represents a collection of products associated
 with a specific NavigationNode in the MzProductCollectionViewController. The
 products are stored in a Core Data database
 
 OPERATION:
 1- A products XML file is downloaded from the Manzia Shopping servers based on the
 specific NavigationNode selected (tapped) by the user. In addition, other products XML files are
 also downloaded in the background and cached in anticipation that a user will
 likely select related NavigationNodes
 2- Each products XML file is associated with a specific URL (on the Manzia servers). The XML
 file is downloaded and parsed on secondary threads using the NSOperation class and the 
 NSOperationQueue class to encapsulate and execute these operations.
 3- Each product described in the products XML file is downloaded if it does not already exist
 and is stored in a Core Data database within the CachesDirectory
 4- The thumbNail image data for each product is stored in a separate entity within the same
 Core Data database while the full size image data is stored in a separate directory within
 the CachesDirectory
 5- A background process is run on application startup and termination to clean up the 
 CachesDirectory and delete "abandoned" databases and full size image directories. The same
 background process will activate during low memory situations and warnings
 6- The user has the ability to clear all caches in Settings
 7- The user has the ability to set the logging level - important for networking based apps
 8- This class exports the NSManagedObjectContext and ProductItemEntity required by the
 MzProductCollectionViewController and MzProductItemViewController that update their views
 in response to NSManagedObjectContext changes
 9- Every time a user taps a NavigationNode for the first time in a specific application session
 this class will download the corresponding products XML file. The XML file is parsed and the
 contents stored in a Core Data database. If the user taps the same NavigationNode a second
 time, the products to be displayed a retrieved from the Core Data database.
 10- Every 5 minutes, a fresh products XML file is downloaded (until app moves to background)
 (as part of the auto-synchronization process). The contents of the new XML file are compared
 to those in the Core Data database and the necessary updates are made accordingly. This
 auto-synchronization is critical in that it allows the products displayed to be accurate,
 for example, in case a merchant changes the price of an item, we can capture this within a 
 5 minute timeframe.
 
*/

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzProductCollectionContext;
@class RetryingHTTPOperation;
@class MzCollectionParserOperation;

enum ProductCollectionSyncState {
    
    ProductCollectionSyncStateStopped, 
    ProductCollectionSyncStateGetting, 
    ProductCollectionSyncStateParsing, 
    ProductCollectionSyncStateCommitting
};
typedef enum ProductCollectionSyncState ProductCollectionSyncState;

@interface MzProductCollection : NSObject {
    //NSString *collectionURLString;
    //MzProductCollectionContext *productCollectionContext;
    //NSEntityDescription *productItemEntity;
    //NSDate *dateLastSynced;
    //ProductCollectionSyncState stateOfSync;
    //NSError *errorFromLastSync;
    //NSTimer *timeToSave;
    //RetryingHTTPOperation *getCollectionOperation;
    //MzCollectionParserOperation *parserOperation;
}

// Properties
@property(nonatomic, copy, readonly) NSString *collectionURLString;
@property(nonatomic, strong, readonly)NSManagedObjectContext *managedObjectContext;
@property(nonatomic, strong, readonly)NSEntityDescription *productItemEntity;
@property(nonatomic, copy, readonly) NSString *collectionCachePath;

// KVO properties
@property(nonatomic, strong, readonly) NSDictionary *productItems;
@property(nonatomic, strong, readonly) NSDictionary *cacheSyncStatus;
@property(nonatomic, strong, readonly) NSDictionary *cachePath;

// Properties that enable the control of the syncing process
@property (nonatomic, assign, readonly, getter=isSynchronizing) BOOL synchronizing;
@property (nonatomic, assign, readonly) ProductCollectionSyncState  stateOfSync;
@property (nonatomic, copy, readonly) NSString *statusOfSync;                 
@property (nonatomic, copy, readonly) NSDate *dateLastSynced;               
@property (nonatomic, copy, readonly) NSError *errorFromLastSync;              
@property (nonatomic, copy, readonly) NSDateFormatter *dateFormatter; 


// Class method to manage the ProductCollection Cache directories
+(void)applicationInBackground;

// Marks for removal a ProductCollection cache at a given path
+ (void)markForRemoveCollectionCacheAtPath:(NSString *)collectionPath;

// initialize
-(id)initWithCollectionURLString:(NSString *)collectionURLString;

// Retrieve all Products in Collection
-(void)fetchProductsInCollection;

// methods to manage the product collection startup, stop and save processes
-(void)startCollection;
-(void)stopCollection;
-(void)saveCollection;

// methods to control the synchronization process
-(void)startSynchronization:(NSString *)relativePath;
-(void)stopSynchronization;

@end
