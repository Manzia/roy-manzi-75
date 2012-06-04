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

@interface MzProductThumbNail : NSManagedObject

@property (nonatomic, retain) NSData * imageDataLarge;
@property (nonatomic, retain) NSData * imageDataMedium;
@property (nonatomic, retain) NSData * imageDataSmall;
@property (nonatomic, retain) MzProductItem *productItem;

@end
