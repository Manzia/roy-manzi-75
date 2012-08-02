//
//  MzSearchItem.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

/*
 MzSearchItem object represents a search created by the user. It captures
 all the search options/criteria.
 */

#import <Foundation/Foundation.h>

@interface MzSearchItem : NSObject {
    NSString *searchTitle;
    NSNumber *priceToSearch;        // price limit for search
    NSNumber *daysToSearch;        // duration of the search
    NSDictionary *searchOptions;
}

// Public properties
@property (nonatomic, copy, readwrite) NSString *searchTitle;
@property (nonatomic, strong, readwrite) NSNumber *priceToSearch;
@property (nonatomic, strong, readwrite) NSNumber *daysToSearch;
@property (nonatomic, strong, readwrite) NSDictionary *searchOptions;

// Method that serializes the MzSearchItem as a property list
-(BOOL) writeSearchItemToFile:(NSString *)filename;

// Keys for the MzSearchItem property List
extern NSString *kSearchItemTitle;
extern NSString *kSearchItemPrice;
extern NSString *kSearchItemDays;
extern NSString *kSearchItemOptions;

@end
