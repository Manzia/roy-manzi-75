//
//  MzProductCollectionTests.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 5/31/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzProductCollectionTests.h"
#import "MzProductCollection.h"

@interface MzProductCollectionTests()
@property (nonatomic, retain)MzProductCollection *productCollection;

@end

@implementation MzProductCollectionTests
@synthesize productCollection;

// Setup Method
-(void)setUp {
    NSLog(@"%@ setUp", self.name);
    NSString *urlString = @"http://test.manzia.com/collections";
    productCollection = [[MzProductCollection alloc] initWithCollectionURLString:urlString];
}

// Tear down uses ARC....hopefully!!!
-(void)tearDown {
    NSLog(@"%@ tearDown using ARC", self.name);
}

// Test
-(void)testPathToCachesDirectory {
    NSLog(@"%@ start", self.name); // self.name is name of test-case method
   
}

// All code under test must be linked into the Unit Test bundle
- (void)testMath
{
    STAssertTrue((1 + 1) == 2, @"Compiler isn't feeling well today :-(");
}

@end
