//
//  MzTaskAttributeOption.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/8/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskAttribute;

@interface MzTaskAttributeOption : NSManagedObject

@property (nonatomic, retain) NSString * attributeOptionId;
@property (nonatomic, retain) NSString * attributeOptionName;
@property (nonatomic, retain) MzTaskAttribute *taskAttribute;

-(void)prepareForDeletion;

@end
