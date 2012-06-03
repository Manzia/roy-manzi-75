//
//  MzCollectionParserOperation.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 6/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MzCollectionParserOperation.h"


@interface MzCollectionParserOperation () <NSXMLParserDelegate>

// read/write variants of public properties

@property (copy, readwrite) NSError *parseError;

// private properties

#if ! defined(NDEBUG)
@property (assign, readwrite) NSTimeInterval debugDelaySoFar;
#endif

@property (retain, readonly ) NSMutableArray *mutableResults;
@property (retain, readwrite) NSXMLParser *collectionParser;
@property (retain, readonly ) NSMutableDictionary *productItemProperties;

@end


@implementation MzCollectionParserOperation

@synthesize parseError;
@synthesize productItemProperties;
@synthesize debugDelay;
@synthesize debugDelaySoFar;
@synthesize mutableResults;
@synthesize collectionParser;

// Initialization
- (id)initWithXMLData:(NSData *)data
{
    assert(data != nil);
    self = [super init];
    if (self != nil) {
        self->xmlData = [data copy];
        self->mutableResults  = [[NSMutableArray alloc] init];
        assert(self->mutableResults != nil);
        self->productItemProperties = [[NSMutableDictionary alloc] init];
        assert(self->productItemProperties != nil);
    }
    return self;
}


@end
