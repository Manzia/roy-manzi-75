//
//  MzSearchItem.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzSearchItem.h"

@implementation MzSearchItem

@synthesize priceToSearch;
@synthesize daysToSearch;
@synthesize searchOptions;
@synthesize searchTitle;
@synthesize searchStatus;

// Method to serialize the SearchItem - we allow for "empty" SearchItems
-(BOOL) writeSearchItemToFile:(NSString *)filename
{
    NSMutableDictionary *searchItem;
    searchItem = [NSMutableDictionary dictionary];
    assert(searchItem != nil);
    
    // Add the price
    if (self.priceToSearch) {
        [searchItem setObject:self.priceToSearch forKey:kSearchItemPrice];        
    } else {
        [searchItem setObject:[NSNull null] forKey:kSearchItemPrice];
    }
    
    // Add the days
    if (self.daysToSearch) {
        [searchItem setObject:self.daysToSearch forKey:kSearchItemDays];
    } else {
        [searchItem setObject:[NSNull null] forKey:kSearchItemDays];
    }
    
    // Add the searchOptions
    if (self.searchOptions) {
        [searchItem setObject:self.searchOptions forKey:kSearchItemOptions];
    } else {
        [searchItem setObject:[NSNull null] forKey:kSearchItemOptions];
    }
    
    // Add the title
    if (self.searchTitle) {
        [searchItem setObject:self.searchTitle forKey:kSearchItemTitle];
    } else {
        [searchItem setObject:[NSNull null] forKey:kSearchItemTitle];
    }
    
    // Add the SearchState - default is 0 = SearchItemStateInProgress
    [searchItem setObject:[NSNumber numberWithInt:searchStatus] forKey:kSearchItemState];
    
    // Can now write to file
    assert([searchItem count] == 5);
    BOOL success;
    success = [searchItem writeToFile:filename atomically:YES];
    
    return success;
}

// Keys for the SearchItem dictionary
NSString *kSearchItemTitle = @"searchItemTitle";
NSString *kSearchItemPrice = @"searchItemPrice";
NSString *kSearchItemDays = @"searchItemDays";
NSString *kSearchItemOptions = @"searchItemOptions";
NSString *kSearchItemState = @"searchItemState";

@end
