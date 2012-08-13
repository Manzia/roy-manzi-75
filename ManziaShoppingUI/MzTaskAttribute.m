//
//  MzTaskAttribute.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/8/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskAttribute.h"
#import "MzTaskAttributeOption.h"
#import "MzTaskType.h"
#import "Logging.h"


@implementation MzTaskAttribute

@dynamic taskAttributeId;
@dynamic taskAttributeName;
@dynamic attributeOptions;
@dynamic taskType;

// Override for debugging purposes
-(void)prepareForDeletion
{
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Will delete TaskAttribute with name: %@", self.taskAttributeName]; 
}

// For some strange reason, maybe an IOS bug!!!, you cannot use the dynamic accessors or
// KVC to traverse a one-to-one relationship whose inverse is to-many relationship. When we
// retrieve the MzTaskAttribute objects, we can access the attributeOptions relationship
// which is to-many but its inverse taskType relationship which is one-to-one returns nil
// even though it has a non-nil value in the persistent store/MOC and its not a fault.
/*-(MzTaskType *)getTaskTypeForTaskAttribute:(MzTaskAttribute *)attribute inManagedObjectContext:(NSManagedObjectContext *)context
{
    assert(attribute != nil);
    assert(context != nil);
    NSArray *taskArray;
    NSError *taskError = NULL;
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"MzTaskType"];
    assert(request != nil);
    [request setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"taskAttributes"]];
    
    // Iterate through all the TaskTypes to see which one has the TaskAttribute
    taskArray = [context executeFetchRequest:request error:&taskError];
    
    // Log error
    if (taskError) {
        [[QLog log] logOption:kLogOptionSyncDetails withFormat:
         @"Error fetching from MzTaskType entity to get MzTaskAttribute with error: %@", taskError.localizedDescription];
        return nil;        
    }
    
}*/


@end
