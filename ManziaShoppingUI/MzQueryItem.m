//
//  MzQueryItem.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/4/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzQueryItem.h"
#import "MzTaskType.h"
#import "MzTaskAttribute.h"
#import "MzTaskAttributeOption.h"
#import "Logging.h"


@implementation MzQueryItem

@dynamic queryString;
@dynamic queryId;

// Insert a new MzQueryItem object into the database - this class method would
// apply only if we are inserting a new MzTaskType with a "brand" MzTaskAttribute
+(void)insertNewMzQueryItemsForTaskAttribute:(MzTaskAttribute *)taskAttribute inManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(taskAttribute != nil);
    assert(context != nil);
                   
        // Use "brand" + "taskType" to create query String
        if ([taskAttribute.taskAttributeName isEqualToString:@"brand"]) {
            [taskAttribute.attributeOptions enumerateObjectsUsingBlock:^(MzTaskAttributeOption *obj, NSUInteger idx, BOOL *stop) {
                
                // Create a new MzQueryItem object in database
                MzQueryItem *queryItem = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
                
                if (queryItem != nil) {
                    assert([queryItem isKindOfClass:[MzQueryItem class]]);
                    
                    // Note we assign the taskTypeId for easy delete/update operations
                    queryItem.queryId = taskAttribute.taskType.taskTypeId;
                    
                    // append with a whitespace in between
                    queryItem.queryString = [obj.attributeOptionName stringByAppendingFormat:@" %@", taskAttribute.taskType.taskTypeName];
                }
                
            }];
            
            // Log
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:
             @"Inserted: %d MzQueryItems for TaskType: %@", [taskAttribute.attributeOptions count], taskAttribute.taskType.taskTypeName];     
        }    

}

// Update and or delete existing MzQueryItem objects
+(void)updateMzQueryItemsForTaskType:(MzTaskType *)taskType inManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(taskType != nil);
    assert(context != nil);
    
    // Before we start doing any work, let's ensure the passed in taskType has a taskAttribute
    // whose value (taskAttributeName) is "brand"
    NSIndexSet *result;
    result = [taskType.taskAttributes indexesOfObjectsPassingTest:^(MzTaskAttribute *obj, NSUInteger idx, BOOL *stop) {
        
        if ([obj.taskAttributeName isEqualToString:@"brand"]) {
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
     since ALL taskTypes after a complete MzTaskCollection sync will have this taskAttribute */
    
    if ([result firstIndex] == NSNotFound) return;     
    
    // Start the update, delete, insert logic...
    
    NSMutableArray *queryToKeep;      //array of existing MzQueryItems to retain
    NSArray *existingQueryItems;
    NSError *fetchError = NULL;
    
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
    
    if (existingQueryItems != nil && [existingQueryItems count] > 0) {
        
        queryToKeep = [NSMutableArray array];
        assert(queryToKeep != nil);
                        
        // In this case, we update or delete accordingly so first we get all
        // the brands (MzTaskAttributeOption) associated with this MzTaskType
        assert(taskType.taskAttributes != nil);
        [taskType.taskAttributes enumerateObjectsUsingBlock:^(MzTaskAttribute *obj, NSUInteger idx, BOOL *stop) {
            
            if ([obj.taskAttributeName isEqualToString:@"brand"]) {
                
                // Iterate over the MzTaskAttributeOptions i.e brand values
                [obj.attributeOptions enumerateObjectsUsingBlock:
                 ^(MzTaskAttributeOption *option, NSUInteger idx, BOOL *stop) {
                     
                     for (MzQueryItem *item in existingQueryItems) {
                         if ([item.queryString hasPrefix:option.attributeOptionName]) {
                             
                             // we keep this MzQueryItem
                             [queryToKeep addObject:item];
                             break;
                         } else {
                             
                             // we need to insert this new brand (MzTaskAttributeOption) since
                             // we don't have it
                             MzQueryItem *queryItem = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
                                                          
                             if (queryItem != nil) {
                                 assert([queryItem isKindOfClass:[MzQueryItem class]]);
                                 
                                 // Note we assign the taskTypeId for easy delete/update operations
                                 queryItem.queryId = taskType.taskTypeId;
                                 queryItem.queryString = [option.attributeOptionName stringByAppendingFormat:@" %@", taskType.taskTypeName];
                                 
                                 // Log
                                 [[QLog log] logOption:kLogOptionSyncDetails withFormat:
                                  @"Inserted a MzQueryItem without a Brand for TaskType: %@", taskType.taskTypeName];
                             }
                         }
                    }
                 }];               
                    
            }
            
        }];
        
        // We can now delete those MzQueryItems that are in the existingQueryItems array but not
        // in the queryToKeep array
        NSSet *keepSet = [NSSet setWithArray:queryToKeep];
        NSUInteger count = 0;
        assert(keepSet != nil);
        for (MzQueryItem *items in existingQueryItems) { 
            
            if (![keepSet containsObject:items]) {   // Note, we are checking pointer values
                [context deleteObject:items];
                count++;
            }
        }
        
        // Log
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Deleted %d MzQueryItems for TaskType: %@", count++, taskType.taskTypeName];

        
    } else if (existingQueryItems != nil) {
        
        // This is likely a new MzTaskType we haven't seen before so we insert..
        assert(taskType.taskAttributes != nil);
        [taskType.taskAttributes enumerateObjectsUsingBlock:^(MzTaskAttribute *obj, NSUInteger idx, BOOL *stop) {
            
            // we insert only for the "brand" MzTaskAttribute
            [MzQueryItem insertNewMzQueryItemsForTaskAttribute:obj inManagedObjectContext:context];
        }];
        
        // Log
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Inserted %d MzQueryItems for TaskType: %@", [taskType.taskAttributes count] ,taskType.taskTypeName];

        
        // We also insert a MzQueryItem where we do not append the brand
        MzQueryItem *queryItem = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
        
        if (queryItem != nil) {
            assert([queryItem isKindOfClass:[MzQueryItem class]]);
            
            // Note we assign the taskTypeId for easy delete/update operations
            queryItem.queryId = taskType.taskTypeId;
            queryItem.queryString = taskType.taskTypeName;
            
            // Log
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:
             @"Inserted a MzQueryItem without brand for TaskType with TaskAttributes: %@", taskType.taskTypeName];
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
