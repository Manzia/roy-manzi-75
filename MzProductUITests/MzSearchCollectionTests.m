//
//  MzSearchCollectionTests.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 2/21/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzSearchCollectionTests.h"
#import "MzSearchCollection.h"
#import "MzSearchItem.h"

@interface MzSearchCollectionTests ()

@property (nonatomic, strong) MzSearchCollection *searchCollection;

@end

@implementation MzSearchCollectionTests

@synthesize searchCollection;

// SearchItem Keys
static NSString *kSearchItemKeywords = @"q";
static NSString *kSearchItemCategory = @"Category";
static NSString *kDefaultSearchItemTitle = @"No Title";

// Setup Tests
- (void)setUp
{
    [super setUp];
    
    self.searchCollection = [[MzSearchCollection alloc] init];
    [self.searchCollection addSearchCollection];
    STAssertNotNil(self.searchCollection, @"Failed to create MzSearchCollection");
}

- (void)tearDown
{
    [self.searchCollection deleteSearchDirectory];
    self.searchCollection = nil;
    [super tearDown];
}

- (void) testRecentSearchItemInDirectory
{
    // Create 2 MzSearchItems
    MzSearchItem *searchItem = [[MzSearchItem alloc] init];
    searchItem.searchTitle = @"searchItem";
    searchItem.searchStatus = SearchItemStateInProgress;
    searchItem.searchTimestamp = [NSDate date];
    searchItem.daysToSearch = [NSNumber numberWithInt:0];
    searchItem.priceToSearch = [NSNumber numberWithDouble:0.0];
    
    // set the search Options
    NSDictionary *searchDict;
    //queryType = self.includeQuery ? kQueryTypeInclude : kQueryTypeExclude;
    searchDict = [NSDictionary dictionaryWithObjectsAndKeys:@"testQuery1", kSearchItemKeywords,
                  @"Laptops", kSearchItemCategory, nil];
    searchItem.searchOptions = [NSDictionary dictionaryWithDictionary:searchDict];
    
    MzSearchItem *searchItem1 = [[MzSearchItem alloc] init];
    searchItem1.searchTitle = @"searchItem1";
    searchItem1.searchStatus = SearchItemStateInProgress;
    searchItem1.daysToSearch = [NSNumber numberWithInt:0];
    searchItem1.priceToSearch = [NSNumber numberWithDouble:0.0];
    
    // set the search Options
    NSDictionary *searchDict1;
    //queryType = self.includeQuery ? kQueryTypeInclude : kQueryTypeExclude;
    searchDict1 = [NSDictionary dictionaryWithObjectsAndKeys:@"testQuery2", kSearchItemKeywords,
                  @"Laptops", kSearchItemCategory, nil];
    searchItem1.searchOptions = [NSDictionary dictionaryWithDictionary:searchDict];
    searchItem1.searchTimestamp = [NSDate date];
    
    // Add the SearchItems
    [self.searchCollection addSearchItem:searchItem];
    [self.searchCollection addSearchItem:searchItem1];
    
    // Test
    MzSearchItem *recentSearch = [self.searchCollection recentSearchItemInDirectory];
    STAssertNotNil(recentSearch, @"Recent MzSearchItem is Nil");
    NSLog(@"Recent Search Title: %@", recentSearch.searchTitle);
    STAssertTrue([recentSearch.searchTitle isEqualToString:@"searchItem1"], @"Unexpected Value for Search Title");
    
}


@end
