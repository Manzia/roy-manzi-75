//
//  MzProductCollectionContext.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 5/30/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface MzProductCollectionContext : NSManagedObjectContext {
    NSString *_collectionCachePath;  
}

// Properties
@property (nonatomic, copy, readonly) NSString *collectionCachePath;

// Initializer
- (id)initWithCollectionURLString:(NSString *)URLString cachePath:(NSString *)collectionCachePath;

@end
