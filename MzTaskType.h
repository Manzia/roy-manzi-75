//
//  MzTaskType.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskAttribute, MzTaskCategory, MzTaskTypeImage;

@interface MzTaskType : NSManagedObject

@property (nonatomic, retain) NSString * taskTypeId;
@property (nonatomic, retain) NSString * taskTypeName;
@property (nonatomic, retain) NSString * taskTypeImageURL;
@property (nonatomic, retain) MzTaskCategory *taskCategory;
@property (nonatomic, retain) MzTaskTypeImage *taskTypeImage;
@property (nonatomic, retain) NSOrderedSet *taskAttributes;
@end

@interface MzTaskType (CoreDataGeneratedAccessors)

- (void)insertObject:(MzTaskAttribute *)value inTaskAttributesAtIndex:(NSUInteger)idx;
- (void)removeObjectFromTaskAttributesAtIndex:(NSUInteger)idx;
- (void)insertTaskAttributes:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeTaskAttributesAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInTaskAttributesAtIndex:(NSUInteger)idx withObject:(MzTaskAttribute *)value;
- (void)replaceTaskAttributesAtIndexes:(NSIndexSet *)indexes withTaskAttributes:(NSArray *)values;
- (void)addTaskAttributesObject:(MzTaskAttribute *)value;
- (void)removeTaskAttributesObject:(MzTaskAttribute *)value;
- (void)addTaskAttributes:(NSOrderedSet *)values;
- (void)removeTaskAttributes:(NSOrderedSet *)values;
@end
