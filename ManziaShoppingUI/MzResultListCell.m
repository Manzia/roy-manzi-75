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
        
        // Set the Labels and Image
        productTitle.text = productItem.productTitle;
        productTitle.textAlignment = UITextAlignmentCenter;
        productPrice.text = [NSString stringWithFormat:@"%@%@", kUSDollarSymbol, productItem.productPriceAmount];
        productPrice.textAlignment = UITextAlignmentLeft;
        productImage = [[UIImageView alloc] initWithImage:[productItem getthumbnailImage:kSmallThumbnailImage]];
        assert(productImage != nil);
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
