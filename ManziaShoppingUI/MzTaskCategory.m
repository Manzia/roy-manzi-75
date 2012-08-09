//
//  MzTaskCategory.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/8/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskCategory.h"
#import "MzTaskType.h"
#import "MzTaskAttribute.h"
#import "MzTaskAttributeOption.h"
#import "Logging.h"


@interface MzTaskCategory ()

-(void)updateTaskCategoryThumbnail;

@end

@implementation MzTaskCategory

@dynamic categoryId;
@dynamic categoryImageURL;
@dynamic categoryName;
@dynamic taskTypes;

#pragma mark * Insert & Update Task Category
// Creates a MzProductItem object with the specified properties in the specified context. 
// The properties dictionary is keyed by property names, in a KVC fashion.

+ (MzTaskCategory *)insertNewMzTaskCategoryWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    MzTaskCategory *insertCategory;
    MzTaskType *insertTaskType;
    MzTaskAttribute *insertTaskAttribute;
    MzTaskAttributeOption *insertAttributeOption;
    
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
            
                       
            for (NSString *options in attributeOptions ) {
                insertAttributeOption = (MzTaskAttributeOption *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttributeOption" inManagedObjectContext:managedObjectContext];
                assert(insertAttributeOption != nil);
                assert([insertAttributeOption isKindOfClass:[MzTaskAttributeOption class]]);
                
                // attributeOptionId value is same as taskAttributeId value
                insertAttributeOption.attributeOptionId = [[properties objectForKey:@"taskAttributeId"] copy];
                insertAttributeOption.attributeOptionName = options;
                                
                // Link to the MzTaskAttribute
                [insertTaskAttribute addAttributeOptionsObject:insertAttributeOption];
               
            }                       
            
        } else {
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Task Attribute: %@ for Task Category: %@ with Task Type: %@ has no attributeOptions", [properties objectForKey:@"taskAttributeName"], [properties objectForKey:@"categoryName"], [properties objectForKey:@"taskTypeName"]];
        }
        
        // Link to the MzTaskType
        [insertTaskType addTaskAttributesObject:insertTaskAttribute];
        
        
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
    NSSet *result;
    BOOL taskTypeThumbnailNeedsUpdate;
    
    taskTypeThumbnailNeedsUpdate = NO;
    
    // Iterate over all the taskType objects we are "related" to
    if ([self.taskTypes count] > 0) {
        result = [self.taskTypes objectsPassingTest:
                  ^(MzTaskType *obj, BOOL *stop) {
                      if ([obj.taskTypeId isEqualToString:[properties objectForKey:@"taskTypeId"]]) {
                          *stop =YES;
                          return YES;   // found a match...stop
                      } else {
                          return  NO;   // keep looking
                      }    
                  }];
        if ([result count] == 1) {
            
            //Note that we may repeatedly keep on doing the same updates, we can come with
            // some logic to keep track of which taskTypeId's we've seen before but the
            // time & memory savings are negligible so we just crunch away...
            // NOTE: The result Set has only one object so we can safely use the anyObject: method
            updateTaskType = [result anyObject];
            assert(updateTaskType != nil);
            
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
            //[MzQueryItem updateMzQueryItemsForTaskType:updateTaskType inManagedObjectContext:context];
            
        } else if ([result count] == 0) {
            
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
            //[MzQueryItem updateMzQueryItemsForTaskType:insertTaskType inManagedObjectContext:context];
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
        //[MzQueryItem updateMzQueryItemsForTaskType:insertTaskType inManagedObjectContext:context];
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
    NSSet *result;
    
    // Iterate over all the taskAttributes objects we are "related" to
    if ([taskType.taskAttributes count] > 0) {
        result = [taskType.taskAttributes objectsPassingTest:
                  ^(MzTaskAttribute *obj, BOOL *stop) {
                      if ([obj.taskAttributeId isEqualToString:[properties objectForKey:@"taskAttributeId"]]) {
                          *stop =YES;
                          return YES;   // found a match...stop
                      } else {
                          return  NO;   // keep looking
                      }    
                  }];
        if ([result count] == 1) {
            
            // We expect to get one and only one result since there can be no duplicate taskAttributeIds
            updateTaskAttribute = [result anyObject];
            
            if (![updateTaskAttribute.taskAttributeName isEqualToString:[properties objectForKey:@"taskAttributeName"]]) {
                updateTaskAttribute.taskAttributeName = [[properties objectForKey:@"taskAttributeName"] copy];
            }
            
            // update the attributeOptions relationship
            [self updateAttributeOptionWithProperties:properties forTaskAttribute:updateTaskAttribute inManagedObjectContext:context];
            
        } else if ([result count] == 0) {
            
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
    
    // Note that the value of the "attributeOptionName" key in parserResults is an array of strings
    assert( [[properties objectForKey:@"attributeOptionName"] isKindOfClass:[NSArray class]] );
    
    // check TaskType properties
    NSArray *optionSet;
    MzTaskAttributeOption *insertAttributeOption;
    NSMutableDictionary *optionDict;
    NSMutableSet *dictKeys;
    
    // Iterate over all the taskAttributes objects we are "related" to...again note that the
    // value for the key: attributeOptionName is an array of strings
    optionSet = [NSArray arrayWithArray:[properties objectForKey:@"attributeOptionName"]];
    assert(optionSet != nil);
    
    // Note that we either delete or insert attributeOptions, it doesn't make sense to do an update
    // We create a dictionary with keys are attributeOptionName and the values are
    // MzTaskAttributeOption objects
    optionDict = [NSMutableDictionary dictionary];
    assert(optionDict != nil);
    
    if ([taskAttribute.attributeOptions count] > 0) {
        
        // we have existing attributeOptions so create the dictionary
        [taskAttribute.attributeOptions enumerateObjectsUsingBlock:^
         (MzTaskAttributeOption *options, BOOL *stop) {
             [optionDict setObject:options forKey:options.attributeOptionName];
         }];
        
        // Create the set of all dictionary keys
        dictKeys = [NSMutableSet setWithArray:[optionDict allKeys]];
        
        // Do inserts and deletes
        for (NSString *optionName in optionSet) {
            
            if ([optionDict objectForKey:optionName] == nil) {
                
                // we don't have this taskAttibuteOption so we insert
               insertAttributeOption = (MzTaskAttributeOption *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttributeOption" inManagedObjectContext:context];
                assert(insertAttributeOption != nil);
                assert([insertAttributeOption isKindOfClass:[MzTaskAttributeOption class]]);
                
                insertAttributeOption.attributeOptionId = [[properties objectForKey:@"taskAttributeId"] copy];
                insertAttributeOption.attributeOptionName = optionName;
                
                 // add the MzTaskAttributeOption object relationship
                [taskAttribute addAttributeOptionsObject:insertAttributeOption];
            } else {
                
                // we have this taskAttributeOption so we remove it so we don't delete it
                [dictKeys removeObject:optionName];
            }
        }
        
        // we can now do all the deletes
        [taskAttribute removeAttributeOptions:dictKeys];        
        
    } else {
        
        // we do not have any attributeOptions so we create a new one
        for (NSString *options in optionSet) {
            
            insertAttributeOption = (MzTaskAttributeOption *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttributeOption" inManagedObjectContext:context];
            assert(insertAttributeOption != nil);
            assert([insertAttributeOption isKindOfClass:[MzTaskAttributeOption class]]);
            
            insertAttributeOption.attributeOptionId = [[properties objectForKey:@"taskAttributeId"] copy];
            insertAttributeOption.attributeOptionName = [options copy];
            
            // add the MzTaskAttributeOption object relationship
            [taskAttribute addAttributeOptionsObject:insertAttributeOption];

        }
    }    
    
}                                    





@end
