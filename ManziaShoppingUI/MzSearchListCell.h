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

@property (nonatomic, strong) IBOutlet UILabel *searchTitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *searchPriceLabel;
@property (nonatomic, strong) IBOutlet UILabel *searchStatusLabel;

// MzSearchItem
@property (nonatomic, strong) MzSearchItem *searchItem; 

@end
