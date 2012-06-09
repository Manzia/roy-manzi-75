//
//  MzProductCollectionContext.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 5/30/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzProductCollectionContext.h"
#import "NetworkManager.h"

@interface MzProductCollectionContext()

// private, read/write properties
@property(nonatomic, copy, readwrite) NSString *collectionCachePath;
@property(nonatomic, copy, readwrite) NSString *collectionURLString;

@end

@implementation MzProductCollectionContext 

// Getters and setters
@synthesize collectionCachePath;
@synthesize collectionURLString;

// Initialize
- (id)initWithCollectionURLString:(NSString *)URLString cachePath:(NSString *)cachePath
{
    assert(URLString != nil);
    assert(cachePath != nil);
    
    self = [super init];
    if (self != nil) {
        self->collectionURLString = [URLString copy];
        self->collectionCachePath = [cachePath copy];
    }
    return self;
}

// Returns path to the productImage Directory
- (NSString *)productImagesDirectoryPath
{
    return [self.collectionCachePath stringByAppendingPathComponent:kProductImagesDirectoryName];
}

- (NSMutableURLRequest *)requestToGetCollectionRelativeString:(NSString *)path
{
    NSMutableURLRequest *urlRequest;
    NSURL *url;
    
    assert([NSThread isMainThread]);
    assert(self.collectionURLString != nil);
    
    urlRequest = nil;
    
    // Construct the URL.
    
    url = [NSURL URLWithString:self.collectionURLString];
    assert(url != nil);
    if (path != nil) {
        url = [NSURL URLWithString:path relativeToURL:url];               
    }
    
    // Call down to the network manager so that it can set up its stuff 
    // (notably the user agent string).
    
    if (url != nil) {
        urlRequest = [[NetworkManager sharedManager] requestToGetURL:url];
        assert(urlRequest != nil);
    }
    
    return urlRequest;
}

@end
