//
//  MzTaskAttribute.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskAttribute.h"
#import "MzTaskAttributeOption.h"
#import "MzTaskType.h"


@implementation MzTaskAttribute

@dynamic taskAttributeId;
@dynamic taskAttributeName;
@dynamic taskType;
@dynamic attributeOptions;

// Implements mutable accessor for Indexed collection
- (void)addAttributeOptionsObject:(MzTaskAttributeOption *)value
{
    [self willChangeValueForKey:@"attributeOptions"];
    NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.attributeOptions];
    assert(tempSet != nil);
    [tempSet addObject:value];
    self.attributeOptions = tempSet;
    [self didChangeValueForKey:@"attributeOptions"];
}

- (void)addAttributeOptions:(NSOrderedSet *)values
{
    [self willChangeValueForKey:@"attributeOptions"];
    NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.attributeOptions];
    assert(tempSet != nil);
    [tempSet unionOrderedSet:values];
    self.attributeOptions = tempSet;
    [self didChangeValueForKey:@"attributeOptions"];
}

- (void)removeAttributeOptionsAtIndexes:(NSIndexSet *)indexes
{
    [self willChangeValueForKey:@"attributeOptions"];
    NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.attributeOptions];
    assert(tempSet != nil);
    [tempSet removeObjectsAtIndexes:indexes];
    self.attributeOptions = tempSet;
    [self didChangeValueForKey:@"attributeOptions"];
}

// Helper method that works around Apple's Bug when you use the add<Key>Object: method on an NSOrderedSet
// to-many relationship property generated automatically by CoreData....that method crashes with a [NSSet intersectsSet:]: error
-(NSUInteger)indexToInsert
{
    assert(self.attributeOptions != nil);
    NSIndexSet *indexSet;
    
    indexSet = [self.attributeOptions indexesOfObjectsPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
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
