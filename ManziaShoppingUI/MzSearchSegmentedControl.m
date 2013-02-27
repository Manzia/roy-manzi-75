//
//  MzSearchSegmentedControl.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 2/24/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzSearchSegmentedControl.h"

@implementation MzSearchSegmentedControl

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

// Trigger UIControlEventValueChanged even when re-tapping the selected segment.
-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    int oldValue = self.selectedSegmentIndex;
    [super touchesBegan:touches withEvent:event];
    if ( oldValue == self.selectedSegmentIndex )
        [self sendActionsForControlEvents:UIControlEventValueChanged];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
