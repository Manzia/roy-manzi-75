//
//  MzProductItem.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 6/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzProductItem.h"
#import "MzProductThumbNail.h"
#import "Logging.h"
#import "MzProductCollectionContext.h"
#import "RetryingHTTPOperation.h"
#import "MakeThumbnailOperation.h"
#import "NetworkManager.h"
#import "QHTTPOperation.h"

/*
 The key operations of a MZProductItem object are:
 1- download a full size product Image when requested
 2- download a thumbNail image
 3- resize the downloaded thumbNail into 3 sizes, small, medium, large
 4- persist MzProductItem objects in the Core Data database
 */

// Available Thumbnail Sizes
extern NSString *const kThumbNailSizeSmall;
extern NSString *const kThumbNailSizeMedium;
extern NSString *const kThumbNailSizeLarge;

// Key whose value is a PlaceHolder thumbnail Image. The PlaceHolder
// is stored in the thumbnailImages dictionary and one placeholder image is stored
// when there is no product Item thumbnail yet in the dictionary or
// Core Data database and another placeholder image is stored when the 
// HTTP GET operation for the product Item thumbnail fails in retry. Clients
// should KVO observe the value for this key and thus display the appropriate
// placeholder.
NSString *const kThumbnailPlaceHolder = @"placeholderImage";

// KVO contexts
static void *GetOperationContext = &GetOperationContext;
static void *ThumbnailStatusContext = &ThumbnailStatusContext;

@interface MzProductItem ()

// read/write version of public properties
@property (nonatomic, retain, readwrite) NSString *productID;
@property (nonatomic, retain, readwrite) NSString *productTitle;
@property (nonatomic, retain, readwrite) NSString *productDetailPath;
@property (nonatomic, retain, readwrite) NSString *remoteImagePath;
@property (nonatomic, retain, readwrite) NSString *remoteThumbnailPath;
@property (nonatomic, retain, readwrite) NSString *productDescription;
@property (nonatomic, retain, readwrite) NSString *localImagePath;
@property (nonatomic, retain, readwrite) NSDate *productTimestamp;
@property (nonatomic, retain, readwrite) NSString *productLanguage;
@property (nonatomic, retain, readwrite) NSString *productCountry;
@property (nonatomic, retain, readwrite) NSString *productClassID;
@property (nonatomic, retain, readwrite) NSString *productSubClassID;
@property (nonatomic, retain, readwrite) NSString *productPriceUnit;
@property (nonatomic, retain, readwrite) NSString *productPriceAmount;
@property (nonatomic, retain, readwrite) NSString *productBrand;
@property (nonatomic, retain, readwrite) NSString *productCondition;
@property (nonatomic, retain, readwrite) NSString *productAvailability;
@property (nonatomic, retain, readwrite) MzProductThumbNail *thumbnail;
//@property (nonatomic, copy, readwrite) NSError *errorGettingImage;

// The thumbnailImages dictionary keeps the "newest" thumbnailImages for our
// MzProductItem with keys that indicate the thumbnail Size. The dictionary also
// stores the PlaceHolder thumbnails and provides a different one depending on
// whether we are getting a thumbnail from the network or if the GET from
// the network failed on retry. The thumbnails in this dictionary are updated
// by KVO observing our thumbnail property's imageData attributes.
@property (nonatomic, retain, readwrite) NSMutableDictionary * thumbnailImages;

// private properties

//@property (nonatomic, retain, readonly ) MzProductCollectionContext *      productCollectionContext;
@property (nonatomic, retain, readwrite) RetryingHTTPOperation *getThumbnailOperation;
//@property (nonatomic, retain, readwrite) RetryingHTTPOperation *getPhotoOperation;
//@property (nonatomic, copy,   readwrite) NSString *getPhotoFilePath;
@property (nonatomic, assign, readwrite) BOOL thumbnailImageIsPlaceholder;


// forward declarations

- (void)updateProductThumbnail;
- (void)updateProductImage;

@end

@implementation MzProductItem

// Setters
@dynamic productID;
@dynamic productTitle;
@dynamic productDetailPath;
@dynamic remoteImagePath;
@dynamic remoteThumbnailPath;
@dynamic productDescription;
@dynamic localImagePath;
@dynamic productTimestamp;
@dynamic productLanguage;
@dynamic productCountry;
@dynamic productClassID;
@dynamic productSubClassID;
@dynamic productPriceUnit;
@dynamic productPriceAmount;
@dynamic productBrand;
@dynamic productCondition;
@dynamic productAvailability;
@dynamic thumbnail;

// Synthesized getters/setters
@synthesize getThumbnailOperation;
//@synthesize getPhotoOperation;
@synthesize thumbnailImageIsPlaceholder;
//@synthesize getPhotoFilePath;
//@synthesize productCollectionContext;
@synthesize thumbnailImages;
//@synthesize errorGettingImage;

#pragma mark * Insert & Update Product Items
// Creates a MzProductItem object with the specified properties in the specified context. 
// The properties dictionary is keyed by property names, in a KVC fashion.

+ (MzProductItem *)insertNewMzProductItemWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    MzProductItem *insertResult;
    
    assert(properties != nil);
    assert( [[properties objectForKey:@"productID"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productTitle"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productDetailPath"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"remoteImagePath"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"remoteThumbnailPath"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productDescription"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productLanguage"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productCountry"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productClassID"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productSubClassID"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productPriceUnit"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productPriceAmount"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productBrand"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productCondition"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productAvailability"] isKindOfClass:[NSString class]] );
    
    assert(managedObjectContext != nil);
    
    insertResult = (MzProductItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzProductItem" inManagedObjectContext:managedObjectContext];
    
    // check we have a valid MzProductItem and assign the new properties
    if (insertResult != nil) {
        assert([insertResult isKindOfClass:[MzProductItem class]]);
        
        insertResult.productID = [[properties objectForKey:@"productID"] copy];
        assert(insertResult.productID != nil);
        
        insertResult.productTitle = [[properties objectForKey:@"productTitle"] copy];
        insertResult.productDetailPath = [[properties objectForKey:@"productDetailPath"] copy];
        insertResult.remoteImagePath = [[properties objectForKey:@"remotePhotoPath"] copy];
        insertResult.remoteThumbnailPath = [[properties objectForKey:@"remoteThumbnailPath"] copy];
        insertResult.productDescription = [[properties objectForKey:@"productDescription"] copy];
        insertResult.productLanguage = [[properties objectForKey:@"productLanguage"] copy];
        insertResult.productCountry = [[properties objectForKey:@"productCountry"] copy];
        insertResult.productClassID = [[properties objectForKey:@"productClassID"] copy];
        insertResult.productSubClassID = [[properties objectForKey:@"productSubClassID"] copy];
        insertResult.productPriceUnit = [[properties objectForKey:@"productPriceUnit"] copy];
        insertResult.productPriceAmount = [[properties objectForKey:@"productPriceAmount"] copy];
        insertResult.productBrand = [[properties objectForKey:@"productBrand"] copy];
        insertResult.productCondition = [[properties objectForKey:@"productCondition"] copy];
        insertResult.productAvailability = [[properties objectForKey:@"productAvailability"] copy];
        
        // Add a timestamp
        insertResult.productTimestamp = [NSDate date];
    }
    return insertResult;
}

// Updates the photo with the specified properties.  This will update the various 
// readonly properties listed below, triggering KVO notifications along the way
- (void)updateWithProperties:(NSDictionary *)properties
{
#pragma unused(properties)
    BOOL    productThumbnailNeedsUpdate;
    BOOL    productImageNeedsUpdate;
    
    assert( [self.productID isEqual:[properties objectForKey:@"productID"]] );
    assert( [[properties objectForKey:@"productTitle"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productDetailPath"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"remoteImagePath"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"remoteThumbnailPath"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productDescription"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productLanguage"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productCountry"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productClassID"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productSubClassID"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productPriceUnit"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productPriceAmount"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productBrand"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productCondition"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"productAvailability"] isKindOfClass:[NSString class]] );
    
    // Update the properties
    // Note that we do not modify the productTimestamp as this value captures when the
    // productItem was initially created - createdTime
    productThumbnailNeedsUpdate = NO;
    productImageNeedsUpdate     = NO;
    
    if ( ! [self.productTitle isEqual:[properties objectForKey:@"productTitle"]] ) {
        self.productTitle = [[properties objectForKey:@"productTitle"] copy];
    }
    if ( ! [self.productDetailPath isEqual:[properties objectForKey:@"productDetailPath"]] ) {
        self.productDetailPath = [[properties objectForKey:@"productDetailPath"] copy];
    }
    
    // update the product Image if the remoteImagePath changes
    if ( ! [self.remoteImagePath isEqual:[properties objectForKey:@"remoteImagePath"]] ) {
        self.remoteImagePath = [[properties objectForKey:@"remoteImagePath"] copy];
        productImageNeedsUpdate     = YES;
    }
    
    // update the product Thumbnail of remoteThumbNailPath changes
    if ( ! [self.remoteThumbnailPath isEqual:[properties objectForKey:@"remoteThumbnailPath"]] ) {
        self.remoteThumbnailPath = [[properties objectForKey:@"remoteThumbnailPath"] copy];
        productThumbnailNeedsUpdate = YES;
    }
    
    if ( ! [self.productDescription isEqual:[properties objectForKey:@"productDescription"]] ) {
        self.productDescription = [[properties objectForKey:@"productDescription"] copy];
    }
    if ( ! [self.productLanguage isEqual:[properties objectForKey:@"productLanguage"]] ) {
        self.productLanguage = [[properties objectForKey:@"productLanguage"] copy];
    }
    if ( ! [self.productCountry isEqual:[properties objectForKey:@"productCountry"]] ) {
        self.productCountry = [[properties objectForKey:@"productCountry"] copy];
    }
    if ( ! [self.productClassID isEqual:[properties objectForKey:@"productClassID"]] ) {
        self.productClassID = [[properties objectForKey:@"productClassID"] copy];
    }
    if ( ! [self.productSubClassID isEqual:[properties objectForKey:@"productSubClassID"]] ) {
        self.productSubClassID = [[properties objectForKey:@"productSubClassID"] copy];
    }
    if ( ! [self.productPriceUnit isEqual:[properties objectForKey:@"productPriceUnit"]] ) {
        self.productPriceUnit = [[properties objectForKey:@"productPriceUnit"] copy];
    }
    if ( ! [self.productPriceAmount isEqual:[properties objectForKey:@"productPriceAmount"]] ) {
        self.productPriceAmount = [[properties objectForKey:@"productPriceAmount"] copy];
    }
    if ( ! [self.productBrand isEqual:[properties objectForKey:@"productBrand"]] ) {
        self.productBrand = [[properties objectForKey:@"productBrand"] copy];
    }
    if ( ! [self.productCondition isEqual:[properties objectForKey:@"productCondition"]] ) {
        self.productCondition = [[properties objectForKey:@"productCondition"] copy];
    }
    if ( ! [self.productAvailability isEqual:[properties objectForKey:@"productAvailability"]] ) {
        self.productAvailability = [[properties objectForKey:@"productAvailability"] copy];
    }
               
    // Do the updates.
    
    if (productThumbnailNeedsUpdate) {
        [self updateProductThumbnail];
    }
    
    // For now we do not need to download full-size product images but the functionality
    // will be left in place in case we need this feature in the future.
    if (productImageNeedsUpdate) {
        //[self updateProductImage];
    }
}
/* Getter for our ManagedObjectContext
- (MzProductCollectionContext *)productCollectionContext
{
    MzProductCollectionContext *result;
    result = (MzProductCollectionContext *) [self managedObjectContext];
    assert( [result isKindOfClass:[MzProductCollectionContext class]] );
    
    return result;
} */

// Method to stop the getThumbnailOperation, return BOOL value = YES indicates that either
// the getThumbnailOperation or the resizeThumbnailOperation have been stopped
- (BOOL)stopThumbnail
{
    BOOL didSomething;
    
    didSomething = NO;
    if (self.getThumbnailOperation != nil) {
        [self.getThumbnailOperation removeObserver:self forKeyPath:@"hasHadRetryableFailure"];
        [[NetworkManager sharedManager] cancelOperation:self.getThumbnailOperation];
        self.getThumbnailOperation = nil;
        didSomething = YES;
    }
    if (self.thumbnail != nil) {
        [self.thumbnail stopResizeOperations:self];
        [self.thumbnail removeObserver:self forKeyPath:@"imageDataSmall"];
        [self.thumbnail removeObserver:self forKeyPath:@"imageDataMedium"];
        [self.thumbnail removeObserver:self forKeyPath:@"imageDataLarge"];
        didSomething = YES;
    }
        
   return didSomething;
}

// Stop all on-going network-based operations
- (void)stopAllOperations
{
    BOOL didSomething;
    
    // Cancel the fetching of the thumbnail if in progress
    didSomething = [self stopThumbnail];
    if (didSomething) {
        [[QLog log] logWithFormat:@"Cancelled thumbnail fetch for Product Item %@", self.productID];
    }
    
    /* Cancel the fetching of the product Image if in progress
    if (self.getPhotoOperation != nil) {
        [[NetworkManager sharedManager] cancelOperation:self.getPhotoOperation];
        self.getPhotoOperation = nil;
        if (self.getPhotoFilePath != nil) {
            (void) [[NSFileManager defaultManager] removeItemAtPath:self.getPhotoFilePath error:NULL];
            self.getPhotoFilePath = nil;
        }
        [[QLog log] logWithFormat:@"Cancelled product Image fetch for Product Item %@", self.productID];
    }*/
}

// Override prepareForDeletion in order to get rid of the product Image file. Also
// stop all network-based operations
/*- (void)prepareForDeletion
{
    //BOOL success;
    
    [[QLog log] logWithFormat:@"Product Image for Product Item %@ deleted", self.productID];
    
    [self stopAllOperations];
    
    // Delete the product Image file if it exists on disk.
    
    if (self.localImagePath != nil) {
        success = [[NSFileManager defaultManager] removeItemAtPath:[self.productCollectionContext.productImagesDirectoryPath stringByAppendingPathComponent:self.localImagePath] error:NULL];
        assert(success);
    } 
    
    [super prepareForDeletion];
} */

// There are three common reasons for turning into a fault:
// 
// o Core Data has decided we're uninteresting, and is reclaiming our memory.
// o We're in the process of being deleted.
// o The managed object context itself is going away.
//
- (void)willTurnIntoFault
{
    [self stopAllOperations];
    [super willTurnIntoFault];
}

#pragma mark * Thumbnails

// start the HTTP GET operation to retrieve the product Item's thumbnail.
- (void)startGetThumbnail
{
    NSURLRequest *request;
    NSURL *requestURL;
    
    assert(self.remoteThumbnailPath != nil);
    assert(self.getThumbnailOperation == nil);
        
    // Initialize our dictionary to store thumbnail Images
    if (self.thumbnailImages == nil) {
        
        // Init with the default Placeholder thumbnail Image
        self.thumbnailImages = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[UIImage imageNamed:@"Placeholder.png"], kThumbnailPlaceHolder, nil];
    }
    assert(self.thumbnailImages != nil);
    
    // Create an NSURLRequest from the remoteThumbnailPath
    requestURL = [[NSURL alloc] initWithString:self.remoteThumbnailPath];
    request = [NSURLRequest requestWithURL:requestURL];
    
    if (request == nil) {
        [[QLog log] logWithFormat:@"Bad ThumbnailPath: %@ for Product Item: %@  path '%@'", self.remoteThumbnailPath, self.productID];
        
        // Change the PlaceHolder thumbnail - this will trigger a KVO notification
        [self.thumbnailImages removeObjectForKey:kThumbnailPlaceHolder];
        [self.thumbnailImages setObject:[UIImage imageNamed:@"PlaceHolder-Deferred"] forKey:kThumbnailPlaceHolder];
        
    } else {
        self.getThumbnailOperation = [[RetryingHTTPOperation alloc] initWithRequest:request];
        assert(self.getThumbnailOperation != nil);
        
        [self.getThumbnailOperation setQueuePriority:NSOperationQueuePriorityLow];
        self.getThumbnailOperation.acceptableContentTypes = [NSSet setWithObjects:@"image/jpeg", @"image/png", nil];
        
        [[QLog log] logWithFormat:@"Start thumbnail GET %@  for Product Item %@", self.remoteThumbnailPath, self.productID];
        
        [self.getThumbnailOperation addObserver:self forKeyPath:@"hasHadRetryableFailure" options:0 context:GetOperationContext];
        
        [[NetworkManager sharedManager] addNetworkManagementOperation:self.getThumbnailOperation finishedTarget:self action:@selector(thumbnailGetDone:)];      
                
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == GetOperationContext) { 
        assert(object == self.getThumbnailOperation);
        assert( [keyPath isEqual:@"hasHadRetryableFailure"] );
        //assert([NSThread isMainThread]);
        
        // If we're currently showing a placeholder and the network operation 
        // indicates that it's had one failure, change the placeholder to the deferred 
        // placeholder.  The test for thumbnailImageIsPlaceholder is necessary in the 
        // -updateThumbnail case because we don't want to replace a valid (but old) 
        // thumbnail with a placeholder.
        
        if (self.thumbnailImageIsPlaceholder && self.getThumbnailOperation.hasHadRetryableFailure) {
            
            if (self.thumbnailImages == nil) {
                
                // Init with the deferred Placeholder thumbnail Image
                self.thumbnailImages = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[UIImage imageNamed:@"Placeholder-Deferred.png"], kThumbnailPlaceHolder, nil];
            } else {
                
                //// Change the PlaceHolder thumbnail - this will trigger a KVO notification
                [self.thumbnailImages removeObjectForKey:kThumbnailPlaceHolder];
                [self.thumbnailImages setObject:[UIImage imageNamed:@"PlaceHolder-Deferred.png"] forKey:kThumbnailPlaceHolder];
            }
        }
    } else        
     
    if (context == ThumbnailStatusContext) {
        assert(object == self.thumbnail);
        assert([keyPath isEqual:@"imageDataSmall"] || [keyPath isEqual:@"imageDataMedium"] || [keyPath isEqual:@"imageDataLarge"]);
        //assert([NSThread isMainThread]);
        
        // Make sure our dictionary of thumbnails is available, if it already exists
        // then we remove the old key-value pair before we insert the new key-value pair
        
        if (self.thumbnailImages == nil) {
            
            // Init with the default Placeholder thumbnail Image
            self.thumbnailImages = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[UIImage imageNamed:@"Placeholder.png"], kThumbnailPlaceHolder, nil];
        }
        assert(self.thumbnailImages != nil);
        
        // Update our dictionary accordingly
        if ([keyPath isEqual:@"imageDataSmall"]) {
            [self.thumbnailImages removeObjectForKey:kThumbNailSizeSmall];
            [self.thumbnailImages setObject:[change objectForKey:NSKeyValueChangeNewKey] forKey:kThumbNailSizeSmall];
            
        } else if ([keyPath isEqual:@"imageDataMedium"]) {
            [self.thumbnailImages removeObjectForKey:kThumbNailSizeMedium];
            [self.thumbnailImages setObject:[change objectForKey:NSKeyValueChangeNewKey] forKey:kThumbNailSizeMedium]; 
            
        } else if ([keyPath isEqual:@"imageDataLarge"]) {
            [self.thumbnailImages removeObjectForKey:kThumbNailSizeLarge];
            [self.thumbnailImages setObject:[change objectForKey:NSKeyValueChangeNewKey] forKey:kThumbNailSizeLarge];
        }
    }
}

// Called when the HTTP operation to GET the productImage thumbnail completes.  
// If all is well, we start a resize operation to reduce it the appropriate 
// size.
- (void)thumbnailGetDone:(RetryingHTTPOperation *)operation

{
    //assert([NSThread isMainThread]);
    assert([operation isKindOfClass:[RetryingHTTPOperation class]]);
    assert(operation == self.getThumbnailOperation);
    assert([self.getThumbnailOperation isFinished]);
       
    // Create our MzProductThumbNail object if none exists....this object will do
    // the resize Operations for us, we KVO observe its imageData properties
    
    if (self.thumbnail == nil) {
        self.thumbnail = [NSEntityDescription insertNewObjectForEntityForName:@"MzProductThumbnail" inManagedObjectContext:self.managedObjectContext];
        assert(self.thumbnail != nil);
    }
    
    // Add self as an observer to our thumbnail's imageData
    [self.thumbnail addObserver:self forKeyPath:@"imageDataSmall" options:NSKeyValueObservingOptionNew context:ThumbnailStatusContext];
    [self.thumbnail addObserver:self forKeyPath:@"imageDataMedium" options:NSKeyValueObservingOptionNew context:ThumbnailStatusContext];
    [self.thumbnail addObserver:self forKeyPath:@"imageDataLarge" options:NSKeyValueObservingOptionNew context:ThumbnailStatusContext];

    
    [[QLog log] logWithFormat:@"Completed thumbnail GET for Product Item %@", self.productID];
    
    if (operation.error != nil) {
        [[QLog log] logWithFormat:@"Error for thumbnail GET: %@ for Product Item: %@", operation.error, self.productID];
        //[self thumbnailCommitImage:nil isPlaceholder:YES];
        (void) [self stopThumbnail];
    } else {
        [[QLog log] logOption:kLogOptionNetworkData withFormat:@"receive %@", operation.responseContent];
        
                // Do the resize
        [self.thumbnail startThumbnailResize:operation];
                
    }
}

// This method returns a thumbnail Image of the requested size, if there
// is no thumbnail in the thumbnailImages dictionary or in the Core Data
// database, we hit the network. In the latter case, a PlaceHolder image is
// returned in the meantime.
- (UIImage *)getthumbnailImage:(kThumbnailImageSize)thumbnailSize
{
    // Check our thumbnailImages dictionary first and return
    UIImage *returnImage;
    self.thumbnailImageIsPlaceholder = NO;
    assert(self.thumbnailImages != nil);
    assert([self.thumbnailImages count] > 0);
    
    switch (thumbnailSize) {
        case kSmallThumbnailImage: {
            returnImage = [thumbnailImages objectForKey:kThumbNailSizeSmall];
            
            // hit the database if we don't have the thumbnail in the dictionary
            if (returnImage == nil && self.thumbnail.imageDataSmall != nil) {
                returnImage = [[UIImage alloc] initWithData:self.thumbnail.imageDataSmall];
                
                // add the retrieved thumbnail to our dictionary for next time
                if (returnImage != nil) {
                    [thumbnailImages setObject:returnImage forKey:kThumbNailSizeSmall];
                    self.thumbnailImageIsPlaceholder = NO;
                }
            } else if (self.thumbnail.imageDataSmall == nil) {
                
                // we need to hit the network so return a PlaceHolder. Start a new GET operation
                // It is assumed that clients will KVO-observe the thumbnailImages dictionary
                // and will be notified of changes at which point they can re-call this
                //method. Note that in the off-chance we already have GET and RESIZE operations
                // in progress they will be stopped by the new GET operations - this scenario
                // should be rare but may occur only the first time a thumbnailImage is requested.
            
                returnImage = [self.thumbnailImages objectForKey:kThumbnailPlaceHolder];
                self.thumbnailImageIsPlaceholder = YES;
            }
            assert(returnImage != nil);
        } break;
        case kMediumThumbnailImage: {
           /* returnImage = [thumbnailImages objectForKey:kThumbNailSizeMedium];
            
            // hit the database if we don't have the thumbnail in the dictionary
            if (returnImage == nil && self.thumbnail.imageDataMedium != nil) {
                returnImage = [[UIImage alloc] initWithData:self.thumbnail.imageDataMedium];
                
                // add the retrieved thumbnail to our dictionary for next time
                if (returnImage != nil) {
                    [thumbnailImages setObject:returnImage forKey:kThumbNailSizeMedium];
                    self.thumbnailImageIsPlaceholder = NO;
                }
            } else if (self.thumbnail.imageDataMedium == nil) {
                
                // we need to hit the network so return a PlaceHolder. Start a new GET operation
                // It is assumed that clients will KVO-observe the thumbnailImages dictionary
                // and will be notified of changes at which point they can re-call this
                //method. Note that in the off-chance we already have GET and RESIZE operations
                // in progress they will be stopped by the new GET operations - this scenario
                // should be rare but may occur only the first time a thumbnailImage is requested.
                
                returnImage = [self.thumbnailImages objectForKey:kThumbnailPlaceHolder];
                self.thumbnailImageIsPlaceholder = YES;
            }
            assert(returnImage != nil); */
            returnImage = nil;

        }break;
        case kLargeThumbnailImage: {
           /* returnImage = [thumbnailImages objectForKey:kThumbNailSizeLarge];
            
            // hit the database if we don't have the thumbnail in the dictionary
            if (returnImage == nil && self.thumbnail.imageDataLarge != nil) {
                returnImage = [[UIImage alloc] initWithData:self.thumbnail.imageDataLarge];
                
                // add the retrieved thumbnail to our dictionary for next time
                if (returnImage != nil) {
                    [thumbnailImages setObject:returnImage forKey:kThumbNailSizeLarge];
                    self.thumbnailImageIsPlaceholder = NO;
                }
            } else if (self.thumbnail.imageDataLarge == nil) {
                
                // we need to hit the network so return a PlaceHolder. Start a new GET operation
                // It is assumed that clients will KVO-observe the thumbnailImages dictionary
                // and will be notified of changes at which point they can re-call this
                //method. Note that in the off-chance we already have GET and RESIZE operations
                // in progress they will be stopped by the new GET operations - this scenario
                // should be rare but may occur only the first time a thumbnailImage is requested.
                
                returnImage = [self.thumbnailImages objectForKey:kThumbnailPlaceHolder];
                self.thumbnailImageIsPlaceholder = YES;
            }
            assert(returnImage != nil); */
            returnImage = nil;
        }
        default:
            break;
    }
    
    // We now hit the network if we returned a PlaceHolder
    if (self.thumbnailImageIsPlaceholder) {
        [self stopThumbnail];
        assert(self.getThumbnailOperation == nil);
        assert(self.thumbnail.resizeOperations == nil);
        [self startGetThumbnail];
    }
    
    return returnImage;
}

// Updates the thumbnail is response to a change in the owning MzProductItem object.
- (void)updateProductThumbnail

{
    [[QLog log] logWithFormat:@"Update thumbnail for Product Item %@", self.productID];
    
    // Update only if we've have existing thumbnails. 
    if (self.thumbnail.imageDataSmall != nil || self.thumbnail.imageDataMedium != nil || self.thumbnail.imageDataLarge != nil) {
        
        // stop any getOperations and resizeOperations in progress       
        (void) [self stopThumbnail];
        
        // Get the new thumbnail imageData       
        [self startGetThumbnail];
    }
}


#pragma mark * Product Image

/*- (void)startGetPhoto
// Starts the HTTP operation to GET the photo itself.
{
    NSURLRequest *request;
    NSURL *requestURL;
    
    assert(self.remoteImagePath != nil);
    assert( ! self.gettingProductImage );
    
    assert(self.getPhotoOperation == nil);
    assert(self.getPhotoFilePath== nil);
    
    self.errorGettingImage = nil;
    
    // Create NSURLRequest from NSURL
    requestURL = [[NSURL alloc] initWithString:self.remoteImagePath];
    request = [NSURLRequest requestWithURL:requestURL];
       
    if (request == nil) {
        [[QLog log] logWithFormat:@"Product Image has bad path '%@' for Product Item %@", self.remoteImagePath, self.productID];
        self.errorGettingImage = [NSError errorWithDomain:kQHTTPOperationErrorDomain code:400 userInfo:nil];
    } else {
        
        // Download the product Image to a temporary file.  Create an output stream 
        // for that file.
        
        self.getPhotoFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ProductImageTemp-%.9f", [NSDate timeIntervalSinceReferenceDate]]];
        assert(self.getPhotoFilePath != nil);
        
        // Create and start the download operation.
        
        self.getPhotoOperation = [[RetryingHTTPOperation alloc] initWithRequest:request];
        assert(self.getPhotoOperation != nil);
        
        [self.getPhotoOperation setQueuePriority:NSOperationQueuePriorityHigh];
        self.getPhotoOperation.responseFilePath = self.getPhotoFilePath;
        self.getPhotoOperation.acceptableContentTypes = [NSSet setWithObjects:@"image/jpeg", @"image/png", nil];
        
        [[QLog log] logWithFormat:@"Start GET for Product Image '%@' for Product Item %@", self.remoteImagePath, self.productID];
        
        [[NetworkManager sharedManager] addNetworkManagementOperation:self.getPhotoOperation finishedTarget:self action:@selector(photoGetDone:)];
    }
}

// Called when the HTTP operation to GET the photo completes.  
// Commits the product Image on success.
- (void)photoGetDone:(RetryingHTTPOperation *)operation
{
    assert([NSThread isMainThread]);
    assert([operation isKindOfClass:[RetryingHTTPOperation class]]);
    assert(operation == self.getPhotoOperation);
    
    [[QLog log] logWithFormat:@"Downloaded Product Image for Product Item %@", self.productID];
    
    if (operation.error != nil) {
        [[QLog log] logWithFormat:@"GET Product Image error %@ for Product Item %@", operation.error, self.productID];
        self.errorGettingImage = operation.error;
    } else {
        BOOL        success;
        NSString *  type;
        NSString *  extension;
        NSString *  fileName;
        NSUInteger  fileCounter;
        NSError *   error;
        
        // Set the file name extension based on the MIME type.
        
        type = operation.responseMIMEType;
        assert(type != nil);
        if ([type isEqual:@"image/png"]) {
            extension = @"png";
        } else {
            assert([type isEqual:@"image/jpeg"]);
            extension = @"jpg";
        }
        
         Move the file to the gallery's photo directory, and if that's successful, set localPhotoPath to point to it.  We automatically rename the file to avoid conflicts.  Conflicts do happen in day-to-day operations (specifically, in the case where we update a photo while actually displaying that photo)
        */
        
      /*  fileCounter = 0;
        do {
            fileName = [NSString stringWithFormat:@"ProductImage-%@-%zu.%@", self.productID, (size_t) fileCounter, extension];
            assert(fileName != nil);
            
            success = [[NSFileManager defaultManager] moveItemAtPath:self.getPhotoFilePath toPath:[self.productCollectionContext.productImagesDirectoryPath stringByAppendingPathComponent:fileName] error:&error];
            if ( success ) {
                self.getPhotoFilePath = nil;
                break;
            }
            fileCounter += 1;
            if (fileCounter > 100) {
                break;
            }
        } while (YES);
        
        // On success, update localPhotoPath to point to the newly downloaded photo 
        // and then delete the previous photo (if any).
        
        if (success) {
            NSString *oldLocalPhotoPath;
            
            oldLocalPhotoPath = [self.localImagePath copy];
            
            [[QLog log] logWithFormat:@"Save new Product Image %@ for Product Item %@",fileName, self.productID];
            self.localImagePath = fileName;
            assert(self.errorGettingImage == nil);
            
            if (oldLocalPhotoPath != nil) {
                [[QLog log] logWithFormat:@"Remove old Product Image %@ for Product Item %@", oldLocalPhotoPath, self.productID];
                
                (void) [[NSFileManager defaultManager] removeItemAtPath:[self.productCollectionContext.productImagesDirectoryPath stringByAppendingPathComponent:oldLocalPhotoPath] error:NULL];
            }
        } else {
            assert(error != nil);
            [[QLog log] logWithFormat:@"Save new Product Image failed with error %@ for Product Item: %@", error, self.productID];
            self.errorGettingImage = error;
        }
    }
    
    // Clean up.
    
    self.getPhotoOperation = nil;
    if (self.getPhotoFilePath != nil) {
        (void) [[NSFileManager defaultManager] removeItemAtPath:self.getPhotoFilePath error:NULL];
        self.getPhotoFilePath = nil;
    }
}

// Register the productImage as dependent key for KVO notifications
+ (NSSet *)keyPathsForValuesAffectingProductImage
{
    return [NSSet setWithObject:@"localImagePath"];
}

// Getter for the productImage property
- (UIImage *)productImage
{
    UIImage *result;
    
    // Don't retain the product Image here.  
    
    if (self.localImagePath == nil) {
        result = nil;
    } else {
        result = [UIImage imageWithContentsOfFile:[self.productCollectionContext.productImagesDirectoryPath stringByAppendingPathComponent:self.localImagePath]];
        if (result == nil) {
            [[QLog log] logWithFormat:@"Bad Image file for Product Item %@", self.productID];
        }
    }
    return result; 
    return  nil;
} */

// Register the gettingProductImage property as a dependent key for KVO notifications
+ (NSSet *)keyPathsForValuesAffectingGettingProductImage
{
    return [NSSet setWithObject:@"getPhotoOperation"];
}

/*- (BOOL)gettingProductImage
{
    return (self.getPhotoOperation != nil);
}

- (void)needPhotoToDisplay
{
    self->photoNeededAssertions += 1;
    if ( (self.localImagePath == nil) && ! self.gettingProductImage ) {
        [self startGetPhoto];
    }
}

- (void)removeFromPhotoToDisplay
{
    assert(self->photoNeededAssertions != 0);
    self->photoNeededAssertions -= 1;
} */

/* Updates the product Image is response to a change in the Product Item's XML entity.
- (void)updateProductImage
{
    [[QLog log] logWithFormat:@"Update Product Image for Product Item %@", self.productID];
    
    // Only fetch the product Image if user is actively looking at it. 
    
    if (self->photoNeededAssertions == 0) {
        
        // No one is actively looking at the product Image.  If we have the photo downloaded, 
        // just forget about it.
        
        if (self.localImagePath != nil) {
            [[QLog log] logWithFormat:@"Delete old photo '%@' for Product Item %@", self.localImagePath, self.productID];
            [[NSFileManager defaultManager] removeItemAtPath:[self.productCollectionContext.productImagesDirectoryPath stringByAppendingPathComponent:self.localImagePath] error:NULL];
            self.localImagePath = nil;
        }
    } else {
        
        // If we're already getting the product Image, stop that get (it may be getting from 
        // the old path).
        
        if (self.getPhotoOperation != nil) {
            [[NetworkManager sharedManager] cancelOperation:self.getPhotoOperation];
            self.getPhotoOperation = nil;
        }
        
        // Start a new download 
        // Note that we don't trigger a KVO notification on photoImage at this point. 
        // Instead we leave the user looking at the old product Image
        
        [self startGetPhoto];
    }
} */


@end
