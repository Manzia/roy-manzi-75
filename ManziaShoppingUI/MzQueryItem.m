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

// Key for attributeOptionName value
static NSString *kAttributeNameKey = @"attributeName";

// Insert a new MzQueryItem object into the database - this class method would
// apply only if we are inserting a new MzTaskType with a "brand" MzTaskAttribute
+(void)insertNewMzQueryItemsForTaskAttribute:(MzTaskAttribute *)taskAttribute inManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(taskAttribute != nil);
    assert(context != nil);
    __block MzQueryItem *queryItem;
    
    // Use "brand" + "taskType" to create query String
    if ([[taskAttribute valueForKey:@"taskAttributeName"] isEqualToString:@"Brand"]) {
        [taskAttribute.attributeOptions enumerateObjectsUsingBlock:^(MzTaskAttributeOption *obj, BOOL *stop) {
            
            // Create a new MzQueryItem object in database
            queryItem = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
            assert(queryItem != nil);
                           
            // Note we assign the taskTypeId for easy delete/update operations
            queryItem.queryId = [taskAttribute valueForKeyPath:@"taskType.taskTypeId"];
            assert(queryItem.queryId != nil);
                          
            // append with a whitespace in between
            queryItem.queryString = [obj.attributeOptionName stringByAppendingFormat:@" %@", [taskAttribute valueForKeyPath:@"taskType.taskTypeName"]];                    
            
        }];
        
    }    
    
}

// Update and or delete existing MzQueryItem objects
+(void)updateMzQueryItemsInManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(context != nil);
    
    // Get all the attributeOptionName values in the MzTaskAttributeOption entity whose
    // taskAttribute.taskAttributeName value = "Brand"
    NSArray *retrievedOptions;
    NSError *fetchOptionError = NULL;
    NSArray *optionNames;
    NSMutableDictionary *optionsDict;
    
    
    NSFetchRequest *fetchOptions = [[NSFetchRequest alloc] initWithEntityName:@"MzTaskAttributeOption"];
    assert(fetchOptions != nil);
    [fetchOptions setFetchBatchSize:30];
    NSPredicate *predicateOption = [NSPredicate predicateWithFormat:@"ANY taskAttribute.taskAttributeName like 'Brand'"];
    [fetchOptions setPredicate:predicateOption];
    [fetchOptions setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"taskAttribute.taskType"]];
    retrievedOptions = [context executeFetchRequest:fetchOptions error:&fetchOptionError];
    assert(retrievedOptions != nil);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:
     @"Number of AttributeOptions for Brand Attribute in DB is: %d", [retrievedOptions count]];
    
    // Log error
    if (fetchOptionError) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Error fetching from MzTaskAttributeOption entity with error: %@", fetchOptionError.localizedDescription]; 
    }

    
    // Create the array and dictionary of attributeOptionNames
    if ([retrievedOptions count] > 0) {
        optionsDict = [NSMutableDictionary dictionary];
        assert(optionsDict != nil);
                
        for (MzTaskAttributeOption *option in retrievedOptions) {
            
            [optionsDict setObject:option forKey:option.attributeOptionName];            
        }
        optionNames = [optionsDict allKeys];
        
    } else {
        
        // Log unexpected result
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"No taskAttributeOption with a Brand TaskAttribute found"];
        
        return;     // nothing to do, take off!
    }
    
            
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
    NSMutableSet *queryToRemove;
    NSUInteger updateItems = 0;
    NSString *keyString;        // keys are of format "brand" + space + "taskTypeName"
    
    // Get the existing MzQueryItems
    NSFetchRequest *fetchRequest;    
    fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"MzQueryItem"];
    assert(fetchRequest != nil);
    [fetchRequest setFetchBatchSize:30];
    existingQueryItems = [context executeFetchRequest:fetchRequest error:&fetchError];
    
    // Log error
    if (fetchError) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Error fetching from MzQueryItem entity with error: %@", fetchError.localizedDescription]; 
    }
    
    // We can do the updates since we have existing MzQueryItem objects
    if (existingQueryItems != nil && [existingQueryItems count] > 0) {
        queryDictionary = [NSMutableDictionary dictionary];
        MzQueryItem *queryItem;
        
        //Iterate to create the queryItem dictionary
        for (MzQueryItem *itemQuery in existingQueryItems) {
            [queryDictionary setObject:itemQuery forKey:itemQuery.queryString];
        }
        
        // create the array of keys
        queryToRemove = [NSMutableSet setWithArray:[queryDictionary allKeys]];
        assert(queryToRemove != nil);
        
        
        // Do the update, insert...
        for (NSString *name in optionNames) {
            
            // check if we already have this attributeOptionName
            keyString = [name stringByAppendingFormat:[[optionsDict objectForKey:name] valueForKeyPath:@"taskAttribute.taskType.taskTypeName"]];             
            
            if( [queryDictionary objectForKey:keyString] != nil ) {
                
                [queryToRemove removeObject:name];  // remaining items will be deleted
            } else {
                
                // we need to insert a new MzQueryItem for this attributeOptionName
                updateItems++;
                queryItem = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
                
                if (queryItem != nil) {
                    //assert([[[queryItem entity] managedObjectClassName ] isEqualToString:@"MzQueryItem"] );
                    
                    // Note we assign the taskTypeId for easy delete/update operations
                    queryItem.queryId = [[optionsDict objectForKey:name] valueForKeyPath:@"taskAttribute.taskType.taskTypeId"];
                    
                    queryItem.queryString = [name stringByAppendingFormat:[[optionsDict objectForKey:name] valueForKeyPath:@"taskAttribute.taskType.taskTypeName"]]; 
                    
                }
                
            }
        }
        
        // Log
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Inserted %d MzQueryItems in database: ", updateItems];
        
        // Now we do the delete....
        if ([queryToRemove count] > 0) {
            
            [queryToRemove enumerateObjectsUsingBlock:^(NSString *query, BOOL *stop) {
                
                [context deleteObject:[queryDictionary objectForKey:query]];
            }];
            
            // Log
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:
             @"Deleted %d MzQueryItems from database: ", [queryToRemove count]];
        }
        
    } else if (existingQueryItems != nil) {
        
        // we need to insert new MzQueryItems for all the attributeOptionNames
        // we insert only for the "brand" MzTaskAttribute
        // Do the update, insert...
        MzQueryItem *itemQuery;
        NSUInteger insertItems = [optionNames count];
        for (NSString *name in optionNames) {
            
            // check if we already have this attributeOptionName
             keyString = [name stringByAppendingFormat:[[optionsDict objectForKey:name] valueForKeyPath:@"taskAttribute.taskType.taskTypeName"]];             
            
            if( [queryDictionary objectForKey:keyString] != nil ) {
                
                [queryToRemove removeObject:name];  // remaining items will be deleted
            } else {
                
                // we need to insert a new MzQueryItem for this attributeOptionName
                updateItems++;
                itemQuery = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
                
                if (itemQuery != nil) {
                    //assert([[[queryItem entity] managedObjectClassName ] isEqualToString:@"MzQueryItem"] );
                    
                    // Note we assign the taskTypeId for easy delete/update operations
                    itemQuery.queryId = [[optionsDict objectForKey:name] valueForKeyPath:@"taskAttribute.taskType.taskTypeId"];
                    
                    itemQuery.queryString = [name stringByAppendingFormat:[[optionsDict objectForKey:name] valueForKeyPath:@"taskAttribute.taskType.taskTypeId"]];                     
                }
                
            }
        }    
         // Log
         [[QLog log] logOption:kLogOptionSyncDetails withFormat:
          @"Initial insert of %d MzQueryItems in database", insertItems + 1];
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
    NSPredicate *queryPredicate = [NSPredicate predicateWithFormat:@"queryId like %@", taskType.taskTypeId];
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
         @"Finished deleting all %d MzQueryItems for TaskType: %@", deleteCount, taskType.taskTypeName];
    }
    
}




@end
