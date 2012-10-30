//
//  MzProductThumbNail.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 6/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzProductThumbNail.h"
#import "MzProductItem.h"
#import "RetryingHTTPOperation.h"
#import "Logging.h"
#import "MakeThumbnailOperation.h"
#import "NetworkManager.h"

// Available Thumbnail Sizes
// NOTE: This implementation was modified on 10/19/2012 so as to generate only one thumbnail Size.
NSString *const kThumbNailSizeSmall = @"45.0";
NSString *const kThumbNailSizeMedium = @"75.0";
NSString *const kThumbNailSizeLarge = @"90.0";

@interface MzProductThumbNail ()

// read/write 
@property (nonatomic, retain, readwrite) NSData *imageDataLarge;
@property (nonatomic, retain, readwrite) NSData *imageDataMedium;
@property (nonatomic, retain, readwrite) NSData *imageDataSmall;

// private properties
@property (nonatomic, retain, readwrite) NSArray *resizeOperations;
@property (nonatomic, retain, readwrite) NSMutableDictionary *resizedThumbnails;

@end

@implementation MzProductThumbNail

@dynamic imageDataLarge;
@dynamic imageDataMedium;
@dynamic imageDataSmall;
@dynamic productItem;

// Getters/Setters
@synthesize resizeOperations;
@synthesize resizedThumbnails;

#pragma mark * Resize operations

// Method is called when the HTTP operation to GET the productImage's thumbnail completes.  
- (void)startThumbnailResize:(RetryingHTTPOperation *)operation
{
    // Ensure we are in the right state and got called by our MzProductItem object
    assert([operation isKindOfClass:[RetryingHTTPOperation class]]);
    assert(operation == self.productItem.getThumbnailOperation);
    assert([self.productItem.getThumbnailOperation isFinished]);
    
    // If we already have on-going resize operations when we are called, we cancel
    // them since we now have new thumbnail data
    
    [self stopResizeOperations:self.productItem];
    assert(self.resizeOperations == nil);
    
    // Start the resize Operations
    /*
     Code modified on Oct 19, 2012 to only handle a single resizeOperation!
     By: Roy Manzi Tumubweinee, Manzia Corporation
     */
    [[QLog log] logWithFormat:@"Starting Resize for Product Item %@", self.productItem.productID];
    
    MakeThumbnailOperation *resizeOperationSmall;
    if ([operation.responseMIMEType isEqualToString:@"image/gif"]) {
        NSData *imageData = [self convertToPNGRepresentation:operation.responseContent];
        if (imageData != nil) {
            // small resize Operation
            resizeOperationSmall = [[MakeThumbnailOperation alloc] initWithImageData:imageData MIMEType:@"image/png"];
            assert(resizeOperationSmall != nil);
        }
    } else {
        // small resize Operation
        resizeOperationSmall = [[MakeThumbnailOperation alloc] initWithImageData:operation.responseContent MIMEType:operation.responseMIMEType];
        assert(resizeOperationSmall != nil);
    }   
    
    // Set the Thumbnail Size
    resizeOperationSmall.thumbnailSize = kThumbNailSizeSmall.floatValue;
    
    self.resizeOperations = [NSArray arrayWithObject:resizeOperationSmall];
    assert(self.resizeOperations != nil);
    
    // We want thumbnails resizes to soak up unused CPU time, but the main thread should 
    // always run if it can.  The operation priority is a relative value (courtesy of the 
    // underlying Mach THREAD_PRECEDENCE_POLICY), that is, it sets the priority relative 
    // to other threads in the same process.  A value of 0.5 is the default, so we set a 
    // value significantly lower than that.
    for (MakeThumbnailOperation *thumbnailOperation in self.resizeOperations) {
        if ([thumbnailOperation respondsToSelector:@selector(setThreadPriority:)] ) {
            [thumbnailOperation setThreadPriority:0.2];
        }
        [[NetworkManager sharedManager] addCPUOperation:thumbnailOperation finishedTarget:self action:@selector(thumbnailResizeComplete:)]; 
    }    
}

//Convert image/gif to image/png representation...we do this on the main thread for now but shall revisit
// after time profiling the performance impact. Also, we do this on the main thread coz we are not too sure about the 
// thread-safety of the UIImage function we are using to do the conversion. This conversion is required because
// the MakeThumbnailOperation operates only on image/jpeg and image/png
-(NSData *)convertToPNGRepresentation:(NSData *)gifData
{
    assert(gifData != nil);
    assert([gifData length] > 0);
    
    // Create Image - we use UIImage since it supports bunch of format including gif
    UIImage *gifImage = [UIImage imageWithData:gifData];
    assert(gifImage != nil);
    assert(gifImage.size.width > 0);
    assert(gifImage.size.height > 0);
    
    NSData *pngData = UIImagePNGRepresentation(gifImage);
    
    // Return
    if (pngData == nil) {
        [[QLog log] logWithFormat:@"Failed to convert image/gif to image/png for Product Item %@", self.productItem.productID];
        return nil;
    }
    return pngData;
}

// Method to stop resize operations
- (BOOL)stopResizeOperations:(id)sender
{
    // We only take "orders" from the MzProductItem that owns us
    if (![sender isKindOfClass:[MzProductItem class]]) {
        return NO;
    }
    if (sender != self.productItem) {
        return NO;
    }
    
    // Carry out the stop resize
    BOOL didSomething = NO;
        
    // stop resize operations
    if (self.resizeOperations != nil && [self.resizeOperations count] > 0) {
        
        for (MakeThumbnailOperation *operation in self.resizeOperations) {
            [[NetworkManager sharedManager] cancelOperation:operation];
        }
        self.resizeOperations = nil;        // ARC releases the operations as well
        didSomething = YES;
    } else {
        self.resizeOperations = nil;
        didSomething = YES;
    }
    
    // clear our dictionary
    if (self.resizedThumbnails != nil && [self.resizedThumbnails count] > 0) {
        [self.resizedThumbnails removeAllObjects];
        self.resizedThumbnails = nil;
        didSomething = YES;
    } else {
        self.resizedThumbnails = nil;
        didSomething = YES;
    }
    return didSomething;                                      
}

// Called when the operation to resize the thumbnail completes.  
// If all is well, we commit the thumbnail to our database.
- (void)thumbnailResizeComplete:(MakeThumbnailOperation *)operation
{
    UIImage *productThumbImage;
    __block BOOL validOperation = NO;
    
    assert([NSThread isMainThread]);
    assert([self.resizeOperations count] > 0 );
    assert([operation isKindOfClass:[MakeThumbnailOperation class]]);
    
    // check that this is one of "our" operations
    for (MakeThumbnailOperation *thumbOperation in self.resizeOperations)
     {
         if(operation == thumbOperation) validOperation = YES;
     }
    assert(validOperation);
    assert([operation isFinished]);
    
    if (operation.thumbnail == nil) {
        [[QLog log] logWithFormat:@"Failed thumbnail resize for Product Item %@", self.productItem.productID];
        productThumbImage = nil;
    } else {
        [[QLog log] logWithFormat:@"Completed thumbnail resize for Product Item %@", self.productItem.productID];
        productThumbImage = [UIImage imageWithCGImage:operation.thumbnail];
        assert(productThumbImage != nil);
        
        // Add entries to our dictionary
        // check the thumbnail sizes
        assert(operation.thumbnailSize == [kThumbNailSizeSmall floatValue] || operation.thumbnailSize == [kThumbNailSizeMedium floatValue] || operation.thumbnailSize == [kThumbNailSizeLarge floatValue]);
        
        if(self.resizedThumbnails == nil) {
            self.resizedThumbnails = [[NSMutableDictionary alloc] init];
            assert(self.resizedThumbnails != nil);
        }
        
        if (operation.thumbnailSize == [kThumbNailSizeSmall floatValue]) {
            [self.resizedThumbnails setObject:productThumbImage forKey:kThumbNailSizeSmall];
            
        } else if (operation.thumbnailSize == [kThumbNailSizeMedium floatValue]) {
            [self.resizedThumbnails setObject:productThumbImage forKey:kThumbNailSizeMedium];
            
        } else if (operation.thumbnailSize == [kThumbNailSizeLarge floatValue]) {
            [self.resizedThumbnails setObject:productThumbImage forKey:kThumbNailSizeLarge];
            
        } else {
            // No code path leads here but who knows....
            [[QLog log] logWithFormat:@"Invalid thumbnail resize for Product Item %@", self.productItem.productID];
            productThumbImage = nil;
        }
        
        /* commit PNG representation into our thumbnail database.  To avoid the scroll view stuttering, we only want to do this if the run loop is running in the default mode.  Thus, we check the mode and either do it directly or defer the work until the next time the default run loop mode runs.
         */
        [[QLog log] logWithFormat:@"Will commit thumbnail for Product Item %@", self.productItem.productID];
        if ( [[[NSRunLoop currentRunLoop] currentMode] isEqual:NSDefaultRunLoopMode] ) {
            [self thumbnailCommitImageData:productThumbImage];
        } else {
            [self performSelector:@selector(thumbnailCommitImageData:) withObject:productThumbImage afterDelay:0.0 inModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];            
        }        
    }   
        
}

// Manual KVO notifications
+(BOOL)automaticallyNotifiesObserversOfImageDataSmall
{
    return NO;
}

+(BOOL)automaticallyNotifiesObserversOfImageDataMedium
{
    return NO;
}

+(BOOL)automaticallyNotifiesObserversOfImageDataLarge
{
    return NO;
}

// Commit the image based on thumbnailSize
- (void)thumbnailCommitImageData:(UIImage *)image
{
    __block NSString *imageSize;
    
    [[QLog log] logWithFormat:@"Commiting thumbnailImage data for Product Item... %@", self.productItem.productID];
    assert([self.resizedThumbnails count] > 0);
    
    // we only commit images that are in our resizedThumbnails dictionary
    [self.resizedThumbnails enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop)
     {
         if (image == value) { //we compare the actual pointer values
             imageSize = [NSString stringWithString:key];
         } 
     }];
    
    if (imageSize == nil) {
        [[QLog log] logWithFormat:@"Invalid thumbnailImage data to commit for Product Item %@", self.productItem.productID];
        return;
    }
          
    // Store the thumbnail's imageData in the imageData property but first clear
    // any existing thumbnail imageData
    if ([imageSize isEqualToString:kThumbNailSizeSmall]) {
        self.imageDataSmall = nil;
        [self willChangeValueForKey:@"imageDataSmall"];
        self.imageDataSmall = [[NSData alloc] initWithData:UIImagePNGRepresentation(image)];
        assert(self.imageDataSmall != nil);
        [self didChangeValueForKey:@"imageDataSmall"];
        
    } /*else if ([imageSize isEqualToString:kThumbNailSizeMedium]) {
        self.imageDataMedium = nil;
        [self willChangeValueForKey:@"imageDataMedium"];
        self.imageDataMedium = UIImagePNGRepresentation(image);
        assert(self.imageDataMedium != nil);
        [self didChangeValueForKey:@"imageDataMedium"];
        
    } else if ([imageSize isEqualToString:kThumbNailSizeLarge]) {
        self.imageDataLarge = nil;
        [self willChangeValueForKey:@"imageDataLarge"];
        self.imageDataLarge = UIImagePNGRepresentation(image);
        assert(self.imageDataLarge != nil);
        [self didChangeValueForKey:@"imageDataLarge"];
    }   */
    
    [[QLog log] logWithFormat:@"Successful Commit thumbnailImage data for Product Item %@", self.productItem.productID];
}

    




@end
