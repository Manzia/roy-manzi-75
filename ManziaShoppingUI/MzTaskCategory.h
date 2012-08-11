//
//  MzTaskCategory.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/8/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskType;

@interface MzTaskCategory : NSManagedObject

@property (nonatomic, retain) NSString * categoryId;
@property (nonatomic, retain) NSString * categoryImageURL;
@property (nonatomic, retain) NSString * categoryName;
@property (nonatomic, retain) NSSet *taskTypes;

// Creates a MzTaskCategory object with the specified properties in the specified context. 
// The properties dictionary is keyed by property names, in a KVC fashion.
+ (MzTaskCategory *)insertNewMzTaskCategoryWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

// Updates the MzTaskCategory object with the specified properties. 
- (void)updateWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)context;

-(void)prepareForDeletion;

@end

@interface MzTaskCategory (CoreDataGeneratedAccessors)

- (void)addTaskTypesObject:(MzTaskType *)value;
- (void)removeTaskTypesObject:(MzTaskType *)value;
- (void)addTaskTypes:(NSSet *)values;
- (void)removeTaskTypes:(NSSet *)values;

@end
