//
//  MzTaskType.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/8/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskAttribute, MzTaskCategory, MzTaskTypeImage;

@interface MzTaskType : NSManagedObject

@property (nonatomic, retain) NSString * taskTypeId;
@property (nonatomic, retain) NSString * taskTypeImageURL;
@property (nonatomic, retain) NSString * taskTypeName;
@property (nonatomic, retain) NSSet *taskAttributes;
@property (nonatomic, retain) MzTaskCategory *taskCategory;
@property (nonatomic, retain) MzTaskTypeImage *taskTypeImage;

// Thumbnail Update
-(void)updateTaskTypeThumbnail;
-(void)prepareForDeletion;

@end

@interface MzTaskType (CoreDataGeneratedAccessors)

- (void)addTaskAttributesObject:(MzTaskAttribute *)value;
- (void)removeTaskAttributesObject:(MzTaskAttribute *)value;
- (void)addTaskAttributes:(NSSet *)values;
- (void)removeTaskAttributes:(NSSet *)values;

@end
