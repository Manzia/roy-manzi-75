//
//  MzSearchListCell.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MzSearchItem;

@interface MzSearchListCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *searchTitleLabel;
@property (nonatomic, weak) IBOutlet UILabel *searchPriceLabel;
@property (nonatomic, weak) IBOutlet UILabel *searchStatusLabel;

// MzSearchItem
@property (nonatomic, strong) MzSearchItem *searchItem; 

@end
