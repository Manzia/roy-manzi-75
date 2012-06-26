//
//  MzProductUITests.m
//  MzProductUITests
//
//  Created by Macbook Pro on 6/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MzProductUITests.h"

@interface MzProductUITests ()

@property (nonatomic, strong, readwrite) MzProductCollection *productCollection;

@end


@implementation MzProductUITests

@synthesize productCollection;

- (void)setUp
{
    [super setUp];
    
    NSLog(@"%@ setup", self.name);
    self.productCollection = [[MzProductCollection alloc] initWithCollectionURLString:@"www.manzia.com/productCollection"];
    STAssertNotNil(self.productCollection, @"Failed to create Product Collection");
}

- (void)tearDown
{
    self.productCollection = nil;
    NSLog(@"%@ tearDown", self.name);
    
    [super tearDown];
}

// // test that we have a valid string
-(void) testCollectionString {
    STAssertTrue([self.productCollection.collectionURLString isEqualToString:@"www.manzia.com/productCollection"], @"Invalid collection String");
}
@end
