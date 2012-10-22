//
//  MzSearchItem.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzSearchItem.h"
#import "Logging.h"

@implementation MzSearchItem

@synthesize priceToSearch;
@synthesize daysToSearch;
@synthesize searchOptions;
@synthesize searchTitle;
@synthesize searchStatus;
@synthesize searchTimestamp;

// Method to serialize the SearchItem - we allow for "empty" SearchItems
-(BOOL) writeSearchItemToFile:(NSURL *)filepath
{
    NSMutableDictionary *searchItem;
    searchItem = [NSMutableDictionary dictionary];
    assert(searchItem != nil);
    assert(filepath != nil);
    assert(filepath.isFileURL);
    
    // Add the price
    if (self.priceToSearch) {
        [searchItem setObject:self.priceToSearch forKey:kSearchItemPrice];        
    } else {
        [searchItem setObject:[NSNumber numberWithInt:0] forKey:kSearchItemPrice];
    }
    
    // Add the days
    if (self.daysToSearch) {
        [searchItem setObject:self.daysToSearch forKey:kSearchItemDays];
    } else {
        [searchItem setObject:[NSNumber numberWithInt:0] forKey:kSearchItemDays];
    }
    
    // Add the searchOptions
    if (self.searchOptions) {
        [searchItem setObject:self.searchOptions forKey:kSearchItemOptions];
    } else {
        [searchItem setObject:[NSDictionary dictionary] forKey:kSearchItemOptions];
    }
    
    // Add the title
    if (self.searchTitle) {
        [searchItem setObject:self.searchTitle forKey:kSearchItemTitle];
    } else {
        [searchItem setObject:[NSString string] forKey:kSearchItemTitle];
    }
    
    // Add the timestamp - note that since we use the timestamp for deletion
    // of the MzSearchItem we cannot set a default value
    if (self.searchTimestamp) {
        [searchItem setObject:self.searchTimestamp forKey:kSearchItemTimestamp];
    } else {
        
        [[QLog log] logWithFormat:@"Search Item has invalid Timestamp"]; 
    }
    
    // Add the SearchState - default is 0 = SearchItemStateInProgress
    [searchItem setObject:[NSNumber numberWithInt:self.searchStatus] forKey:kSearchItemState];
    
    // Can now write to file
    assert([searchItem count] == 6);
    [[QLog log] logWithFormat:@"Number of dictionary entries to write to file: %d", [searchItem count]];
    
    BOOL success;
    success = [searchItem writeToURL:filepath atomically:YES];
    
    return success;
}

// Keys for the SearchItem dictionary
NSString *kSearchItemTitle = @"searchItemTitle";
NSString *kSearchItemPrice = @"searchItemPrice";
NSString *kSearchItemDays = @"searchItemDays";
NSString *kSearchItemOptions = @"searchItemOptions";
NSString *kSearchItemState = @"searchItemState";
NSString *kSearchItemTimestamp = @"searchItemTimestamp";

@end
