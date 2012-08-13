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
static NSString *kAttributeBrand = @"Brand";

// Get all the existing MzQueryItems
+(NSArray *)getAllQueryItemsInManagedObjectContext:(NSManagedObjectContext *)context
{
    NSArray *existingQueryItems;
    NSError *fetchError = NULL;
        
    // Get the existing MzQueryItems
    NSFetchRequest *fetchRequest;    
    fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"MzQueryItem"];
    assert(fetchRequest != nil);
    existingQueryItems = [context executeFetchRequest:fetchRequest error:&fetchError];
    assert(existingQueryItems != nil);
    
    // Log error
    if (fetchError) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Error fetching from MzQueryItem entity with error: %@", fetchError.localizedDescription];
        return  nil;
        
    } else {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Number of existing QueryItems for Brand Attribute in DB is: %d", [existingQueryItems count]];
    }
    return existingQueryItems;
}

// Get all the existing MzTaskAttributes whose taskAttributeName = Brand
+(NSArray *)getBrandTaskAtrributesInManagedObjectContext:(NSManagedObjectContext *)context
{
    // Get all the MzTaskAttributes whose taskAttributeName value = "Brand"
    NSArray *retrievedAttributes;
    NSError *attributeError = NULL;    
    
    NSFetchRequest *fetchAttributes = [[NSFetchRequest alloc] initWithEntityName:@"MzTaskAttribute"];
    assert(fetchAttributes != nil);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"taskAttributeName like[c] %@", kAttributeBrand];
    [fetchAttributes setPredicate:predicate];
    [fetchAttributes setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObjects:@"taskType", @"attributeOptions", nil]];
    retrievedAttributes = [context executeFetchRequest:fetchAttributes error:&attributeError];
    assert(retrievedAttributes != nil);
    
    // Log error
    if (attributeError) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Error fetching from MzTaskAttribute entity to create MzQueryItems with error: %@", attributeError.localizedDescription];
        return nil;
        
    } else {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Number of Brand TaskAttributes in DB is: %d", [retrievedAttributes count]];
    }
    
   return retrievedAttributes;

}

// For some strange reason, maybe an IOS bug!!!, you cannot use the dynamic accessors or
// KVC to traverse a one-to-one relationship whose inverse is to-many relationship. When we
// retrieve the MzTaskAttribute objects above, we can access the attributeOptions relationship
// which is to-many but its inverse taskType relationship which is one-to-one returns nil
// even though it has a non-nil value in the persistent store/MOC and its not a fault.


// Update and or delete existing MzQueryItem objects
+(void)updateMzQueryItemsInManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(context != nil);
    NSArray *retrievedAttributes;
    NSArray *retrievedQuery;
               
    retrievedAttributes = [MzQueryItem getBrandTaskAtrributesInManagedObjectContext:context];
    assert(retrievedAttributes != nil);
    retrievedQuery = [MzQueryItem getAllQueryItemsInManagedObjectContext:context];
    assert(retrievedQuery != nil);
        
    // Insert, update, delete
    if ([retrievedAttributes count] > 0) {
        
        if ([retrievedQuery count] > 0) {
            
            // We could check each TaskAttribute in the retrievedAttributes array and compare
            // each attributeOptionName value in its atrributeOptions set to the queryString
            // value of the MzQueryItem and then decide to keep to keep or delete or insert but
            // the amount of time and effort is almost the same as just deleting all the items
            // in the MzQueryItem entity and doing a fresh insert....which is what we opt to do
            // since in both cases we still need to traverse through all the MzQueryItems
            for (MzQueryItem *item in retrievedQuery) {
                [context deleteObject:item];
            }
            
            //Log
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:
             @"Deleted %d MzQueryItems in database for Refresh", [retrievedQuery count]];
            
        } 
        // we now insert new MzQueryItems for all the "brand" MzTaskAttributes
        // Do the update, insert...
        __block MzQueryItem *itemQuery;
        __block NSString *preString;
        NSString *postString;
        __block NSUInteger count = 0;
        for (MzTaskAttribute *attribute in retrievedAttributes) {
            
            assert(attribute != nil);
            assert([attribute hasFaultForRelationshipNamed:@"taskType"] == NO);
            assert(attribute.attributeOptions != nil);
            assert(attribute.taskType != nil);
            postString = attribute.taskType.taskTypeName;
            
            //iterate to get each MzTaskAttributeOption object
            [attribute.attributeOptions enumerateObjectsUsingBlock:
             ^(MzTaskAttributeOption *option, BOOL *stop) {
                                  
                 // create the MzQueryItems
                 itemQuery = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
                 assert(itemQuery != nil);
                 preString = option.attributeOptionName;
                                  
                 // set the values where the queryString has the format:
                 // "brand" + "taskTypeName" e.g HP Printer
                 itemQuery.queryId = [attribute.taskType.taskTypeId copy];
                 itemQuery.queryString = [preString stringByAppendingFormat:@" %@", postString];
                 count++;
             }];
            
            // Also create a plain MzQueryItem without the "brand" prefix in the queryString
            // create the MzQueryItems
            itemQuery = (MzQueryItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzQueryItem" inManagedObjectContext:context];
            assert(itemQuery != nil);
            itemQuery.queryId = [attribute.taskType.taskTypeId copy];
            itemQuery.queryString = [postString copy];
        }
        
        //Log
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Inserted %d new MzQueryItems in database after Refresh", count + [retrievedAttributes count]];
        
    } else {
        // Log unexpected result
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"No Brand TaskAttribute found"];
        
        return;     // nothing to do, take off!
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
