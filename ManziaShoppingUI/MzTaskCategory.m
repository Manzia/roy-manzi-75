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

// Override for debugging purposes
-(void)prepareForDeletion
{
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Will delete TaskCategory with name: %@", self.categoryName]; 
}

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
        //insertTaskType.taskCategory = insertCategory;
        
        // add the MzTaskAttribute object relationship
        insertTaskAttribute = (MzTaskAttribute *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttribute" inManagedObjectContext:managedObjectContext];
        assert(insertTaskAttribute != nil);
        assert([insertTaskAttribute isKindOfClass:[MzTaskAttribute class]]);
        
        insertTaskAttribute.taskAttributeId = [[properties objectForKey:@"taskAttributeId"] copy];
        insertTaskAttribute.taskAttributeName = [[properties objectForKey:@"taskAttributeName"] copy];
        //insertTaskAttribute.taskType = insertTaskType;
        
        // add the MzTaskAttributeOption object relationship
        /* NOTE THAT ITS IMPORTANT TO KEEP THE FOLLOWING DISTINCTION
         The value for the  key "attributeOptionName" passed in from the parse results is an
         NSArray of strings each of which represents an MzTaskAttributeOption managed object i.e
         the string is assigned to "attributeOptionName" property of  each 
         MzTaskAttributeOption managed object created.         
         */
        NSArray *attributeOptions;
        NSMutableSet *optionsSet;
        attributeOptions = [NSArray arrayWithArray:[properties objectForKey:@"attributeOptionName"]];
        assert(attributeOptions != nil);
        optionsSet = [NSMutableSet set];
        assert(optionsSet != nil);
        
        if ([attributeOptions count] > 0) {
            
                       
            for (NSString *options in attributeOptions ) {
                insertAttributeOption = (MzTaskAttributeOption *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttributeOption" inManagedObjectContext:managedObjectContext];
                assert(insertAttributeOption != nil);
                assert([insertAttributeOption isKindOfClass:[MzTaskAttributeOption class]]);
                
                // attributeOptionId value is same as taskAttributeId value
                insertAttributeOption.attributeOptionId = [[properties objectForKey:@"taskAttributeId"] copy];
                insertAttributeOption.attributeOptionName = options;
                //insertAttributeOption.taskAttribute = insertTaskAttribute;
                                
                // Link to the MzTaskAttribute
                [optionsSet addObject:insertAttributeOption];                
               
            } 
            // Link to the MzTaskAttribute
            insertTaskAttribute.attributeOptions = [NSSet setWithSet:optionsSet];
            //[insertTaskAttribute addAttributeOptions:optionsSet];
            
        } else {
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Task Attribute: %@ for Task Category: %@ with Task Type: %@ has no attributeOptions", [properties objectForKey:@"taskAttributeName"], [properties objectForKey:@"categoryName"], [properties objectForKey:@"taskTypeName"]];
        }
        
        // Link to the MzTaskType
        insertTaskType.taskAttributes = [NSSet setWithObject:insertTaskAttribute];
        //[insertTaskType addTaskAttributes:[NSSet setWithObject:insertTaskAttribute]];
                
        
        // Link to the MzTaskCategory
        insertCategory.taskTypes = [NSSet setWithObject:insertTaskType];
        //[insertCategory addTaskTypes:[NSSet setWithObject:insertTaskType]];              
        
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
                
        // categoryId has no valid taskType values
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Update existing TaskCategory with categoryId: %@",[properties objectForKey:@"categoryId"]]; 
    }        
    
    // Do the thmbnail updates.
    if (categoryThumbnailNeedsUpdate) {
        [self updateTaskCategoryThumbnail];
    }    
    
}

// Define all the NSFetchRequest methods
-(NSFetchRequest *)taskTypesFetchWithTaskCategoryId:(NSString *)taskId
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"MzTaskType"];
    assert(request != nil);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ANY taskCategory.categoryId like[c] %@", taskId];
    [request setPredicate:predicate];
    [request setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"taskAttributes"]];
    
    return request;
}

-(NSFetchRequest *)taskAttributesFetch
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"MzTaskAttribute"];
    assert(request != nil);
    [request setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"attributeOptions"]];
    return request;
}

-(NSFetchRequest *)taskAttributeOptionsFetchforTaskAttributeId:(NSString *)attributeId
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"MzTaskAttributeOption"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"attributeOptionId like %@", attributeId];
    assert(predicate != nil);
    [request setPredicate:predicate];    
    assert(request != nil);
    return request;
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
    
    /* Testing code
    NSArray *retrievedTasks;
    NSError *tasksError;
    
    retrievedTasks = [context executeFetchRequest:[self taskTypesFetchWithTaskCategoryId:self.categoryId] error:&tasksError];
    assert(retrievedTasks != nil);
    NSUInteger taskCount = [retrievedTasks count]; */
    
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
            //insertTaskType.taskCategory = self;
            
            // update the taskAttributes relationship
            [self updateTaskAttributeWithProperties:properties forTaskType:insertTaskType inManagedObjectContext:context];
            
            // Add to the To-Many relationship
            [self addTaskTypesObject:insertTaskType];
            //[self addTaskTypes:[NSSet setWithObject:insertTaskType]];
                        
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
        //insertTaskType.taskCategory = self;
                
        // update the taskAttributes relationship
        [self updateTaskAttributeWithProperties:properties forTaskType:insertTaskType 
                         inManagedObjectContext:context];
        
        // Add to the To-Many relationship
        self.taskTypes = [NSSet setWithObject:insertTaskType];
        //[self addTaskTypes:[NSSet setWithObject:insertTaskType]];
                
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
    NSSet *tasks;
    NSArray *fetchArray;
    NSError *error = NULL;
    
    // Iterate over all the taskAttributes objects we are "related" to
    // Get all the taskAttribute objects - this looks like overkill since we are calling this
    // fetchRequest for every NSDictionary in the parserResults but its more efficient to do this
    // fetch from the database once and have all the objects cached by Core Data rather than try
    // to repeatedly retrieve only those taskAttribute objects we need each time this method is
    // called potentially requiring a database trip with every method call
    fetchArray = [context executeFetchRequest:[self taskAttributesFetch] error:&error];
    assert(fetchArray != nil);
    
    if (error) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Error retrieving MzTaskAttribute objects with error: %@", error.localizedDescription];
        return;
    }
        
    tasks = [NSSet setWithArray:fetchArray];    // ensure no duplicates
    assert(tasks != nil);
    
    /* Test
    NSString *test = [[[tasks anyObject] entity] name];
    NSLog(@"Class type for taskAttributes set: %@", test); */
    
    if ([tasks count] > 0) {        
        result = [tasks objectsPassingTest:
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
            //insertTaskAttribute.taskType = taskType;
            
            // update the attributeOptions relationship
            [self updateAttributeOptionWithProperties:properties forTaskAttribute:insertTaskAttribute inManagedObjectContext:context];
            
            // Link to the new MzTaskAttribute object
            [taskType addTaskAttributesObject:insertTaskAttribute];
            //[taskType addTaskAttributes:[NSSet setWithObject:insertTaskAttribute]];            
        }
        
    } else {
        
        // we have no taskAttribute objects linked to us so we add the new one
        insertTaskAttribute = (MzTaskAttribute *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttribute" inManagedObjectContext:context];
        assert(insertTaskAttribute != nil);
        assert([insertTaskAttribute isKindOfClass:[MzTaskAttribute class]]);
        
        insertTaskAttribute.taskAttributeId = [[properties objectForKey:@"taskAttributeId"] copy];
        insertTaskAttribute.taskAttributeName =[[properties objectForKey:@"taskAttributeName"] copy];
        insertTaskAttribute.taskType = taskType;
        
        // update the attributeOptions relationship
        [self updateAttributeOptionWithProperties:properties forTaskAttribute:insertTaskAttribute inManagedObjectContext:context];
        
        // Link to the new MzTaskAttribute object
        taskType.taskAttributes = [NSSet setWithObject:insertTaskAttribute];
        //[taskType addTaskAttributes:[NSSet setWithObject:insertTaskAttribute]];        
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
    NSSet *attributes;
    NSArray *fetchOptions;
    NSError *error = NULL;
    
    // Iterate over all the taskAttributes objects we are "related" to...again note that the
    // value for the key: attributeOptionName is an array of strings
    optionSet = [NSArray arrayWithArray:[properties objectForKey:@"attributeOptionName"]];
    assert(optionSet != nil);
    
    // Get all the attributeOptions objects - this looks like overkill since we are calling this
    // fetchRequest for every NSDictionary in the parserResults but its more efficient to do this
    // fetch from the database once and have all the objects cached by Core Data rather than try
    // to repeatedly retrieve only those attributeOptions objects we need each time this method is
    // called potentially requiring a database trip with every method call
    fetchOptions = [context executeFetchRequest:[self taskAttributeOptionsFetchforTaskAttributeId:taskAttribute.taskAttributeId] error:&error];
    assert(fetchOptions != nil);
    
    if (error) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Error retrieving MzTaskAttributeOption objects with error: %@", error.localizedDescription];
        return;
    }

    attributes = [NSSet setWithArray:fetchOptions];     //ensure no duplicates
    assert(attributes != nil);
    
    // Note that we either delete or insert attributeOptions, it doesn't make sense to do an update
    // We create a dictionary with keys are attributeOptionName and the values are
    // MzTaskAttributeOption objects
    optionDict = [NSMutableDictionary dictionary];
    assert(optionDict != nil);
    
    if ([attributes count] > 0) {
        
        // we have existing attributeOptions so create the dictionary
        [attributes enumerateObjectsUsingBlock:^
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
                //insertAttributeOption.taskAttribute = taskAttribute;
                
                 // add the MzTaskAttributeOption object relationship
                [taskAttribute addAttributeOptionsObject:insertAttributeOption];
            } else {
                
                // we have this taskAttributeOption so we remove it so we don't delete it
                [dictKeys removeObject:optionName];
            }
        }
        
        // we can now do all the deletes
        if ([dictKeys count] > 0) {
            [taskAttribute removeAttributeOptions:dictKeys];
        }
                
        
    } else {
        
        // we do not have any attributeOptions so we create a new one
        NSMutableSet *setOptions;
        setOptions = [NSMutableSet set];
        assert(setOptions != nil);
        
        for (NSString *options in optionSet) {
            
            insertAttributeOption = (MzTaskAttributeOption *) [NSEntityDescription insertNewObjectForEntityForName:@"MzTaskAttributeOption" inManagedObjectContext:context];
            assert(insertAttributeOption != nil);
            assert([insertAttributeOption isKindOfClass:[MzTaskAttributeOption class]]);
            
            insertAttributeOption.attributeOptionId = [[properties objectForKey:@"taskAttributeId"] copy];
            insertAttributeOption.attributeOptionName = [options copy];
            insertAttributeOption.taskAttribute = taskAttribute;
            
            // add the MzTaskAttributeOption object relationship
            [setOptions addObject:insertAttributeOption];            
        }
        // add the MzTaskAttributeOption object relationship
        taskAttribute.attributeOptions = [NSSet setWithSet:setOptions];
        //[taskAttribute addAttributeOptions:setOptions];
    }    
    
}                                    





@end
