//
//  MzTaskType.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskType.h"
#import "MzTaskAttribute.h"
#import "MzTaskCategory.h"
#import "MzTaskTypeImage.h"


@implementation MzTaskType

@dynamic taskTypeId;
@dynamic taskTypeName;
@dynamic taskTypeImageURL;
@dynamic taskCategory;
@dynamic taskTypeImage;
@dynamic taskAttributes;

// Implements mutable accessor for Indexed collection
- (void)addTaskAttributesObject:(MzTaskAttribute *)value
{
    [self willChangeValueForKey:@"taskAttributes"];
    NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.taskAttributes];
    assert(tempSet != nil);
    [tempSet addObject:value];
    self.taskAttributes = tempSet;
    [self didChangeValueForKey:@"taskAttributes"];
}

- (void)addTaskAttributes:(NSOrderedSet *)values
{
    [self willChangeValueForKey:@"taskAttributes"];
    NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.taskAttributes];
    assert(tempSet != nil);
    [tempSet unionOrderedSet:values];
    self.taskAttributes = tempSet;
    [self didChangeValueForKey:@"taskAttributes"];
}

- (void)removeTaskAttributesAtIndexes:(NSIndexSet *)indexes
{
    [self willChangeValueForKey:@"taskAttributes"];
    NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.taskAttributes];
    assert(tempSet != nil);
    [tempSet removeObjectsAtIndexes:indexes];
    self.taskAttributes = tempSet;
    [self didChangeValueForKey:@"taskAttributes"];
}


// Helper method that works around Apple's Bug when you use the add<Key>Object: method on an NSOrderedSet
// to-many relationship property generated automatically by CoreData....that method crashes with a [NSSet intersectsSet:]: error
-(NSUInteger)indexToInsert
{
    assert(self.taskAttributes != nil);
    NSIndexSet *indexSet;
    
    indexSet = [self.taskAttributes indexesOfObjectsPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
        return  YES;
    }];
    
    // determine the Index
    if ([indexSet firstIndex] == NSNotFound) {
        return 0;
    } else {
        return [indexSet lastIndex] + 1;
    }
}


@end
