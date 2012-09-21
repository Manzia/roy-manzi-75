//
//  MzAddSearchHeaderView.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 9/13/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MzAddSearchHeaderViewDelegate;


@interface MzAddSearchHeaderView : UIView {
    
}

// Properties (subViews)
@property (nonatomic, strong) UITextField *priceField;
@property (nonatomic, strong) UIStepper *durationStepper;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIButton *productCategory;
@property (nonatomic, weak) id<MzAddSearchHeaderViewDelegate> delegate;

// Initialize

-(id)initWithFrame:(CGRect)theFrame delegate:(id <MzAddSearchHeaderViewDelegate>)theDelegate;

@end

/* Protocol to be implemented by delegates, delegates are informed when the Preferred Price is set,
 when the Search Duration is set and when the Product Category button is tapped
*/

@protocol MzAddSearchHeaderViewDelegate <NSObject>

@optional


// method called when the Search Duration is set
-(void)tableHeaderView:(MzAddSearchHeaderView *)headerView selectedDuration:(NSUInteger)duration;

// method called when Product Category button is tapped
-(void)tableHeaderView:(MzAddSearchHeaderView *)headerView categoryButtonState:(BOOL)isTapped;

@end