//
//  MzTaskCategory.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskType;

@interface MzTaskCategory : NSManagedObject

@property (nonatomic, retain) NSString * categoryId;
@property (nonatomic, retain) NSString * categoryName;
@property (nonatomic, retain) NSString * categoryImageURL;
@property (nonatomic, retain) NSOrderedSet *taskTypes;
@end

@interface MzTaskCategory (CoreDataGeneratedAccessors)

- (void)insertObject:(MzTaskType *)value inTaskTypesAtIndex:(NSUInteger)idx;
- (void)removeObjectFromTaskTypesAtIndex:(NSUInteger)idx;
- (void)insertTaskTypes:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeTaskTypesAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInTaskTypesAtIndex:(NSUInteger)idx withObject:(MzTaskType *)value;
- (void)replaceTaskTypesAtIndexes:(NSIndexSet *)indexes withTaskTypes:(NSArray *)values;
- (void)addTaskTypesObject:(MzTaskType *)value;
- (void)removeTaskTypesObject:(MzTaskType *)value;
- (void)addTaskTypes:(NSOrderedSet *)values;
- (void)removeTaskTypes:(NSOrderedSet *)values;

// Creates a MzTaskCategory object with the specified properties in the specified context. 
// The properties dictionary is keyed by property names, in a KVC fashion.
+ (MzTaskCategory *)insertNewMzTaskCategoryWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

// Updates the MzTaskCategory object with the specified properties. 
- (void)updateWithProperties:(NSDictionary *)properties;
@end
