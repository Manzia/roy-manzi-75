//
//  MzReviewItem.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 1/30/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzProductItem;

@interface MzReviewItem : NSManagedObject {
    
}

// Creates a MzReviewItem object with the specified properties in the specified context.
// The properties dictionary is keyed by property names, in a KVC fashion.
+ (MzReviewItem *)insertNewMzReviewItemWithProperties:(NSDictionary *)properties
                               inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@property (nonatomic, retain, readonly) NSString * reviewAuthor;
@property (nonatomic, retain, readonly) NSString * reviewCategory;
@property (nonatomic, retain, readonly) NSString * reviewContent;
@property (nonatomic, retain, readonly) NSString * reviewId;
@property (nonatomic, retain, readonly) NSNumber * reviewRating;
@property (nonatomic, retain, readonly) NSString * reviewSku;
@property (nonatomic, retain, readonly) NSDate * reviewSubmitTime;
@property (nonatomic, retain, readonly) NSString * reviewTitle;

// The MzProductItem this MzReviewItem "belongs" to
@property (nonatomic, retain) MzProductItem *reviewProduct;

@end
