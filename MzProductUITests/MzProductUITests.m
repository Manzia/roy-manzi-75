//
//  MzProductUITests.m
//  MzProductUITests
//
//  Created by Roy Manzi Tumubweinee on 6/25/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
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
    self.productCollection = [[MzProductCollection alloc] initWithCollectionURLString:@"http://www.manzia.com/productCollection"];
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
    STAssertTrue([self.productCollection.collectionURLString isEqualToString:@"http://www.manzia.com/productCollection"], @"Invalid collection String");
}

/* test the startCollection method
- (void) testStartCollection {
    [self.productCollection startCollection];
    
    // Sync state is not stopped
    STAssertTrue(self.productCollection.stateOfSync != ProductCollectionSyncStateStopped, @"State of sync is Stopped");
    
    // we expect the getOperation to fail since we provided "invalid" URL
    STAssertTrue(self.productCollection.statusOfSync != nil, @"Sync status is nil" );
    NSLog(@"Sync status %@", self.productCollection.statusOfSync);
    
    // stop the collection
    [self.productCollection stopCollection];
    STAssertTrue(self.productCollection.stateOfSync == ProductCollectionSyncStateStopped, @"State of sync is not Stopped");
} */

@end
