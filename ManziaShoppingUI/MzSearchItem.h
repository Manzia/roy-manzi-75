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

// States of a MzSearchItem object
enum SearchItemState {
    
    SearchItemStateInProgress, // search is in progress - default
    SearchItemStateCompleted    // search has been completed
};
typedef enum SearchItemState SearchItemState;

@interface MzSearchItem : NSObject {
    /*NSString *searchTitle;
    NSNumber *priceToSearch;        // price limit for search
    NSNumber *daysToSearch;        // duration of the search
    NSDictionary *searchOptions;
    SearchItemState searchStatus; */
}

// Public properties
@property (nonatomic, copy, readwrite) NSString *searchTitle;
@property (nonatomic, strong, readwrite) NSNumber *priceToSearch;
@property (nonatomic, strong, readwrite) NSNumber *daysToSearch;
@property (nonatomic, strong, readwrite) NSDictionary *searchOptions;
@property (nonatomic, assign, readwrite) SearchItemState searchStatus;
@property (nonatomic, strong, readwrite) NSDate *searchTimestamp;

// Method that serializes the MzSearchItem as a property list
-(BOOL) writeSearchItemToFile:(NSURL *)filepath;


// Keys for the MzSearchItem property List
extern NSString *kSearchItemTitle;
extern NSString *kSearchItemPrice;
extern NSString *kSearchItemDays;
extern NSString *kSearchItemOptions;
extern NSString *kSearchItemState;
extern NSString *kSearchItemTimestamp;

@end
