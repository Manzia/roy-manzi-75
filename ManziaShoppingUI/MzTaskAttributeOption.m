//
//  MzTaskAttributeOption.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/8/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskAttributeOption.h"
#import "MzTaskAttribute.h"
#import "Logging.h"


@implementation MzTaskAttributeOption

@dynamic attributeOptionId;
@dynamic attributeOptionName;
@dynamic taskAttribute;

// Override for debugging purposes
-(void)prepareForDeletion
{
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Will delete TaskAttributeOption with name: %@", self.attributeOptionName]; 
}


@end
