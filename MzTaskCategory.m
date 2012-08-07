//
//  MzTaskCategory.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskCategory.h"
#import "MzTaskType.h"
#import "MzTaskAttribute.h"
#import "MzTaskAttributeOption.h"
#import "Logging.h"
#import "MzQueryItem.h"

@interface MzTaskCategory ()

// forward declaration
- (void) updateTaskCategoryThumbnail;

@end

@implementation MzTaskCategory

@dynamic categoryId;
@dynamic categoryName;
@dynamic categoryImageURL;
@dynamic taskTypes;

#pragma mark * Mutable Accessors

// Mutable accessors for the Indexed collection to-many relationship
- (void)addTaskTypesObject:(MzTaskType *)value;
{
    [self willChangeValueForKey:@"taskTypes"];
    NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.taskTypes];
    assert(tempSet != nil);
    [tempSet addObject:value];
    self.taskTypes = tempSet;
    [self didChangeValueForKey:@"taskTypes"];
}

- (void)addTaskTypes:(NSOrderedSet *)values;
{
    [self willChangeValueForKey:@"taskTypes"];
    NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.taskTypes];
    assert(tempSet != nil);
    [tempSet unionOrderedSet:values];
    self.taskTypes = tempSet;
    [self didChangeValueForKey:@"taskTypes"];
}

- (void)removeTaskTypesAtIndexes:(NSIndexSet *)indexes;
{
    [self willChangeValueForKey:@"taskTypes"];
    NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.taskTypes];
    assert(tempSet != nil);
    [tempSet removeObjectsAtIndexes:indexes];
    self.taskTypes = tempSet;
    [self didChangeValueForKey:@"taskTypes"];
}


#pragma mark * Insert & Update Task Category
// Creates a MzProductItem object with the specified properties in the specified context. 
// The properties dictionary is keyed by property names, in a KVC fashion.

+ (MzTaskCategory *)insertNewMzTaskCategoryWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    MzTaskCategory *insertCategory;
    MzTaskType *insertTaskType;
    MzTaskAttribute *insertTaskAttribute;    
    
    assert(properties != nil);
    assert( [[properties objectForKey:@"categoryId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"categoryName"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"categoryImageURL"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskTypeId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskTypeName"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskTypeImageURL"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskAttributeId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskAttributeName"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"attributeOptionId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"attributeOptionName"] isKindOfClass:[NSArray class]] );
        
    assert(managedObjectContext != nil);
    
    insertCategory = (MzTaskCategory *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskCategory" inManagedObjectContext:managedObjectContext];
    
    // check we have a valid MzTaskCategory and assign the new properties
    if (insertCategory != nil) {
        assert([insertCategory isKindOfClass:[MzTaskCategory class]]);
        
        insertCategory.categoryId = [[properties objectForKey:@"categoryId"] copy];
        assert(insertCategory.categoryId != nil);
        
        insertCategory.categoryName = [[properties objectForKey:@"categoryName"] copy];
        insertCategory.categoryImageURL = [[properties objectForKey:@"categoryImageURL"] copy];
        
        // add the MzTaskType object relationship
        insertTaskType = (MzTaskType *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskType" inManagedObjectContext:managedObjectContext];
        assert(insertTaskType != nil);
        assert([insertTaskType isKindOfClass:[MzTaskType class]]);
        
        insertTaskType.taskTypeId = [[properties objectForKey:@"taskTypeId"] copy];
        insertTaskType.taskTypeName =[[properties objectForKey:@"taskTypeName"] copy];
        insertTaskType.taskTypeImageURL = [[properties objectForKey:@"taskTypeImageURL"] copy];
        
        // add the MzTaskAttribute object relationship
        insertTaskAttribute = (MzTaskAttribute *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttribute" inManagedObjectContext:managedObjectContext];
        assert(insertTaskAttribute != nil);
        assert([insertTaskAttribute isKindOfClass:[MzTaskAttribute class]]);
        
        insertTaskAttribute.taskAttributeId = [[properties objectForKey:@"taskAttributeId"] copy];
        insertTaskAttribute.taskAttributeName = [[properties objectForKey:@"taskAttributeName"] copy];
        
        // add the MzTaskAttributeOption object relationship
        /* NOTE THAT ITS IMPORTANT TO KEEP THE FOLLOWING DISTINCTION
         The value for the  key "attributeOptionName" passed in from the parse results is an
         NSArray of strings each of which represents an MzTaskAttributeOption managed object i.e
         the string is assigned to "attributeOptionName" property of  each 
         MzTaskAttributeOption managed object created.         
         */
        NSArray *attributeOptions;
        attributeOptions = [NSArray arrayWithArray:[properties objectForKey:@"attributeOptionName"]];
        assert(attributeOptions != nil);
        if ([attributeOptions count] > 0) {
            
            // create the MzTaskAttributeOption objects
            NSMutableArray *attributeArray;
            attributeArray = [NSMutableArray array];
            assert(attributeArray != nil);
            NSOrderedSet *attributeSet;
            
            for (NSString *options in attributeOptions ) {
                MzTaskAttributeOption *insertAttributeOption = (MzTaskAttributeOption *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttributeOption" inManagedObjectContext:managedObjectContext];
                assert(insertAttributeOption != nil);
                assert([insertAttributeOption isKindOfClass:[MzTaskAttributeOption class]]);
                
                // attributeOptionId value is same as taskAttributeId value
                insertAttributeOption.attributeOptionId = [[properties objectForKey:@"taskAttributeId"] copy];
                insertAttributeOption.attributeOptionName = options;
                insertAttributeOption.taskAttribute = insertTaskAttribute;
                assert(insertAttributeOption.taskAttribute != nil);
                
                // Link to the MzTaskAttribute
                [attributeArray addObject:insertAttributeOption];
            }
            // Link to the passed MzTaskAttribute object
            attributeSet = [NSOrderedSet orderedSetWithArray:attributeArray];
            assert(attributeSet != nil);
            [insertTaskAttribute addAttributeOptions:attributeSet];
            
        } else {
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Task Attribute: %@ for Task Category: %@ with Task Type: %@ has no attributeOptions", [properties objectForKey:@"taskAttributeName"], [properties objectForKey:@"categoryName"], [properties objectForKey:@"taskTypeName"]];
        }
        
        // Link to the MzTaskType
        [insertTaskType addTaskAttributesObject:insertTaskAttribute];
        
        // Update MzQueryItem table
        [MzQueryItem updateMzQueryItemsForTaskType:insertTaskType inManagedObjectContext:managedObjectContext];
        
        // Link to the MzTaskCategory
        [insertCategory addTaskTypesObject:insertTaskType];        
        
    }
    return insertCategory;
}

// Updates the taskCategory with the specified properties.  This will update the various 
// readonly properties listed below, triggering KVO notifications along the way
- (void)updateWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)context
{
    BOOL   categoryThumbnailNeedsUpdate;
    
        
    assert(properties != nil);
    assert( [[properties objectForKey:@"categoryId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"categoryName"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"categoryImageURL"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskTypeId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskTypeName"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskTypeImageURL"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskAttributeId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskAttributeName"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"attributeOptionId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"attributeOptionName"] isKindOfClass:[NSArray class]] );
    
    // Update the properties
    categoryThumbnailNeedsUpdate = NO;
    
    
    // This method was called on "us" (this MzTaskCategory object) because we have
    // the "right" categoryId value
    
    if (![self.categoryId isEqualToString:[properties objectForKey:@"categoryId"]]) {
        
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Unexpected categoryId: %@ will not update",[properties objectForKey:@"categoryId"]]; 
        return;
    } else {
        
        // check TaskCategory properties
        if (![self.categoryName isEqualToString:[properties objectForKey:@"categoryName"]]) {
            self.categoryName = [[properties objectForKey:@"categoryName"] copy];
        }
        
        if (![self.categoryImageURL isEqualToString:[properties objectForKey:@"categoryImageURL"]]) {
            self.categoryImageURL = [[properties objectForKey:@"categoryImageURL"] copy];
            categoryThumbnailNeedsUpdate = YES;
        }
        
        // check the TaskType properties and update accordingly
        [self updateTaskTypeWithProperties:properties inManagedObjectContext:context];
        assert(self.taskTypes != nil);
        
                    
        // categoryId has no valid taskType values
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Update existing TaskCategory with categoryId: %@",[properties objectForKey:@"categoryId"]]; 
        }        
            
    // Do the thmbnail updates.
    if (categoryThumbnailNeedsUpdate) {
        [self updateTaskCategoryThumbnail];
    }    
       
}


// Method updates or inserts the MzTaskType objects for a given MzTaskCategory object based on the
// passed properties dictionary
- (void) updateTaskTypeWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(properties != nil);
    assert( [[properties objectForKey:@"taskTypeId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskTypeName"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskTypeImageURL"] isKindOfClass:[NSString class]] );
    
    // check TaskType properties
    MzTaskType *updateTaskType;
    MzTaskType *insertTaskType;
    NSIndexSet *result;
    BOOL taskTypeThumbnailNeedsUpdate;
    
    taskTypeThumbnailNeedsUpdate = NO;
    
    // Iterate over all the taskType objects we are "related" to
    if ([self.taskTypes count] > 0) {
        result = [self.taskTypes indexesOfObjectsPassingTest:
                  ^(MzTaskType *obj, NSUInteger idx, BOOL *stop) {
                      if ([obj.taskTypeId isEqualToString:[properties objectForKey:@"taskTypeId"]]) {
                          *stop =YES;
                          return YES;   // found a match...stop
                      } else {
                          return  NO;   // keep looking
                      }    
                  }];
        if ([result firstIndex] != NSNotFound) {
            
            //Note that we may repeatedly keep on doing the same updates, we can come with
            // some logic to keep track of which taskTypeId's we've seen before but the
            // time & memory savings are negligible so we just crunch away...
            updateTaskType = [self.taskTypes objectAtIndex:[result firstIndex]];
            
            if (![updateTaskType.taskTypeName isEqualToString:[properties objectForKey:@"taskTypeName"]]) {
                updateTaskType.taskTypeName = [[properties objectForKey:@"taskTypeName"] copy];
            }
            
            if (![updateTaskType.taskTypeImageURL isEqualToString:[properties objectForKey:@"taskTypeImageURL"]]) {
                updateTaskType.taskTypeImageURL = [[properties objectForKey:@"taskTypeImageURL"] copy];
                taskTypeThumbnailNeedsUpdate = YES;
            }
            
            // Update the taskAttributes relationship
            [self updateTaskAttributeWithProperties:properties forTaskType:updateTaskType inManagedObjectContext:context];
            
            // Update the MzQueryItem entity
            [MzQueryItem updateMzQueryItemsForTaskType:updateTaskType inManagedObjectContext:context];
            
        } else {
            
            // no match, so we need to insert a new MzTaskType object
            // add the MzTaskType object relationship
            insertTaskType = (MzTaskType *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskType" inManagedObjectContext:context];
            assert(insertTaskType != nil);
            assert([insertTaskType isKindOfClass:[MzTaskType class]]);
            
            insertTaskType.taskTypeId = [[properties objectForKey:@"taskTypeId"] copy];
            insertTaskType.taskTypeName =[[properties objectForKey:@"taskTypeName"] copy];
            insertTaskType.taskTypeImageURL = [[properties objectForKey:@"taskTypeImageURL"] copy];
            
            // update the taskAttributes relationship
            [self updateTaskAttributeWithProperties:properties forTaskType:insertTaskType inManagedObjectContext:context];
            
            // Add to the To-Many relationship
            [self addTaskTypesObject:insertTaskType];
            
            // Update the MzQueryItem entity
            [MzQueryItem updateMzQueryItemsForTaskType:insertTaskType inManagedObjectContext:context];
        }
        
    } else {
        
        // we have no taskType objects linked to us so we add the new one
        insertTaskType = (MzTaskType *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskType" inManagedObjectContext:context];
        assert(insertTaskType != nil);
        assert([insertTaskType isKindOfClass:[MzTaskType class]]);
        
        insertTaskType.taskTypeId = [[properties objectForKey:@"taskTypeId"] copy];
        insertTaskType.taskTypeName =[[properties objectForKey:@"taskTypeName"] copy];
        insertTaskType.taskTypeImageURL = [[properties objectForKey:@"taskTypeImageURL"] copy];
        
        // update the taskAttributes relationship
        [self updateTaskAttributeWithProperties:properties forTaskType:insertTaskType 
                         inManagedObjectContext:context];
        
        // Add to the To-Many relationship
        [self addTaskTypesObject:insertTaskType];
        
        // Update the MzQueryItem entity
        [MzQueryItem updateMzQueryItemsForTaskType:insertTaskType inManagedObjectContext:context];
    }
    
    // Update thumbnail
    if (taskTypeThumbnailNeedsUpdate) {
        [updateTaskType updateTaskTypeThumbnail];
    }
}

// Method updates or inserts MzTaskAttribute objects for a given MzTaskType object based on the
// passed properties dictionary
- (void) updateTaskAttributeWithProperties:(NSDictionary *)properties forTaskType:(MzTaskType *)taskType inManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(properties != nil);
    assert(taskType != nil);
    assert( [[properties objectForKey:@"taskAttributeId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"taskAttributeName"] isKindOfClass:[NSString class]] );
    
    // check TaskType properties
    MzTaskAttribute *updateTaskAttribute;
    MzTaskAttribute *insertTaskAttribute;
    NSIndexSet *result;
    
    // Iterate over all the taskAttributes objects we are "related" to
    if ([taskType.taskAttributes count] > 0) {
        result = [taskType.taskAttributes indexesOfObjectsPassingTest:
                  ^(MzTaskAttribute *obj, NSUInteger idx, BOOL *stop) {
                      if ([obj.taskAttributeId isEqualToString:[properties objectForKey:@"taskAttributeId"]]) {
                          *stop =YES;
                          return YES;   // found a match...stop
                      } else {
                          return  NO;   // keep looking
                      }    
                  }];
        if ([result firstIndex] != NSNotFound) {
            updateTaskAttribute = [taskType.taskAttributes objectAtIndex:[result firstIndex]];
            
            if (![updateTaskAttribute.taskAttributeName isEqualToString:[properties objectForKey:@"taskAttributeName"]]) {
                updateTaskAttribute.taskAttributeName = [[properties objectForKey:@"taskAttributeName"] copy];
            }
            
            // update the attributeOptions relationship
            [self updateAttributeOptionWithProperties:properties forTaskAttribute:updateTaskAttribute inManagedObjectContext:context];
            
        } else {
            
            // no match, so we need to insert a new MzTaskAttribute object
            // add the MzTaskAttribute object relationship
            insertTaskAttribute = (MzTaskAttribute *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttribute" inManagedObjectContext:context];
            assert(insertTaskAttribute != nil);
            assert([insertTaskAttribute isKindOfClass:[MzTaskAttribute class]]);
            
            insertTaskAttribute.taskAttributeId = [[properties objectForKey:@"taskAttributeId"] copy];
            insertTaskAttribute.taskAttributeName =[[properties objectForKey:@"taskAttributeName"] copy];
            
            // update the attributeOptions relationship
            [self updateAttributeOptionWithProperties:properties forTaskAttribute:insertTaskAttribute inManagedObjectContext:context];
            
            // Link to the new MzTaskAttribute object
            [taskType addTaskAttributesObject:insertTaskAttribute];
        }
        
    } else {
        
        // we have no taskAttribute objects linked to us so we add the new one
        insertTaskAttribute = (MzTaskAttribute *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttribute" inManagedObjectContext:context];
        assert(insertTaskAttribute != nil);
        assert([insertTaskAttribute isKindOfClass:[MzTaskAttribute class]]);
        
        insertTaskAttribute.taskAttributeId = [[properties objectForKey:@"taskAttributeId"] copy];
        insertTaskAttribute.taskAttributeName =[[properties objectForKey:@"taskAttributeName"] copy];
        
        // update the attributeOptions relationship
        [self updateAttributeOptionWithProperties:properties forTaskAttribute:insertTaskAttribute inManagedObjectContext:context];
        
        // Link to the new MzTaskAttribute object
        [taskType addTaskAttributesObject:insertTaskAttribute];
    }                                               
    
}


// Method updates, inserts and deletes MzTaskAttributeOption objects for a given MzTaskAttribute object
// based on passed properties dictionary
- (void) updateAttributeOptionWithProperties:(NSDictionary *)properties 
forTaskAttribute:(MzTaskAttribute *)taskAttribute inManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(properties != nil);
    assert(taskAttribute != nil);
    assert(taskAttribute.attributeOptions != nil);
    assert( [[properties objectForKey:@"attributeOptionId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"attributeOptionName"] isKindOfClass:[NSArray class]] );
    
    // check TaskType properties
    NSIndexSet *result;
    NSMutableSet *existingOption;
    NSArray *optionSet;
    NSIndexSet *optionToRemove;
    
    
    // Iterate over all the taskAttributes objects we are "related" to...again note that the
    // value for the key: attributeOptionName is an array of strings
    optionSet = [NSArray arrayWithArray:[properties objectForKey:@"attributeOptionName"]];
    if ([taskAttribute.attributeOptions count] > 0) {
        
        existingOption = [NSMutableSet set]; // attributeOptions we already own
        
        for (NSString *option in optionSet) { 
            
            result = [taskAttribute.attributeOptions indexesOfObjectsPassingTest:
                      ^(MzTaskAttributeOption *obj, NSUInteger idx, BOOL *stop) {
                          
                          // Look for a match between the new and old attributeOptions
                          
                          if ([obj.attributeOptionName isEqualToString:option]) {
                              
                              //found match
                              [existingOption addObject:option];
                              return YES;   
                              
                          } else {
                              return  NO;   // keep looking
                          }
                          
                      }];            
        }
        
        // Get the indexes of all the taskAttributeOptions that did not have a match above
        if ([result count] > 0) {
            
            optionToRemove = [taskAttribute.attributeOptions indexesOfObjectsPassingTest:
                              ^(MzTaskAttributeOption *obj, NSUInteger idx, BOOL *stop) {
                                  
                                  if ([result containsIndex:idx]) {
                                      return  NO;
                                  } else {
                                      return  YES;
                                  }
                              }];
        } else {
            
            // In this case none of our old attributeOption values are valid so we remove all of them
            optionToRemove = [taskAttribute.attributeOptions indexesOfObjectsPassingTest:
                              ^(MzTaskAttributeOption *obj, NSUInteger idx, BOOL *stop) {
                                  
                                  if (obj) {
                                      return  YES;  // get all indexes in the set
                                  } else {
                                      return  NO;
                                  }
                              }];

        }
        
        // Remove the taskAttributeOptions that did not match either scenario above
        if ([optionToRemove firstIndex] != NSNotFound) {
            [taskAttribute removeAttributeOptionsAtIndexes:optionToRemove];
        }
        
        // Now we can add the new attributeOption values that we did not already have
        if ([existingOption count] > 0) {
            
            NSMutableArray *attributeArray;
            attributeArray = [NSMutableArray array];
            assert(attributeArray != nil);
            NSOrderedSet *attributeSet;
            
            for (NSString *option in optionSet) {
                
                if ([existingOption member:option] == nil) {
                    
                    // add the MzTaskAttributeOption object relationship
                    MzTaskAttributeOption *insertAttributeOption = (MzTaskAttributeOption *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttributeOption" inManagedObjectContext:context];
                    assert(insertAttributeOption != nil);
                    assert([insertAttributeOption isKindOfClass:[MzTaskAttributeOption class]]);
                    
                    insertAttributeOption.attributeOptionId = [[properties objectForKey:@"taskAttributeId"] copy];
                    insertAttributeOption.attributeOptionName = option;
                    insertAttributeOption.taskAttribute = taskAttribute;
                    assert(insertAttributeOption.taskAttribute != nil);
                    
                    // Link to the passed MzTaskAttribute object
                    [attributeArray addObject:insertAttributeOption];
                }
            }
            // Link to the passed MzTaskAttribute object
            attributeSet = [NSOrderedSet orderedSetWithArray:attributeArray];
            assert(attributeSet != nil);
            [taskAttribute addAttributeOptions:attributeSet];
            
        } else {
            
            // None of the new attributeOption values match any of existing attributeOptions so we add all the new ones
            NSMutableArray *attributeArray;
            attributeArray = [NSMutableArray array];
            assert(attributeArray != nil);
            NSOrderedSet *attributeSet;
            
            for (NSString *option in optionSet) {
                                    
                    // add the MzTaskAttributeOption object relationship
                    MzTaskAttributeOption *insertAttribute = (MzTaskAttributeOption *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttributeOption" inManagedObjectContext:context];
                    assert(insertAttribute != nil);
                    assert([insertAttribute isKindOfClass:[MzTaskAttributeOption class]]);
                    
                    insertAttribute.attributeOptionId = [[properties objectForKey:@"taskAttributeId"] copy];
                    insertAttribute.attributeOptionName = option;
                    insertAttribute.taskAttribute = taskAttribute;
                    assert(insertAttribute.taskAttribute != nil);
                    
                    // Link to the passed MzTaskAttribute object
                [attributeArray addObject:insertAttribute];                
            }
            // Link to the passed MzTaskAttribute object
            attributeSet = [NSOrderedSet orderedSetWithArray:attributeArray];
            assert(attributeSet != nil);
            [taskAttribute addAttributeOptions:attributeSet];
        }        
                
    } else {
        
        // In this case, the taskAttribute object has no attributeOption objects so we add all of the new
        // attributeOptions being passed in
        NSMutableArray *attributeArray;
        attributeArray = [NSMutableArray array];
        assert(attributeArray != nil);
        NSOrderedSet *attributeSet;
        
        for (NSString *option in optionSet) {
            
            // add the MzTaskAttributeOption object relationship
            MzTaskAttributeOption *insertOption = (MzTaskAttributeOption *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttributeOption" inManagedObjectContext:context];
            assert(insertOption != nil);
            assert([insertOption isKindOfClass:[MzTaskAttributeOption class]]);
            
            insertOption.attributeOptionId = [[properties objectForKey:@"taskAttributeId"] copy];
            insertOption.attributeOptionName = option;
            insertOption.taskAttribute = taskAttribute;
            assert(insertOption.taskAttribute != nil);
                       
            [attributeArray addObject:insertOption];                
        }
        
         // Link to the passed MzTaskAttribute object
        attributeSet = [NSOrderedSet orderedSetWithArray:attributeArray];
        assert(attributeSet != nil);
        [taskAttribute addAttributeOptions:attributeSet];
        
    }   
}                                    
                                
// Helper method that works around Apple's Bug when you use the add<Key>Object: method on an NSOrderedSet
// to-many relationship property generated automatically by CoreData....that method crashes with a [NSSet intersectsSet:]: error
-(NSUInteger)indexToInsert
{
    assert(self.taskTypes != nil);
    NSIndexSet *indexSet;
    
    indexSet = [self.taskTypes indexesOfObjectsPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
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
