//
//  MzTaskAttribute.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/8/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskAttributeOption, MzTaskType;

@interface MzTaskAttribute : NSManagedObject

@property (nonatomic, retain) NSString * taskAttributeId;
@property (nonatomic, retain) NSString * taskAttributeName;
@property (nonatomic, retain) NSSet *attributeOptions;
@property (nonatomic, retain) MzTaskType *taskType;
@end

@interface MzTaskAttribute (CoreDataGeneratedAccessors)

- (void)addAttributeOptionsObject:(MzTaskAttributeOption *)value;
- (void)removeAttributeOptionsObject:(MzTaskAttributeOption *)value;
- (void)addAttributeOptions:(NSSet *)values;
- (void)removeAttributeOptions:(NSSet *)values;

@end
