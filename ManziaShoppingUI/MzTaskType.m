//
//  MzTaskType.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/8/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskType.h"
#import "MzTaskAttribute.h"
#import "MzTaskCategory.h"
#import "MzTaskTypeImage.h"
#import "Logging.h"


@implementation MzTaskType

@dynamic taskTypeId;
@dynamic taskTypeImageURL;
@dynamic taskTypeName;
@dynamic taskAttributes;
@dynamic taskCategory;
@dynamic taskTypeImage;

// Override for debugging purposes
-(void)prepareForDeletion
{
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Will delete TaskType with name: %@", self.taskTypeName]; 
}

@end
