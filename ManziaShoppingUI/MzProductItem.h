//
//  MzProductItem.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 6/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzProductThumbNail;

@interface MzProductItem : NSManagedObject

// Creates a photo with the specified properties in the specified context. 
// The properties dictionary is keyed by property names, in a KVC fashion.
+ (MzProductItem *)insertNewProductItemWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

- (void)updateWithProperties:(NSDictionary *)properties;
// Updates the photo with the specified properties.  This will update the various 
// readonly properties listed below, triggering KVO notifications along the way.



@property (nonatomic, retain) NSString * productID;
@property (nonatomic, retain) NSString * productTitle;
@property (nonatomic, retain) NSString * productDetailPath;
@property (nonatomic, retain) NSString * remoteImagePath;
@property (nonatomic, retain) NSString * remoteThumbnailPath;
@property (nonatomic, retain) NSString * productDescription;
@property (nonatomic, retain) NSString * localImagePath;
@property (nonatomic, retain) NSDate * productTimestamp;
@property (nonatomic, retain) NSString * productLanguage;
@property (nonatomic, retain) NSString * productCountry;
@property (nonatomic, retain) NSString * productClassID;
@property (nonatomic, retain) NSString * productSubClassID;
@property (nonatomic, retain) NSString * productPriceUnit;
@property (nonatomic, retain) NSString * productPriceAmount;
@property (nonatomic, retain) NSString * productBrand;
@property (nonatomic, retain) NSString * productCondition;
@property (nonatomic, retain) NSString * productAvailability;
@property (nonatomic, retain) MzProductThumbNail *thumbnail;

@end
