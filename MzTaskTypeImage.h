//
//  MzTaskTypeImage.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskType;

@interface MzTaskTypeImage : NSManagedObject

@property (nonatomic, retain) NSData * taskTypeImageData;
@property (nonatomic, retain) NSString * taskTypeId;
@property (nonatomic, retain) MzTaskType *taskType;

@end
