//
//  MzQueryItem.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/8/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzQueryItem.h"
#import "MzTaskAttribute.h"
#import "MzTaskAttributeOption.h"
#import "MzTaskType.h"
#import "Logging.h"

@implementation MzQueryItem

@dynamic queryId;
@dynamic queryString;

// Insert a new MzQueryItem object into the database - this class method would
// apply only if we are inserting a new MzTaskType with a "brand" MzTaskAttribute
+(void)insertNewMzQueryItemsForTaskAttribute:(MzTaskAttribute *)taskAttribute inManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(taskAttribute != nil);
    assert(context != nil);
    
    // Use "brand" + "taskType" to create query String
    if ([taskAttribute.taskAttributeName isEqualToString:@"Brand"]) {
        [taskAttribute.attributeOptions enumerateObjectsUsingBlock:^(MzTaskAttributeOption *obj, BOOL *stop) {
            
            // Create a new MzQueryItem object in database
            MzQueryItem *queryItem = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
            assert(queryItem != nil);
                           
            // Note we assign the taskTypeId for easy delete/update operations
            queryItem.queryId = taskAttribute.taskType.taskTypeId;
                
            // append with a whitespace in between
            queryItem.queryString = [obj.attributeOptionName stringByAppendingFormat:@" %@", taskAttribute.taskType.taskTypeName];           
            
        }];
        
    }    
    
}

// Update and or delete existing MzQueryItem objects
+(void)updateMzQueryItemsForTaskType:(MzTaskType *)taskType inManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(taskType != nil);
    assert(context != nil);
    
    // Before we start doing any work, let's ensure the passed in taskType has a taskAttribute
    // whose value (taskAttributeName) is "brand"
    NSSet *result;
    result = [taskType.taskAttributes objectsPassingTest:
              ^(MzTaskAttribute *obj, BOOL *stop) {
        
        if ([obj.taskAttributeName isEqualToString:@"Brand"]) {
            *stop = YES;
            return YES;
        } else {
            return  NO;
        }
    }];
    
    /* exit if no "brand" taskAttribute to save time and resources
     NOTE: even though we return/exit now, we will eventually be able to create the MzQueryItems
     for the "brand" taskAttribute for this taskType because we will be called again eventually
     with the same taskType when it has been associated with a "brand" taskAttribute
     since ALL taskTypes after a complete MzTaskCollection sync will have a "brand" taskAttribute */
    
    if ([result count] == 0) return;     
    
    /* Start the update, delete, insert logic...
     1- Create a dictionary whose keys are all the attributeOptionNames associated with this "brand"
     taskAttribute and whose values are the corresponding MzQueryItem objects in the database
     2- create an array with all the attributeOptionNames associated with the input TaskType
     3- create a set with all the keys of the dictionary in step 1
     4- For each attributeOptionName in the array from step 2
     a- if there is a matching key in the dictionary, keep that MzQueryItem object, remove that key
     from the array in step 3
     b- if there is no matching key in the dictionary, create a new MzQueryItem object
     5- remove all the MzQueryItem objects whose keys match those still remaining in the array from step 3
     */
    
    NSArray *existingQueryItems;
    NSError *fetchError = NULL;
    NSMutableDictionary *queryDictionary;
    NSMutableArray *optionNames;
    NSMutableSet *queryToRemove;
    MzTaskAttribute *tempTaskAttribute;
    
    // Create the array of attributeOptionNames associated with incoming MzTaskType object
    if ([result count] == 1) {
        tempTaskAttribute = [result anyObject];
        assert(tempTaskAttribute != nil);
        optionNames = [NSMutableArray array];
        assert(optionNames != nil);
        
        // Iterate
        [tempTaskAttribute.attributeOptions enumerateObjectsUsingBlock:
         ^(MzTaskAttributeOption *option, BOOL *stop) {
             
             [optionNames addObject:option.attributeOptionName];
         }];
    } else {
        
        // Log unexpected result
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Unexpected result - TaskType: %@ has more than one Brand TaskAttribute", taskType.taskTypeName];
        return;
    } 
    
    
    // Get the existing MzQueryItems
    NSFetchRequest *fetchRequest;    
    fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"MzQueryItem"];
    assert(fetchRequest != nil);
    NSPredicate *queryPredicate = [NSPredicate predicateWithFormat:@"queryId == %@", taskType.taskTypeId];
    assert(queryPredicate != nil);
    [fetchRequest setPredicate:queryPredicate];
    existingQueryItems = [context executeFetchRequest:fetchRequest error:&fetchError];
    
    // Log error
    if (fetchError) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Error fetching from MzQueryItem entity for TaskType: %@ with error: %@", taskType.taskTypeName, fetchError.localizedDescription]; 
    }
    
    // We can do the updates since we have existing MzQueryItem objects
    if (existingQueryItems != nil && [existingQueryItems count] > 0) {
        queryDictionary = [NSMutableDictionary dictionary];
        
        //Iterate to create the queryItem dictionary
        for (MzQueryItem *itemQuery in existingQueryItems) {
            [queryDictionary setObject:itemQuery forKey:itemQuery.queryString];
        }
        
        // create the array of keys
        queryToRemove = [NSMutableSet setWithArray:[queryDictionary allKeys]];
        assert(queryToRemove != nil);
        NSUInteger updateItems = 0;
        NSString *keyString;        // keys are of format "brand" + space + "taskTypeName"
        
        // Do the update, insert...
        for (NSString *name in optionNames) {
            
            // check if we already have this attributeOptionName
            keyString = [name stringByAppendingFormat:@" %@", taskType.taskTypeName];            
            
            if( [queryDictionary objectForKey:keyString] != nil ) {
                
                [queryToRemove removeObject:name];  // remaining items will be deleted
            } else {
                
                // we need to insert a new MzQueryItem for this attributeOptionName
                updateItems++;
                MzQueryItem *queryItem = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
                
                if (queryItem != nil) {
                    //assert([[[queryItem entity] managedObjectClassName ] isEqualToString:@"MzQueryItem"] );
                    
                    // Note we assign the taskTypeId for easy delete/update operations
                    queryItem.queryId = taskType.taskTypeId;
                    queryItem.queryString = [name stringByAppendingFormat:@" %@", taskType.taskTypeName]; 
                }
                
            }
        }
        
        // Log
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Inserted %d MzQueryItems for TaskType: %@", updateItems, taskType.taskTypeName];
        
        // Now we do the delete....
        if ([queryToRemove count] > 0) {
            
            [queryToRemove enumerateObjectsUsingBlock:^(NSString *query, BOOL *stop) {
                
                [context deleteObject:[queryDictionary objectForKey:query]];
            }];
            
            // Log
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:
             @"Deleted %d MzQueryItems for TaskType: %@", [queryToRemove count] ,taskType.taskTypeName];
        }
        
    } else if (existingQueryItems != nil) {
        
        // we need to insert new MzQueryItems for all the attributeOptionNames
        // we insert only for the "brand" MzTaskAttribute
        NSUInteger insertItems = [tempTaskAttribute.attributeOptions count];
        [MzQueryItem insertNewMzQueryItemsForTaskAttribute:tempTaskAttribute inManagedObjectContext:context];
        
        // We also insert a MzQueryItem where we do not append the brand
        MzQueryItem *queryItem = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
        
        if (queryItem != nil) {
            //assert([[[queryItem entity] managedObjectClassName ] isEqualToString:@"MzQueryItem"] );
            
            // Note we assign the taskTypeId for easy delete/update operations
            queryItem.queryId = taskType.taskTypeId;
            queryItem.queryString = taskType.taskTypeName;
            
            // Log
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:
             @"Inserted %d MzQueryItems for TaskType: %@", insertItems + 1, taskType.taskTypeName];
        }        
        
    }
    
}

// Delete all the MzQueryItems associated with a TaskType
+(void)deleteAllQueryItemsForTaskType:(MzTaskType *)taskType inManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(taskType != nil);
    assert(context != nil);
    
    NSError *fetchError = NULL;
    NSArray *existingQueryItems;
    
    // Get the existing MzQueryItems
    NSFetchRequest *fetchRequest;    
    fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"MzQueryItem"];
    assert(fetchRequest != nil);
    NSPredicate *queryPredicate = [NSPredicate predicateWithFormat:@"queryId == %@", taskType.taskTypeId];
    assert(queryPredicate != nil);
    [fetchRequest setPredicate:queryPredicate];
    existingQueryItems = [context executeFetchRequest:fetchRequest error:&fetchError];
    
    // Log error
    if (fetchError) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Error fetching from MzQueryItem entity to Delete for TaskType: %@ with error: %@", taskType.taskTypeName, fetchError.localizedDescription]; 
    }
    
    if (existingQueryItems != nil && [existingQueryItems count] > 0) {
        NSUInteger deleteCount = [existingQueryItems count];
        for (MzQueryItem *item in existingQueryItems) {
            [context deleteObject:item];
        }
        
        // Log
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Deleted %d MzQueryItems for TaskType: %@", deleteCount, taskType.taskTypeName];
    }
    
}




@end
