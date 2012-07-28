//
//  MzTaskCollectionContext.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 7/24/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskCollectionContext.h"
#import "NetworkManager.h"

@interface MzTaskCollectionContext()

// private, read/write properties
@property(nonatomic, copy, readwrite) NSString *tasksCachePath;
@property(nonatomic, copy, readwrite) NSString *tasksURLString;

@end

@implementation MzTaskCollectionContext

// Getters and setters
@synthesize tasksCachePath;
@synthesize tasksURLString;

// Initialize
- (id)initWithTasksURLString:(NSString *)URLString cachePath:(NSString *)cachePath
{
    assert(URLString != nil);
    assert(cachePath != nil);
    
    self = [super init];
    if (self != nil) {
        self->tasksURLString = [URLString copy];
        self->tasksCachePath = [cachePath copy];
    }
    return self;
}

- (NSMutableURLRequest *)requestToGetCollectionRelativeString:(NSString *)path
{
    NSMutableURLRequest *urlRequest;
    NSURL *url;
    
    assert([NSThread isMainThread]);
    assert(self.tasksURLString != nil);
    
    urlRequest = nil;
    
    // Construct the URL.
    
    url = [NSURL URLWithString:self.tasksURLString];
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
