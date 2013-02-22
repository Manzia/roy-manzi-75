//
//  MzReviewsListCell.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 2/2/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzReviewsListCell.h"
#import "MzReviewItem.h"

@implementation MzReviewsListCell

// Synthesize
@synthesize reviewAuthor;
@synthesize reviewDateTime;
@synthesize reviewItem;
@synthesize reviewRating;
@synthesize reviewSource;
@synthesize reviewText;
@synthesize reviewTitle;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

// Override Setter
-(void) setReviewItem:(MzReviewItem *)newReviewItem
{
    if (newReviewItem != nil) {
        self->reviewItem = newReviewItem;
        
        // Set the Cell Labels & Text
        self->reviewTitle.text = newReviewItem.reviewTitle;
        self->reviewText.text = newReviewItem.reviewContent;
        self->reviewSource.text = newReviewItem.reviewSource;
        self->reviewRating.text = [newReviewItem.reviewRating stringValue];
        self->reviewAuthor.text = newReviewItem.reviewAuthor;
        
        // Format the DateTime
        self->reviewDateTime.text = [self formatReviewSubmitTime:newReviewItem.reviewSubmitTime];
        
        // Format the TextView
        NSRange textRange = NSMakeRange(0, 150);
        [self->reviewText scrollRangeToVisible:textRange];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

// Helper method to format the DateTime from the RFC3339 format to NSDateFormatterMediumStyle i.e, Feb 2, 2013
-(NSString *)formatReviewSubmitTime:(NSDate *)reviewDate
{
    assert(reviewDate != nil);
        
    // Format the NSDate to the new Format
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:usLocale];
    
    return [dateFormatter stringFromDate:reviewDate];
}

@end
