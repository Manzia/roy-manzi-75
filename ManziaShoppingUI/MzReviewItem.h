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

@interface MzReviewItem : NSManagedObject

@property (nonatomic, retain) NSString * reviewAuthor;
@property (nonatomic, retain) NSString * reviewCategory;
@property (nonatomic, retain) NSString * reviewContent;
@property (nonatomic, retain) NSString * reviewId;
@property (nonatomic, retain) NSNumber * reviewRating;
@property (nonatomic, retain) NSString * reviewSku;
@property (nonatomic, retain) NSDate * reviewSubmitTime;
@property (nonatomic, retain) NSString * reviewTitle;
@property (nonatomic, retain) MzProductItem *reviewProduct;

@end
