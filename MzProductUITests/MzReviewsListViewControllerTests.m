//
//  MzReviewsListViewControllerTests.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 2/13/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzReviewsListViewControllerTests.h"
#import "MzReviewsListViewController.h"

// Ivars
@interface MzReviewsListViewControllerTests ()

@property (nonatomic, strong) MzReviewsListViewController *reviewController;

@end

@implementation MzReviewsListViewControllerTests

static NSString *kProductSkuId = @"7039173";

@synthesize reviewController;

- (void)setUp
{
    [super setUp];
    
    self.reviewController = [[MzReviewsListViewController alloc] initWithStyle:UITableViewStylePlain];
    STAssertNotNil(self.reviewController, @"Failed to create MzReviewsListViewController");
}

- (void)tearDown
{
    self.reviewController = nil;
    [super tearDown];
}

// // test that we have a valid string
-(void) testGenerateReviewsURL {
    NSString *actualReviewURL = [self.reviewController generateReviewsURL:kProductSkuId];
    NSString *expectedReviewURL = @"http://ec2-50-18-112-205.us-west-1.compute.amazonaws.com:8080/ManziaWebService/service/reviews?sku=7039173";
    
    // Test
    STAssertTrue([actualReviewURL isEqualToString:expectedReviewURL], @"Unexpected Reviews URL String");
}


@end
