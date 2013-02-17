//
//  MzResultListCell.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 10/16/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzResultListCell.h"
#import "MzProductItem.h"


@implementation MzResultListCell

@synthesize productImage;
@synthesize productItem;
@synthesize productPrice;
@synthesize productTitle;
@synthesize priceLabel;
@synthesize selectedReviews;

// USD
static NSString *kUSDollarSymbol = @"$";

// Initializer
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

// Override Setter
-(void) setProductItem:(MzProductItem *)newProductItem
{
    if (productItem != newProductItem) {
        productItem = newProductItem;
        
        // The priceLabel.text string will be nil if we've been handed a cell that was dequeued
        // and was originally a "No Searches Found" or "No Products Found" cell, so we need to
        // un-nil first, we also need to re-set the Colors, Fonts etc..
        
        // Set the Labels and Image
        productTitle.text = productItem.productTitle;
        productTitle.textColor = [UIColor darkTextColor];
        productTitle.textAlignment = UITextAlignmentCenter;
        productTitle.font = [UIFont systemFontOfSize:15.0];
        productPrice.text = [NSString stringWithFormat:@"%@%@", kUSDollarSymbol, productItem.productPriceAmount];
        productPrice.textColor = [UIColor redColor];
        productPrice.textAlignment = UITextAlignmentLeft;
        
        
        if (priceLabel.text == nil) {
            priceLabel.text = @"Price:";
        }
        priceLabel.textAlignment = UITextAlignmentRight;
        priceLabel.textColor = [UIColor darkTextColor];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
