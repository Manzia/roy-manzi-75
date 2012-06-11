//
//  MzProductThumbNail.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 6/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzProductItem;
@class RetryingHTTPOperation;

// Available ThumbNail Sizes- these are created on-demand
// and stored in the Core Data database. When requesting a thumbnailImage
// these are the only options available for its size.

enum kThumbnailImageSize {
    
    kSmallThumbnailImage, 
    kMediumThumbnailImage, 
    kLargeThumbnailImage
};
typedef enum kThumbnailImageSize kThumbnailImageSize;


@interface MzProductThumbNail : NSManagedObject 
{
    NSArray *resizeOperations;
}

// The collection whose elements are the active on-going Thumbnail Resize
// Operations. The resize operations occur concurrently
@property (nonatomic, retain, readonly) NSArray *resizeOperations;

// Properties whose data is available after a resize Operation
@property (nonatomic, retain, readonly) NSData *imageDataLarge;
@property (nonatomic, retain, readonly) NSData *imageDataMedium;
@property (nonatomic, retain, readonly) NSData *imageDataSmall;

// Relationship property to the MzProductItem object that "owns" this
// MzProductThumbnail object
@property (nonatomic, retain) MzProductItem *productItem;

// stops all resize operations. This method will only execute if the 
//MzProductItem object that "owns" this MzProductThumbnail sends it
// otherwise it returns with NO
-(BOOL)stopResizeOperations:(id)sender;

// starts resize operations
-(void)startThumbnailResize:(RetryingHTTPOperation *)operation;

@end
