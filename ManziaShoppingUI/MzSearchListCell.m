//
//  MzSearchListCell.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzSearchListCell.h"
#import "MzSearchItem.h"

@implementation MzSearchListCell

@synthesize searchPriceLabel;
@synthesize searchTitleLabel;
@synthesize searchStatusLabel;
@synthesize searchItem;

// Override Setter
- (void)setSearchItem:(MzSearchItem *)newSearchItem {
    
    if (searchItem != newSearchItem) {
        searchItem = newSearchItem;
        
        searchPriceLabel.text = [searchItem.priceToSearch stringValue];
        searchTitleLabel.text = searchItem.searchTitle;
        
        switch (searchItem.searchStatus) {
            case SearchItemStateInProgress:
                searchStatusLabel.text = @"In Progress";
                break;
            case SearchItemStateCompleted:
                searchStatusLabel.text = @"Completed";
                break;
            default:
                break;
        }        
    }
}


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
