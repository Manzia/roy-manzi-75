//
//  MzSearchListHeaderView.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.

/*
 MzSearchListHeaderView is assigned to the tableHeaderView
 property of the UITableView of the MzSearchListViewController
 It has one UIButton that pushes onto the screen the
 MzAddSearchViewController that allow the user to creates Searches
 (MzSearchItems)
 */

#import <UIKit/UIKit.h>

@protocol MzSearchListHeaderViewDelegate;


@interface MzSearchListHeaderView : UIView {
    
}

@property (nonatomic, weak) UIButton *addSearchButton;
@property (nonatomic, weak) id <MzSearchListHeaderViewDelegate> delegate;

// Initialize

-(id)initWithFrame:(CGRect)theFrame delegate:(id <MzSearchListHeaderViewDelegate>)theDelegate;

@end

/*
 Protocol to be adopted by the section header's delegate; the section header tells its delegate when the section should be opened and closed.
 */
@protocol MzSearchListHeaderViewDelegate <NSObject>

@optional

-(void)tableHeaderView:(MzSearchListHeaderView *)sectionHeaderView buttonState:(BOOL)isTapped;


@end
