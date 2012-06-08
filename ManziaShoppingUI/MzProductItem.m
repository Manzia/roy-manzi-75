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

// ThumbNailImage sizes
const CGFloat kThumbNailSizeSmall = 60.0f;
const CGFloat kThumbNailSizeMedium = 75.0f;
const CGFloat kThumbNailSizeLarge = 90.0f;

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
@property (nonatomic, copy, readwrite) NSError *errorGettingImage;

// private properties

@property (nonatomic, retain, readonly ) MzProductCollectionContext *      productCollectionContext;
@property (nonatomic, retain, readwrite) RetryingHTTPOperation *getthumbnailOperation;
@property (nonatomic, retain, readwrite) MakeThumbnailOperation *resizethumbnailOperation;
@property (nonatomic, retain, readwrite) RetryingHTTPOperation *getPhotoOperation;
@property (nonatomic, copy,   readwrite) NSString *getPhotoFilePath;
@property (nonatomic, assign, readwrite) BOOL thumbnailImageIsPlaceholder;

// forward declarations

- (void)updateProductThumbnail;
- (void)updateProductImage;

- (void)thumbnailCommitImage:(UIImage *)image isPlaceholder:(BOOL)isPlaceholder;
- (void)thumbnailCommitImageData:(UIImage *)image;

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
@synthesize getthumbnailOperation;
@synthesize resizethumbnailOperation;
@synthesize getPhotoOperation;
@synthesize thumbnailImageIsPlaceholder;
@synthesize getPhotoFilePath;
@synthesize productCollectionContext;

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
    if (productImageNeedsUpdate) {
        [self updateProductImage];
    }
}
// Getter for our ManagedObjectContext
- (MzProductCollectionContext *)productCollectionContext
{
    MzProductCollectionContext *result;
    result = (MzProductCollectionContext *) [self managedObjectContext];
    assert( [result isKindOfClass:[MzProductCollectionContext class]] );
    
    return result;
}

// Method to stop the getThumbnailOperation, return BOOL value = YES indicates that either
// the getThumbnailOperation or the resizeThumbnailOperation have been stopped
- (BOOL)stopThumbnail
{
    BOOL didSomething;
    
    didSomething = NO;
    if (self.getthumbnailOperation != nil) {
        [self.getthumbnailOperation removeObserver:self forKeyPath:@"hasHadRetryableFailure"];
        [[NetworkManager sharedManager] cancelOperation:self.getthumbnailOperation];
        self.getthumbnailOperation = nil;
        didSomething = YES;
    }
    if (self.resizethumbnailOperation != nil) {
        [[NetworkManager sharedManager] cancelOperation:self.resizethumbnailOperation];
        self.resizethumbnailOperation = nil;
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
    
    // Cancel the fetching of the product Image if in progress
    if (self.getPhotoOperation != nil) {
        [[NetworkManager sharedManager] cancelOperation:self.getPhotoOperation];
        self.getPhotoOperation = nil;
        if (self.getPhotoFilePath != nil) {
            (void) [[NSFileManager defaultManager] removeItemAtPath:self.getPhotoFilePath error:NULL];
            self.getPhotoFilePath = nil;
        }
        [[QLog log] logWithFormat:@"Cancelled product Image fetch for Product Item %@", self.productID];
    }
}

// Override prepareForDeletion in order to get rid of the product Image file. Also
// stop all network-based operations
- (void)prepareForDeletion
{
    BOOL success;
    
    [[QLog log] logWithFormat:@"Product Image for Product Item %@ deleted", self.productID];
    
    [self stopAllOperations];
    
    // Delete the product Image file if it exists on disk.
    
    if (self.localImagePath != nil) {
        success = [[NSFileManager defaultManager] removeItemAtPath:[self.productCollectionContext.productImagesDirectoryPath stringByAppendingPathComponent:self.localImagePath] error:NULL];
        assert(success);
    }
    
    [super prepareForDeletion];
}

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
    assert(self.getthumbnailOperation == nil);
    assert(self.resizethumbnailOperation == nil);
    
    // Create an NSURLRequest from the remoteThumbnailPath
    requestURL = [[NSURL alloc] initWithString:self.remoteThumbnailPath];
    request = [NSURLRequest requestWithURL:requestURL];
    
    if (request == nil) {
        [[QLog log] logWithFormat:@"Bad ThumbnailPath: %@ for Product Item: %@  path '%@'", self.remoteThumbnailPath, self.productID];
        [self thumbnailCommitImage:nil isPlaceholder:YES];
    } else {
        self.getthumbnailOperation = [[RetryingHTTPOperation alloc] initWithRequest:request];
        assert(self.getthumbnailOperation != nil);
        
        [self.getthumbnailOperation setQueuePriority:NSOperationQueuePriorityLow];
        self.getthumbnailOperation.acceptableContentTypes = [NSSet setWithObjects:@"image/jpeg", @"image/png", nil];
        
        [[QLog log] logWithFormat:@"Start thumbnail GET %@  for Product Item %@", self.remoteThumbnailPath, self.productID];
        
        [self.getthumbnailOperation addObserver:self forKeyPath:@"hasHadRetryableFailure" options:0 context:&self->thumbnailImage];
        
        [[NetworkManager sharedManager] addNetworkManagementOperation:self.getthumbnailOperation finishedTarget:self action:@selector(thumbnailGetDone:)];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &self->thumbnailImage) {
        assert(object == self.getthumbnailOperation);
        assert( [keyPath isEqual:@"hasHadRetryableFailure"] );
        assert([NSThread isMainThread]);
        
        // If we're currently showing a placeholder and the network operation 
        // indicates that it's had one failure, change the placeholder to the deferred 
        // placeholder.  The test for thumbnailImageIsPlaceholder is necessary in the 
        // -updateThumbnail case because we don't want to replace a valid (but old) 
        // thumbnail with a placeholder.
        
        if (self.thumbnailImageIsPlaceholder && self.getthumbnailOperation.hasHadRetryableFailure) {
            [self thumbnailCommitImage:[UIImage imageNamed:@"Placeholder-Deferred.png"] isPlaceholder:YES];
        }
    } else if (NO) {   // Disabled because the super class does nothing useful with it.
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

// Called when the HTTP operation to GET the photo's thumbnail completes.  
// If all is well, we start a resize operation to reduce it the appropriate 
// size.
- (void)thumbnailGetDone:(RetryingHTTPOperation *)operation

{
    assert([NSThread isMainThread]);
    assert([operation isKindOfClass:[RetryingHTTPOperation class]]);
    assert(operation == self.getthumbnailOperation);
    assert([self.getthumbnailOperation isFinished]);
    
    assert(self.resizethumbnailOperation == nil);
    
    [[QLog log] logWithFormat:@"Completed thumbnail GET for Product Item %@", self.productID];
    
    if (operation.error != nil) {
        [[QLog log] logWithFormat:@"Error for thumbnail GET: %@ for Product Item: %@", operation.error, self.productID];
        [self thumbnailCommitImage:nil isPlaceholder:YES];
        (void) [self stopThumbnail];
    } else {
        [[QLog log] logOption:kLogOptionNetworkData withFormat:@"receive %@", operation.responseContent];
        
        // Got the data successfully.  Let's start the resize operation.
        
        self.resizethumbnailOperation = [[MakeThumbnailOperation alloc] initWithImageData:operation.responseContent MIMEType:operation.responseMIMEType];
        assert(self.resizethumbnailOperation != nil);
        
        self.resizethumbnailOperation.thumbnailSize = kThumbNailSizeSmall;
        
        // We want thumbnails resizes to soak up unused CPU time, but the main thread should 
        // always run if it can.  The operation priority is a relative value (courtesy of the 
        // underlying Mach THREAD_PRECEDENCE_POLICY), that is, it sets the priority relative 
        // to other threads in the same process.  A value of 0.5 is the default, so we set a 
        // value significantly lower than that.
        
        if ( [self.resizethumbnailOperation respondsToSelector:@selector(setThreadPriority:)] ) {
            [self.resizethumbnailOperation setThreadPriority:0.2];
        }
        [self.resizethumbnailOperation setQueuePriority:NSOperationQueuePriorityLow];
        
        [[NetworkManager sharedManager] addCPUOperation:self.resizethumbnailOperation finishedTarget:self action:@selector(thumbnailResizeDone:)];
    }
}

// Called when the operation to resize the thumbnail completes.  
// If all is well, we commit the thumbnail to our database.
- (void)thumbnailResizeDone:(MakeThumbnailOperation *)operation
{
    UIImage *productImage;
    
    assert([NSThread isMainThread]);
    assert([operation isKindOfClass:[MakeThumbnailOperation class]]);
    assert(operation == self.resizethumbnailOperation);
    assert([self.resizethumbnailOperation isFinished]);
    
    [[QLog log] logWithFormat:@"Completed thumbnail resize for Product Item %@", self.productID];
    
    if (operation.thumbnail == NULL) {
        [[QLog log] logWithFormat:@"Failed thumbnail resize for Product Item %@", self.productID];
        productImage = nil;
    } else {
        productImage = [UIImage imageWithCGImage:operation.thumbnail];
        assert(productImage != nil);
    }
    
    [self thumbnailCommitImage:productImage isPlaceholder:NO];
    [self stopThumbnail];
}

- (void)thumbnailCommitImage:(UIImage *)image isPlaceholder:(BOOL)isPlaceholder
// Commits the thumbnail image to the object itself and to the Core Data database.
{
    // If we were given no image, that's a shortcut for the bad image placeholder.  In 
    // that case we ignore the incoming value of placeholder and force it to YES.
    
    if (image == nil) {
        isPlaceholder = YES;
        image = [UIImage imageNamed:@"Placeholder-Bad.png"];
        assert(image != nil);
    }
    
    // If it was a placeholder, someone else has logged about the failure, so 
    // we only log for real thumbnails.
    
    if ( ! isPlaceholder ) {
        [[QLog log] logWithFormat:@"Commit thumbnail for Product Item %@ thumbnail commit", self.productID];
    }
    
    // If we got a non-placeholder image, commit its PNG representation into our thumbnail 
    // database.  To avoid the scroll view stuttering, we only want to do this if the run loop 
    // is running in the default mode.  Thus, we check the mode and either do it directly or 
    // defer the work until the next time the default run loop mode runs.
    //
    // If we were running on iOS 4 or later we could get the PNG representation using 
    // ImageIO, but I want to maintain iOS 3 compatibility for the moment and on that 
    // system we have to use UIImagePNGRepresentation.
    
    if ( ! isPlaceholder ) {
        if ( [[[NSRunLoop currentRunLoop] currentMode] isEqual:NSDefaultRunLoopMode] ) {
            [self thumbnailCommitImageData:image];
        } else {
            [self performSelector:@selector(thumbnailCommitImageData:) withObject:image afterDelay:0.0 inModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
        }
    }
    
    // Commit the change to the thumbnailImage property.
    
    [self willChangeValueForKey:@"thumbnailImage"];
    self->thumbnailImage = image;
    [self  didChangeValueForKey:@"thumbnailImage"];    
}

// Commits the thumbnail data to the Core Data database.
- (void)thumbnailCommitImageData:(UIImage *)image

{
    [[QLog log] logWithFormat:@"Commit thumbnailImage data for Product Item %@", self.productID];
    
    // Create a MzProductThumbNail if none exists.
    
    if (self.thumbnail == nil) {
        self.thumbnail = [NSEntityDescription insertNewObjectForEntityForName:@"MzProductThumbnail" inManagedObjectContext:self.managedObjectContext];
        assert(self.thumbnail != nil);
    }
    
    // Store the thumbnail's imageData in the imageData property
    
    if (self.thumbnail.imageDataSmall == nil) {
        self.thumbnail.imageDataSmall = UIImagePNGRepresentation(image);
        assert(self.thumbnail.imageDataSmall != nil);
    }
}

- (UIImage *)thumbnailImage
{
    if (self->thumbnailImage == nil) {
        if ( (self.thumbnail != nil) && (self.thumbnail.imageDataSmall != nil) ) {
            
            // Return thumbnail from database if there is one.
            
            self.thumbnailImageIsPlaceholder = NO;
            self->thumbnailImage = [[UIImage alloc] initWithData:self.thumbnail.imageDataSmall];
            assert(self->thumbnailImage != nil);
        } else {
            
            assert(self.getthumbnailOperation == nil);               
            assert(self.resizethumbnailOperation == nil);   //             
            self.thumbnailImageIsPlaceholder = YES;
            self->thumbnailImage = [UIImage imageNamed:@"Placeholder.png"];
            assert(self->thumbnailImage != nil);
            
            [self startGetThumbnail];
        }
    }
    return self->thumbnailImage;
}

// Updates the thumbnail is response to a change in the owning MzProductItem object.
- (void)updateThumbnail

{
    [[QLog log] logWithFormat:@"Update thumbnail for Product Item %@", self.productID];
    
    // We only do an update if we've previously handed out a thumbnail image. 
    // If not, the thumbnail will be fetched normally when the client first 
    // requests an image.
    
    if (self->thumbnailImage != nil) {
        
        // If we're already getting a thumbnail, stop that get (it may be getting from 
        // the old path).
        
        (void) [self stopThumbnail];
        
        // Clear our thumbnail data.  This ensures that, if we quit before the get is complete, 
        // then, on relaunch, we will notice that we need to get the thumbnail.
        
        if (self.thumbnail != nil) {
            self.thumbnail.imageDataSmall = nil;
        }
        
        // Kick off the network get.   Keep thumbnailImage so the client 
        // will continue to see the old thumbnail (which might be a placeholder) until the 
        // get completes.
        
        [self startGetThumbnail];
    }
}

#pragma mark * Product Image

- (void)startGetPhoto
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
// If all is well, we commit the photo to the database.
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
        
        /* Move the file to the gallery's photo directory, and if that's successful, set localPhotoPath to point to it.  We automatically rename the file to avoid conflicts.  Conflicts do happen in day-to-day operations (specifically, in the case where we update a photo while actually displaying that photo)
        */
        
        fileCounter = 0;
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
}

// Register the gettingProductImage property as a dependent key for KVO notifications
+ (NSSet *)keyPathsForValuesAffectingGettingProductImage
{
    return [NSSet setWithObject:@"getPhotoOperation"];
}

- (BOOL)gettingProductImage
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
}

// Updates the product Image is response to a change in the Product Item's XML entity.
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
}


@end
