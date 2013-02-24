//
//  MzQualitiesListCell.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 2/24/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzQualitiesListCell.h"

@implementation MzQualitiesListCell

@synthesize qualityLabel;

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
