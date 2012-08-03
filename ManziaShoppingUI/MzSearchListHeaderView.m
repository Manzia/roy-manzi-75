//
//  MzSearchListHeaderView.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzSearchListHeaderView.h"
#import <QuartzCore/QuartzCore.h>

#define BUTTON_WIDTH 120
#define BUTTON_HEIGHT 30

@implementation MzSearchListHeaderView

@synthesize addSearchButton;
@synthesize delegate;

// Frame is expected to be (0, 0, 320, 70)
- (id)initWithFrame:(CGRect)frame delegate:(id <MzSearchListHeaderViewDelegate>)theDelegate
{
    self = [super initWithFrame:frame];
    if (self) {
        
        // Initialize
        delegate = theDelegate;
        self.backgroundColor = [UIColor clearColor];
        
        // Create and configure the UIButton in the HeaderView
        CGFloat halfWidth = BUTTON_WIDTH/2;
        CGFloat halfHeight = BUTTON_HEIGHT/2;
        CGRect buttonFrame = CGRectMake(CGRectGetMidX(frame)-halfWidth, 
                                        CGRectGetMidY(frame)-halfHeight, BUTTON_WIDTH, BUTTON_HEIGHT);
        
        assert(CGRectContainsRect(frame, buttonFrame));     //check valid Rect
        UIButton *searchButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        searchButton.frame = buttonFrame;
        [searchButton setBackgroundColor:[UIColor clearColor]];
        [searchButton setTitle:@"Add a Search" forState:UIControlStateNormal];
        [searchButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        searchButton.userInteractionEnabled = YES;
        [searchButton addTarget:self action:@selector(addSearchSelected:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:searchButton];
        addSearchButton = searchButton;        
    }
    return self;
}

// Inform the delegate when the user taps the "Add a Search" button
-(IBAction)addSearchSelected:(id)sender {
       
    if ([self.delegate respondsToSelector:@selector(tableHeaderView:buttonState:)]) {
        [self.delegate tableHeaderView:self buttonState:YES];
    }    
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
