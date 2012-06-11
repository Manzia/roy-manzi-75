//
//  MzProductItem.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 6/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "MzProductThumbNail.h"

@class MzProductThumbNail;
@class RetryingHTTPOperation;
@class MakeThumbnailOperation;




@interface MzProductItem : NSManagedObject
{
    NSMutableDictionary *thumbnailImages;
    BOOL thumbnailImageIsPlaceholder;
    RetryingHTTPOperation *getThumbnailOperation;
    RetryingHTTPOperation *getPhotoperation;
    NSString *getPhotoFilePath;
    NSUInteger photoNeededAssertions;
    NSError *errorGettingImage;
}

// Creates a MzProductItem object with the specified properties in the specified context. 
// The properties dictionary is keyed by property names, in a KVC fashion.
+ (MzProductItem *)insertNewMzProductItemWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

// Updates the photo with the specified properties.  This will update the various 
// readonly properties listed below, triggering KVO notifications along the way
- (void)updateWithProperties:(NSDictionary *)properties;

// This method returns a thumbnail Image of the requested size, if there
// is no thumbnail in the thumbnailImages dictionary or in the Core Data
// database, we hit the network. In the latter case, a PlaceHolder image is
// returned in the meantime.
- (UIImage *)getthumbnailImage:(kThumbnailImageSize)thumbnailSize;

// Read-only public properties

// Immutable productID uniquely identifies a productItem, is KVO observable 
@property (nonatomic, retain, readonly) NSString * productID;

// productTitle is user-visible and is KVO observable
@property (nonatomic, retain, readonly) NSString * productTitle;

// URL Link to the Retailer's website for the specific productItem, KVO observable
@property (nonatomic, retain, readonly) NSString * productDetailPath;

// URL link to the full size photo image hosted by Retailer, is KVO observable
@property (nonatomic, retain, readonly) NSString * remoteImagePath;

// URL link to the thumbNail image hosted by Retailer, is KVO observable
@property (nonatomic, retain, readonly) NSString * remoteThumbnailPath;

// Text description of the productItem, is KVO observable & user-visible
@property (nonatomic, retain, readonly) NSString * productDescription;

// path of the photo file on disk, relative to the ProductCollectionContext pathToPhotosDirectory, or nil if not downloaded, is KVO observable
@property (nonatomic, retain, readonly) NSString * localImagePath;

// Datetime the productItem was inserted into the Core Data database
@property (nonatomic, retain, readonly) NSDate * productTimestamp;

// The language in which the product info will be displayed, is KVO observable
@property (nonatomic, retain, readonly) NSString * productLanguage;

// The country for which this product is available, is KVO observable
@property (nonatomic, retain, readonly) NSString * productCountry;

// The ClassID value is a numeric representation of the product Category
// used to group productItems e.g men's shoes, HP laptops etc., is KVO observable
@property (nonatomic, retain, readonly) NSString * productClassID;

// The SubClassID is a numeric representation of product sub-categories used
// to further sub-divide product categories e.g boots under men's shoes etc.
// property is KVO observable
@property (nonatomic, retain, readonly) NSString * productSubClassID;

// Price denomination of the productItem, is KVO observable & user-visible
@property (nonatomic, retain, readonly) NSString * productPriceUnit;

// Actual price value of the productItem, is KVO observable and user-visible
@property (nonatomic, retain, readonly) NSString * productPriceAmount;

// Product Brand - is KVO observable and user-visible
@property (nonatomic, retain, readonly) NSString * productBrand;

//Product condition e.g new, used etc, is KVO observable and user-visible
@property (nonatomic, retain, readonly) NSString * productCondition;

// Product availability e.g in stock, is KVO observable and user-visible
@property (nonatomic, retain, readonly) NSString * productAvailability;

// Pointer to the thumbnail object associated with the productItem
@property (nonatomic, retain, readonly) MzProductThumbNail *thumbnail;

// KVO observable, returns nil if the photo isn't available yet
@property (nonatomic, retain, readonly ) UIImage * productImage;  

// Property that returns getThumbnailOperation
@property(nonatomic, retain, readonly) RetryingHTTPOperation *getThumbnailOperation;


// The view controllers call the following methods to register/unregister to be provided
// with the full size image. Only if a view controller has explicitly registered will
// an actual photo be downloaded by the MzProductItem object.

- (void)needPhotoToDisplay;
- (void)removeFromPhotoToDisplay;

// The following properties capture the status of the product image download operation
// errorGettingImage will have a value if the photoImage is nil, i.e was not
// downloaded. gettingProductImage indicates whether or not the productImage is in
// the process of being downloaded.

@property (nonatomic, assign, readonly ) BOOL gettingProductImage;    
@property (nonatomic, copy,   readonly ) NSError *errorGettingImage; 


@end
