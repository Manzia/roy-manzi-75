//
//  MzQueryItem.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/8/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskType;

@interface MzQueryItem : NSManagedObject

@property (nonatomic, retain) NSString * queryId;
@property (nonatomic, retain) NSString * queryString;

// Insert, Update and Delete MzQueryItem objects
+(void)updateMzQueryItemsInManagedObjectContext:(NSManagedObjectContext *)context;

+(void)deleteAllQueryItemsForTaskType:(MzTaskType *)taskType 
               inManagedObjectContext:(NSManagedObjectContext *) context;


@end
