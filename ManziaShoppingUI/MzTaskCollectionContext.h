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

// Initializer
- (id)initWithTasksURLString:(NSString *)URLString cachePath:(NSString *)cachePath;

// Returns a mutable request that's configured to do an HTTP GET operation 
// for a resources with the given path relative to the collectionURLString. 
// If path is nil, returns a request for the collectionURLString resource 
// itself.  This can return fail (and return nil) if path is not nil and 
// yet not a valid URL path.

- (NSMutableURLRequest *)requestToGetCollectionRelativeString:(NSString *)path;


@end
