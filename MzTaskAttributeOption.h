//
//  MzTaskAttributeOption.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskAttribute;

@interface MzTaskAttributeOption : NSManagedObject

@property (nonatomic, retain) NSString * attributeOptionId;
@property (nonatomic, retain) NSString * attributeOptionName;
@property (nonatomic, retain) MzTaskAttribute *taskAttribute;

@end
