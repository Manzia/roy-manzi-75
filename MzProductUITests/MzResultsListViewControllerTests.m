//
//  MzResultsListViewControllerTests.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 3/1/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzResultsListViewControllerTests.h"
#import "MzResultsListViewController.h"

@interface MzResultsListViewControllerTests ()

@property(nonatomic, strong) MzResultsListViewController *resultsController;

@end

@implementation MzResultsListViewControllerTests

@synthesize resultsController;

static NSString *kProductSkuId = @"4602955";
static NSString *kSearchItemCategory = @"Category";

- (void)setUp
{
    [super setUp];
    
    self.resultsController = [[MzResultsListViewController alloc] initWithStyle:UITableViewStylePlain];
    STAssertNotNil(self.resultsController, @"Failed to create MzResultsListViewController");    
}

- (void)tearDown
{
    self.resultsController = nil;
    [super tearDown];
}

// // test that we have a valid string
-(void) testCreateRankURL {
    
    // Create MzSearchItem
    MzSearchItem *searchItem = [[MzSearchItem alloc] init];
    searchItem.searchTitle = @"searchItem";
    searchItem.searchStatus = SearchItemStateInProgress;
    searchItem.searchTimestamp = [NSDate date];
    searchItem.daysToSearch = [NSNumber numberWithInt:0];
    searchItem.priceToSearch = [NSNumber numberWithDouble:0.0];
    
    // set the search Options
    NSDictionary *searchDict;
    searchDict = [NSDictionary dictionaryWithObjectsAndKeys:@"testQuery1", @"q1", @"testQuery2 testQuery3", @"q2", @"testQuery4", @"q3", @"Laptops", kSearchItemCategory, nil];
    searchItem.searchOptions = [NSDictionary dictionaryWithDictionary:searchDict];

    
    NSURL *actualReviewURL = [self.resultsController createRankingURL:searchItem forProduct:kProductSkuId];
    NSString *expectedReviewURL = @"http://ec2-50-18-112-205.us-west-1.compute.amazonaws.com:8080/ManziaWebService/service/ranking/415-309-7418?sku=4602955&Category=Laptops&q2=testQuery2%20testQuery3&q1=testQuery1&q3=testQuery4";
    
    // Test
    NSLog(@"Actual Review URL: %@", actualReviewURL);
    NSLog(@"Expected Review URL: %@", expectedReviewURL);
    STAssertTrue([[actualReviewURL absoluteString] isEqualToString:expectedReviewURL], @"Unexpected Ranking URL String");
}

@end
