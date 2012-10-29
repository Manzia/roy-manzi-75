//
//  MzAddSearchHeaderView.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 9/13/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzAddSearchHeaderView.h"

@implementation MzAddSearchHeaderView

@synthesize priceField;
@synthesize productCategory;
@synthesize durationLabel;
@synthesize durationStepper;
@synthesize delegate;

// View Frame is expected to be (0, 0, 320, 110)
-(id)initWithFrame:(CGRect)theFrame delegate:(id <MzAddSearchHeaderViewDelegate>)theDelegate
{
    self = [super initWithFrame:theFrame];
    if (self) {
        
        // Initialization code
        self.delegate = theDelegate;
        self.backgroundColor = [UIColor clearColor];
        
        // create the UILabels
        // priceLabel
        CGRect priceLabelRect = CGRectMake(20, 10, 120, 25);
        UILabel *priceLabel = [[UILabel alloc] initWithFrame:priceLabelRect];
        assert(priceLabel != nil);
        priceLabel.text = @"Preferred Price US$";
        priceLabel.font = [UIFont systemFontOfSize:17.0];
        priceLabel.textColor = [UIColor redColor];
        priceLabel.tag = 0;
        priceLabel.minimumFontSize = 10.0;
        priceLabel.adjustsFontSizeToFitWidth = YES;
        priceLabel.userInteractionEnabled = NO;
        priceLabel.backgroundColor = [UIColor lightGrayColor];
        
        //search Duration label
        CGRect durationLabelRect = CGRectMake(20, 48, 140, 25);
        UILabel *searchDurationLabel = [[UILabel alloc] initWithFrame:durationLabelRect];
        assert(searchDurationLabel != nil);
        searchDurationLabel.text = @"Search Duration (Days)";
        searchDurationLabel.font = [UIFont systemFontOfSize:17.0];
        searchDurationLabel.textColor = [UIColor redColor];
        searchDurationLabel.tag = 1;
        searchDurationLabel.minimumFontSize = 10.0;
        searchDurationLabel.adjustsFontSizeToFitWidth = YES;
        searchDurationLabel.userInteractionEnabled = NO;
        searchDurationLabel.backgroundColor = [UIColor lightGrayColor];
        
        //productCategory label
        CGRect productCategoryRect = CGRectMake(20, 80, 120, 21);
        UILabel *productCategoryLabel = [[UILabel alloc] initWithFrame:productCategoryRect];
        assert(productCategoryLabel != nil);
        productCategoryLabel.text = @"Product Category";
        productCategoryLabel.font = [UIFont systemFontOfSize:13.0];
        productCategoryLabel.textColor = [UIColor redColor];
        productCategoryLabel.tag = 2;
        productCategoryLabel.minimumFontSize = 10.0;
        productCategoryLabel.adjustsFontSizeToFitWidth = YES;
        productCategoryLabel.userInteractionEnabled = NO;
        productCategoryLabel.backgroundColor = [UIColor lightGrayColor];
        
        // search Duration value Label
        CGRect durationValueRect = CGRectMake(281, 48, 30, 27);
        UILabel *durationValueLabel = [[UILabel alloc] initWithFrame:durationValueRect];
        assert(durationValueLabel != nil);
        durationValueLabel.text = @"0";
        durationValueLabel.font = [UIFont systemFontOfSize:17.0];
        durationValueLabel.textColor = [UIColor redColor];
        durationValueLabel.tag = 3;
        durationValueLabel.minimumFontSize = 10.0;
        durationValueLabel.adjustsFontSizeToFitWidth = YES;
        durationValueLabel.userInteractionEnabled = NO;
        durationValueLabel.backgroundColor = [UIColor lightGrayColor];
        self.durationLabel = durationValueLabel;
        
        // instantiate the UITextField
        CGRect priceTextRect = CGRectMake(180, 10, 94, 31);
        UITextField *priceValue = [[UITextField alloc] initWithFrame:priceTextRect];
        assert(priceValue != nil);
        priceValue.placeholder = @"100.00";
        priceValue.font = [UIFont systemFontOfSize:17.0];
        priceValue.tag = 4;
        priceValue.minimumFontSize = 10.0;
        priceValue.adjustsFontSizeToFitWidth = YES;
        priceValue.clearsOnBeginEditing = YES;
        priceValue.backgroundColor = [UIColor whiteColor];
        priceValue.returnKeyType = UIReturnKeyDone;
        priceValue.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        self.priceField = priceValue;
        
        // instantiate the UIStepper view
        CGRect durationStepperRect = CGRectMake(180, 48, 94, 27);
        UIStepper *durationSearchStepper = [[UIStepper alloc] initWithFrame:durationStepperRect];
        assert(durationSearchStepper != nil);
        durationSearchStepper.minimumValue = 0;
        durationSearchStepper.maximumValue = 7;
        durationSearchStepper.stepValue = 1.0;
        durationSearchStepper.tag = 5;
        self.durationStepper = durationSearchStepper;
        
        // add Target
        [self.durationStepper addTarget:self action:@selector(durationStepperDidChange) forControlEvents:UIControlEventValueChanged];
        
        // instantiate the UIButton view for the productCategory
        CGRect categoryRect = CGRectMake(180, 80, 94, 27);
        UIButton *categoryButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        assert(categoryButton != nil);
        categoryButton.frame = categoryRect;
        //[categoryButton setTitle:@"Phones" forState:UIControlStateNormal];
        categoryButton.userInteractionEnabled = YES;
        categoryButton.tag = 6;
        self.productCategory = categoryButton;
        
        // add Target
        [self.productCategory addTarget:self action:@selector(categoryButtonWasTapped) forControlEvents:UIControlEventTouchUpInside];
        
        // Add all the subviews
        [self insertSubview:priceLabel atIndex:priceLabel.tag];
        [self insertSubview:searchDurationLabel atIndex:searchDurationLabel.tag];
        [self insertSubview:productCategoryLabel atIndex:productCategoryLabel.tag];
        [self insertSubview:durationValueLabel atIndex:durationValueLabel.tag];
        [self insertSubview:priceValue atIndex:priceValue.tag];
        [self insertSubview:durationSearchStepper atIndex:durationSearchStepper.tag];
        [self insertSubview:categoryButton atIndex:categoryButton.tag];
    }
    return self;
}

// Method called when the durationStepper changes value
-(void)durationStepperDidChange
{
    // we call our delegate
    assert(self.delegate != nil);
    [self.delegate tableHeaderView:self selectedDuration:self.durationStepper.value];             
}

// Method called when categoryButton is tapped
-(void)categoryButtonWasTapped
{
    // we call our delegate
    assert(self.delegate != nil);
    [self.delegate tableHeaderView:self categoryButtonState:YES];
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
