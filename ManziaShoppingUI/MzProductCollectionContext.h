//
//  MzProductCollectionContext.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 5/30/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

/* There's a one-to-one relationship between MzProductCollection and MzProductCollectionContext objects. The MzProductItem and MzProductThumbNail managed objects, can access this context  easily (via their managedObjectContext property).
 */

@interface MzProductCollectionContext : NSManagedObjectContext {
    NSString *collectionCachePath;
    NSString *collectionURLString;
}

// Properties
@property (nonatomic, copy, readonly) NSString *collectionCachePath;
@property (nonatomic, copy, readonly) NSString *collectionURLString;

// path to product Images directory within CollectionCachePath

@property (nonatomic, copy, readonly ) NSString *productImagesDirectoryPath;    

// Initializer
- (id)initWithCollectionURLString:(NSString *)URLString cachePath:(NSString *)cachePath;

// Returns a mutable request that's configured to do an HTTP GET operation 
// for a resources with the given path relative to the collectionURLString. 
// If path is nil, returns a request for the collectionURLString resource 
// itself.  This can return fail (and return nil) if path is not nil and 
// yet not a valid URL path.

- (NSMutableURLRequest *)requestToGetCollectionRelativeString:(NSString *)path;

// Const String declared in MzProductCollection.m
extern NSString * kProductImagesDirectoryName;

@end
