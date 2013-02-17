//
//  MzReviewCollection.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 1/31/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzReviewCollection.h"
#import "MzReviewParserOperation.h"
#import "RetryingHTTPOperation.h"
#import "Logging.h"
#import "MzProductItem.h"
#import "NetworkManager.h"
#import "MzReviewItem.h"

#define kAutoSaveContextChangesTimeInterval 1.0     // 5 secs to auto-save

@interface MzReviewCollection()

// private properties
@property (nonatomic, copy, readwrite) NSString *collectionURLString;
@property (nonatomic, strong, readwrite)NSEntityDescription *reviewItemEntity;
@property (nonatomic, strong, readwrite) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, copy, readwrite) NSURL *collectionCachePath;
@property (nonatomic, assign, readwrite) ReviewCollectionSyncState stateOfSync;
@property (nonatomic, strong, readwrite) NSTimer *timeToSave;
@property (nonatomic, copy, readwrite) NSDate *dateLastSynced;
@property (nonatomic, copy, readwrite) NSError *errorFromLastSync;
@property (nonatomic, strong, readwrite) RetryingHTTPOperation *getCollectionOperation;
@property (nonatomic, strong, readwrite) MzReviewParserOperation *parserOperation;
@property (nonatomic, copy, readwrite) NSString *productItemID;

// Property that holds all the MzReviewItems associated with this MzReviewCollection
// in an NSDictinary whose Key is the productID of the associated MzProductItem
@property (nonatomic, strong, readwrite) NSDictionary *reviewItems;

// Dictionary whose Key is the productItemID and Value is the statusOfSync string
@property(nonatomic, strong, readwrite) NSDictionary *cacheSyncStatus;

// Dictionary whose Key is the Search URL and Value is the collectionCacheName
@property(nonatomic, strong, readwrite) NSDictionary *cachePath;

// Maintain a pointer to the MzProductItem that "own" us
@property(nonatomic, strong, readwrite) MzProductItem *productItem;

// forward declarations

- (void)startParserOperationWithData:(NSData *)data;
- (void)commitParserResults:(NSArray *)latestResults;

@end


@implementation MzReviewCollection

// Synthesize properties
@synthesize collectionURLString;
@synthesize reviewItemEntity;
@synthesize collectionCachePath;
@synthesize stateOfSync;
@synthesize timeToSave;
@synthesize dateFormatter;
@synthesize dateLastSynced;
@synthesize errorFromLastSync;
@synthesize getCollectionOperation;
@synthesize parserOperation;
@synthesize synchronizing;
@synthesize statusOfSync;
@synthesize managedObjectContext;
@synthesize reviewItems;
@synthesize cacheSyncStatus;
@synthesize cachePath;
@synthesize productItemID;
@synthesize productItem;

#pragma mark * Initialization

// Initialize the MzReviewCollection object
- (id)initWithCollectionURLString:(NSString *)collectURLString andProductItem:(MzProductItem *)prodItem
{
    assert(collectURLString != nil);
    assert(prodItem != nil);
    
    self = [super init];
    if (self != nil) {
        self.collectionURLString = collectURLString;
        self.managedObjectContext = prodItem.managedObjectContext;
        self.productItemID = prodItem.productID;
        self.productItem = prodItem;
        [[QLog log] logWithFormat:@"Review Collection instantiated with URL: %@", self.collectionURLString];
    }
    return self;
}

#pragma mark * Core Data Management

// Override synthesized Getter for the reviewItemEntity property
- (NSEntityDescription *)reviewItemEntity
{
    if (self->reviewItemEntity == nil) {
        assert(self.managedObjectContext != nil);
        self->reviewItemEntity = [NSEntityDescription entityForName:@"MzReviewItem" inManagedObjectContext:self.managedObjectContext];
        assert(self->reviewItemEntity != nil);
    }
    return self->reviewItemEntity;
}

// Method to return all stored ReviewItems (MzReviewItem objects) for "our" productItemID
- (NSFetchRequest *)reviewItemsFetchRequest
{
    assert(self.reviewItemEntity != nil);
    assert(self.productItemID != nil);
    NSFetchRequest *fetchRequest;
    fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[self.reviewItemEntity name]];
    assert(fetchRequest != nil);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"reviewProduct.productID like[c] %@", self.productItemID];
    assert(predicate != nil);
    [fetchRequest setPredicate:predicate];
    //[fetchRequest setFetchBatchSize:20];
    
    return fetchRequest;
}

// Retrieve all the ReviewItems in the Collection asynchronously. This method will return immediately
//so the caller is expected to use KVO on the reviewItems property to get notified when the
// reviewItems have been fetched
-(void)fetchReviewsInCollection
{
    assert(self.collectionURLString != nil);
    assert(self.managedObjectContext != nil);
    
    NSMutableDictionary *reviewDict = [NSMutableDictionary dictionary];
    __block NSArray *reviews = nil;
    
    // Retrieve ReviewItem asynchronously??...need to try the performBlock:^{...
        [self.managedObjectContext performBlockAndWait:^{
            NSError *error = nil;
            NSFetchRequest *fetchRequest = [self reviewItemsFetchRequest];
            assert(fetchRequest != nil);
            NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            if (fetchResults != nil) {
                reviews = [NSArray arrayWithArray:fetchResults];
                assert(reviews != nil);
                [[QLog log] logWithFormat:@"Fetched %d Reviews for Review Collection with productItemID: '%@'", [reviews count], self.productItemID];
            } else {
                [[QLog log] logWithFormat:@"Failed to retrieve Reviews from Review Collection with productItemID: '%@'", self.productItemID];
            }
        }];
    
    if ([reviews count] > 0) {
        [reviewDict setObject:reviews forKey:[self.productItemID copy]];
        
        //KVO notify
        //[self willChangeValueForKey:@"productItems"];
        self.reviewItems = reviewDict;
        //[self didChangeValueForKey:@"productItems"];
    }
    
}

#pragma mark * Review Collection Lifecycle Management

// Start the Review Collection
- (void)startCollection
{
    BOOL success;
    assert(self.collectionURLString != nil);
    assert(self.productItemID != nil);
        
    // Start up the Collection Cache.  Abandon the Collection, and retry once more
    // on initial failure    
    success = self.managedObjectContext != nil ? YES : NO;
    if ( ! success ) {
        [[QLog log] logWithFormat:@"SEVERE, Missing NSManagedObjectContext, cannot startup Review Collection with URL: %@", self.collectionURLString];
        
        // application is dead and we crash
        abort();
    } else {
        // append the productItemID to collectionURLString..happens in the startGetOperation: method
        [self startSynchronization:nil];
    }
}

// Save the Collection Cache
- (void)saveCollection
{
    NSError *error = nil;
    
    // Typically this instance method will be called automatically after a preset
    // time interval in response to managedObjectContext changes, so we disable the
    // auto-save before actually saving the Collection Cache.
    
    [self.timeToSave invalidate];
    self.timeToSave = nil;
    
    // Now save.
    if (self.managedObjectContext != nil && [self.managedObjectContext hasChanges] ) {
        BOOL success;
        success = [self.managedObjectContext save:&error];
        if (success) {
            error = nil;
        }
    }
    
    // Log the results.
    
    if (error == nil) {
        [[QLog log] logWithFormat:@"Saved Review Collection with ProductItemID: %@", self.productItemID];
    } else {
        [[QLog log] logWithFormat:@"Review Collection save error: %@ for ProductItemID: %@", error, self.productItemID];
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
    self.timeToSave = [NSTimer scheduledTimerWithTimeInterval:kAutoSaveContextChangesTimeInterval target:self
                                                     selector:@selector(saveCollection) userInfo:nil repeats:NO];
}


// Closes access to the Collection Cache when a user switches to another ProductCollection
// or when the application is moved to the background
- (void)stopCollection
{
    [self stopSynchronization];
    assert(self.managedObjectContext != nil);
    
    // Stop the auto save mechanism and then force a save.
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification
                                                      object:self.managedObjectContext];
    [self saveCollection];
    self.reviewItemEntity = nil;
    [[QLog log] logWithFormat:@"Stopped Review Collection with ProductItemID: %@", self.productItemID];
}

#pragma mark * Main Synchronization methods

// Register all the dependent properties/keys (on StateOfSync property) to enable
// KVO notifications for changes in any of these dependent properties
+ (NSSet *)keyPathsForValuesAffectingStatusOfSync
{
    return [NSSet setWithObjects:@"stateOfSync", @"errorFromLastSync", @"dateFormatter", @"dateLastSynced",
            @"getCollectionOperation.retryStateClient", nil];
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
    NSString *collectionID = self.productItemID;
    if (status != nil && collectionID != nil) {
        NSMutableDictionary *statusDict = [NSMutableDictionary dictionaryWithObject:status forKey:collectionID];
        assert(statusDict != nil);
        [self willChangeValueForKey:@"cacheSyncStatus"];
        self.cacheSyncStatus = statusDict;
        [self didChangeValueForKey:@"cacheSyncStatus"];
    }
}

// Override getter for the KVO-observable and User-Visible statusOfSync property
- (NSString *)statusOfSync
{
    NSString *syncResult;
    
    if (self.errorFromLastSync == nil) {
        switch (self.stateOfSync) {
            case ReviewCollectionSyncStateStopped: {
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

/* Method that starts an HTTP GET operation to retrieve the Review Collection's
 XML file. The method has a relativePath argument whose value can be
 appended to the Review Collection's collectionURLString for the HTTP GET.
 
 The relativePath is primarily used by the MzProductReviewsViewController
 to HTTP GET more review items for the same product item (MzProductItem). Each HTTP GET
 operation will retrieve an XML file with details for 20 items 
 */

- (void)startGetOperation:(NSString *)relativePath
{
    NSMutableURLRequest *requestURL;
    assert(self.stateOfSync == ReviewCollectionSyncStateStopped);
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Start HTTP GET for Review Collection with URL %@", self.collectionURLString];
    
    // get the URLRequest
    requestURL = [self requestToGetCollectionRelativeString:relativePath];
    assert(requestURL != nil);
    
    assert(self.getCollectionOperation == nil);
    self.getCollectionOperation = [[RetryingHTTPOperation alloc] initWithRequest:requestURL];
    assert(self.getCollectionOperation != nil);
    
    [self.getCollectionOperation setQueuePriority:NSOperationQueuePriorityNormal];
    self.getCollectionOperation.acceptableContentTypes = [NSSet setWithObjects:@"application/xml", @"text/xml", nil];
    
    [[NetworkManager sharedManager] addNetworkManagementOperation:self.getCollectionOperation finishedTarget:self action:@selector(getCollectionOperationComplete:)];
    
    self.stateOfSync = ReviewCollectionSyncStateGetting;
    
    // Notify observers of sync status
    [self notifyCacheSyncStatus];
}

// Starts an operation to parse the review collection's XML when the HTTP GET
// operation completes succesfully
- (void)getCollectionOperationComplete:(RetryingHTTPOperation *)operation
{
    NSError *error;
    assert([operation isKindOfClass:[RetryingHTTPOperation class]]);
    assert(operation == self.getCollectionOperation);
    assert(self.stateOfSync == ReviewCollectionSyncStateGetting);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Completed HTTP GET operation for Review Collection with URL: %@", self.collectionURLString ];
    
    // error checking
    error = operation.error;
    if (error != nil) {
        self.errorFromLastSync = error;
        self.stateOfSync = ReviewCollectionSyncStateStopped;
    } else {
        if ([QLog log].isEnabled) {
            [[QLog log] logOption:kLogOptionNetworkData withFormat:@"Received valid Reviews XML from HTTP GET operation for ProductItemID: %@", self.productItemID];
        }
        [self startParserOperationWithData:self.getCollectionOperation.responseContent];
    }
    
    self.getCollectionOperation = nil;
    
    [self notifyCacheSyncStatus];
}

// Starts the operation to parse the Review Collection's XML.
- (void)startParserOperationWithData:(NSData *)data
{
    assert(self.stateOfSync == ReviewCollectionSyncStateGetting);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Start parse operation for Review Collection with ProductItemID: %@", self.productItemID];
    
    assert(self.parserOperation == nil);
    self.parserOperation = [[MzReviewParserOperation alloc] initWithXMLData:data];
    assert(self.parserOperation != nil);
    
    [self.parserOperation setQueuePriority:NSOperationQueuePriorityNormal];
    
    [[NetworkManager sharedManager] addCPUOperation:self.parserOperation finishedTarget:self action:@selector(parserOperationDone:)];
    
    self.stateOfSync = ReviewCollectionSyncStateParsing;
    
    [self notifyCacheSyncStatus];
}

// Method is called when the Collection ParserOperation completes and if successful
// commits the results to the Core Data database in our Collection Cache.
- (void)parserOperationDone:(MzReviewParserOperation *)operation
{
    assert([NSThread isMainThread]);
    assert([operation isKindOfClass:[MzReviewParserOperation class]]);
    assert(operation == self.parserOperation);
    assert(self.stateOfSync == ReviewCollectionSyncStateParsing);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Parsing complete for Review Collection with ProductItemID: %@", self.productItemID];
    
    if (operation.parseError != nil) {
        self.errorFromLastSync = operation.parseError;
        self.stateOfSync = ReviewCollectionSyncStateStopped;
    } else {
        [self.managedObjectContext performBlock:^{
            [self commitParserResults:operation.parseResults];
        }];
        
        assert(self.errorFromLastSync == nil);
        self.dateLastSynced = [NSDate date];
        self.stateOfSync = ReviewCollectionSyncStateStopped;
        [[QLog log] logWithFormat:@"Successfully synced Review Collection with ProductItemID: %@", self.productItemID];
        
    }
    self.parserOperation = nil;
    
    [self notifyCacheSyncStatus];
}

// Commit the parseResults to the Core Data database. Note: We only insert new Reviews that do not
// already exist in the database,
- (void)commitParserResults:(NSArray *)parserResults
{
    assert(parserResults != nil);
    
    if ([parserResults count] > 0) {
        
        NSFetchRequest *fetchRequest;
        NSError *fetchError = NULL;
        NSMutableSet *oldReviewIDs;
        NSMutableSet *newReviewIDs;
        NSArray *retrievedReviews;
        
        // Retrieve and store the productIDs from the parserResults in a set (avoids duplicates)
        newReviewIDs = [NSMutableSet setWithArray:[parserResults valueForKey:kReviewParserReviewId]];
        assert(newReviewIDs != nil);
        
        // We expect to have only one value, i.e the reviewSku which is equivalent to the productID since
        // the Reviews are ProductItem specific (i.e there is a one-to-many relationship between a ProductItem
        // and ReviewItems)
        if ([newReviewIDs count] != [parserResults count]) {
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Duplicates in new Review Items for Review Collection with ProductItemID: %@", self.productItemID];
        }
        
        // Get all the productItems from the database - we don't set a batch size on the number retrieved
        // since we don't ever expect a specific ProductItem to have more than a few thousand Reviews at most
        // which are routinely deleted when the MzProductCollection caches are deleted on Application shutdown
        fetchRequest = [self reviewItemsFetchRequest];
        assert(fetchRequest != nil);
        retrievedReviews = [self.managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
        assert(retrievedReviews != nil);
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Retrieved: %d Review Items from Database for Review Collection with ProductItemID: %@", [retrievedReviews count] ,self.productItemID];
                
        // Handle errors, we do not commit the new parserResults if we have errors ...the next time we synchronize
        // we shall re-attempt to commit the new Reviews and assume the underlying PersistentStore managed by
        // our associated MzProductCollection has been fixed.
        if (fetchError) {
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Error: %@ while fetching from Review Collection Cache for ProductItemID: %@", fetchError.localizedDescription, self.productItemID];
            //[self markForRemoveCollectionCacheAtPath:self.collectionCachePath];
            return;
        }
        
        // Do the Updates accordingly
        if ([retrievedReviews count] > 0) {
            
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Retrieved: %d Review Items from Database for Review Collection with ProductItemID: %@", [retrievedReviews count] ,self.productItemID];
            
            // Retrieve the productIDs from the existing reviewItems
            oldReviewIDs = [NSMutableSet setWithArray:[retrievedReviews valueForKey:kReviewParserReviewId]];
            assert(oldReviewIDs != nil);
            
            // productIDs to insert
            [newReviewIDs minusSet:oldReviewIDs];
                        
            // insert all the new productItems we don't already have
            int newReviewCount = 0;
            assert(self.productItem != nil);
            NSMutableSet *newItems = [NSMutableSet setWithSet:self.productItem.productReviews];
            for (NSDictionary *result in parserResults) {
                
                if ([newReviewIDs containsObject:[result objectForKey:kReviewParserReviewId]]) {
                    MzReviewItem *newReview = [MzReviewItem insertNewMzReviewItemWithProperties:result
                                                                         inManagedObjectContext:self.managedObjectContext];
                    assert(newReview != nil);
                    assert([newReview.reviewSku isEqualToString:self.productItemID] );
                    [newItems addObject:newReview];
                    //[self.productItem addReviewItemsObject:newReview];
                    newReviewCount++;
                }                
            }
            self.productItem.productReviews = [NSSet setWithSet:newItems];
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Inserted %d new Reviews for Review Collection with ProductItemID: %@", newReviewCount, self.productItemID];
            
        } else {
            
            // we insert all the new MzReviewItems since NONE exist in the database
            int newReviewCount = 0;
            assert(self.productItem != nil);
            NSMutableSet *newItems = [NSMutableSet set];
            for (NSDictionary *result in parserResults) {
                                
                MzReviewItem *newReview = [MzReviewItem insertNewMzReviewItemWithProperties:result
                                                                     inManagedObjectContext:self.managedObjectContext];
                assert(newReview != nil);
                assert([newReview.reviewSku isEqualToString:self.productItemID] );
                [newItems addObject:newReview];
                //[self.productItem addReviewItemsObject:newReview];
                newReviewCount++;
                
            }
            self.productItem.productReviews = [NSSet setWithSet:newItems];
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Inserted %d new Reviews for Review Collection with ProductItemID: %@", newReviewCount, self.productItemID];
        }
    } else {
        
        // we got zero ReviewItems from the ParseResults
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"EMPTY ParseResults array for Review Collection with ProductItemID: %@", self.productItemID];
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
    return (self->stateOfSync > ReviewCollectionSyncStateStopped);
}

+ (BOOL)automaticallyNotifiesObserversOfStateOfSync
{
    return NO;
}

// Setter for the stateOfSync property, this property is KVO-observable
- (void)setStateOfSync:(ReviewCollectionSyncState)newValue
{
    if (newValue != self->stateOfSync) {
        BOOL    isSyncingChanged;
        
        isSyncingChanged = (self->stateOfSync > ReviewCollectionSyncStateStopped) != (newValue > ReviewCollectionSyncStateStopped);
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
        if (self.stateOfSync == ReviewCollectionSyncStateStopped) {
            [[QLog log] logWithFormat:@"Starting synchronization for Review Collection with URL: %@", self.collectionURLString];
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
        self.stateOfSync = ReviewCollectionSyncStateStopped;
        
        [[QLog log] logWithFormat:@"Stopped synchronization for Review Collection with ProductItemID: %@", self.productItemID];
        
        // Notify observers
        [self notifyCacheSyncStatus];
    }
}


@end
