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

@property (nonatomic, strong, readonly) NSString * reviewAuthor;
@property (nonatomic, strong, readonly) NSString * reviewCategory;
@property (nonatomic, strong, readonly) NSString * reviewContent;
@property (nonatomic, strong, readonly) NSString * reviewId;
@property (nonatomic, strong, readonly) NSNumber * reviewRating;
@property (nonatomic, strong, readonly) NSString * reviewSku;
@property (nonatomic, strong, readonly) NSDate * reviewSubmitTime;
@property (nonatomic, strong, readonly) NSString * reviewTitle;
@property (nonatomic, strong, readonly) NSString *reviewSource;

// The MzProductItem this MzReviewItem "belongs" to
@property (nonatomic, retain) MzProductItem *reviewProduct;

@end
