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


@end
