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

// path to product Images directory within CollectionCachePath

@property (nonatomic, copy, readonly ) NSString *productImagesDirectoryPath;    

// Initializer
- (id)initWithCollectionURLString:(NSString *)URLString cachePath:(NSString *)collectionCachePath;

// Returns a mutable request that's configured to do an HTTP GET operation 
// for a resources with the given path relative to the collectionURLString. 
// If path is nil, returns a request for the galleryURLString resource 
// itself.  This can return fail (and return nil) if path is not nil and 
// yet not a valid URL path.

- (NSMutableURLRequest *)requestToGetCollectionRelativeString:(NSString *)path;


@end
