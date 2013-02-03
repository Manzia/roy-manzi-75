//
//  MzReviewsListCell.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 2/2/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MzReviewItem;

@interface MzReviewsListCell : UITableViewCell

// Interface Builder properties
@property (nonatomic, strong, readonly) IBOutlet UILabel *reviewTitle;
@property (nonatomic, strong, readonly) IBOutlet UILabel *reviewRating;
@property (nonatomic, strong, readonly) IBOutlet UILabel *reviewAuthor;
@property (nonatomic, strong, readonly) IBOutlet UILabel *reviewDateTime;
@property (nonatomic, strong, readonly) IBOutlet UILabel *reviewSource;
@property (nonatomic, strong, readonly) IBOutlet UITextView *reviewText;

// The MzReviewItem the cell displays
@property (nonatomic, strong) MzReviewItem *reviewItem;

@end
