//
//  MzTaskAttribute.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskAttributeOption, MzTaskType;

@interface MzTaskAttribute : NSManagedObject

@property (nonatomic, retain) NSString * taskAttributeId;
@property (nonatomic, retain) NSString * taskAttributeName;
@property (nonatomic, retain) MzTaskType *taskType;
@property (nonatomic, retain) NSOrderedSet *attributeOptions;
@end

@interface MzTaskAttribute (CoreDataGeneratedAccessors)

- (void)insertObject:(MzTaskAttributeOption *)value inAttributeOptionsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromAttributeOptionsAtIndex:(NSUInteger)idx;
- (void)insertAttributeOptions:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeAttributeOptionsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInAttributeOptionsAtIndex:(NSUInteger)idx withObject:(MzTaskAttributeOption *)value;
- (void)replaceAttributeOptionsAtIndexes:(NSIndexSet *)indexes withAttributeOptions:(NSArray *)values;
- (void)addAttributeOptionsObject:(MzTaskAttributeOption *)value;
- (void)removeAttributeOptionsObject:(MzTaskAttributeOption *)value;
- (void)addAttributeOptions:(NSOrderedSet *)values;
- (void)removeAttributeOptions:(NSOrderedSet *)values;

// Helper method for inserts
-(NSUInteger)indexToInsert;

@end
