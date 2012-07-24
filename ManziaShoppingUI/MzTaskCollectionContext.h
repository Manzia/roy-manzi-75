//
//  MzTaskCollectionContext.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 7/24/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface MzTaskCollectionContext : NSManagedObjectContext {
    NSString *tasksCachePath;
    NSString *tasksURLString;
}

// Properties
@property (nonatomic, copy, readonly) NSString *tasksCachePath;
@property (nonatomic, copy, readonly) NSString *tasksURLString;

@end
