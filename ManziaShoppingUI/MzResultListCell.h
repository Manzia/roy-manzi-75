//
//  MzResultListCell.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 10/16/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MzProductItem;

@interface MzResultListCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UIImageView *productImage;
@property (nonatomic, strong) IBOutlet UILabel *productTitle;
@property (nonatomic, strong) IBOutlet UILabel *productPrice;
@property (nonatomic, strong) IBOutlet UILabel *priceLabel;
@property (nonatomic, strong) IBOutlet UISegmentedControl *reviewRanks;


// The Product Item that cell displays
@property (nonatomic, strong) MzProductItem *productItem;


@end
