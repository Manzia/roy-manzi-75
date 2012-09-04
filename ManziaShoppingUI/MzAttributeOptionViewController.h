//
//  MzAttributeOptionViewController.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 9/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

// Protocol to be implement by delegates
@protocol MzAttributeOptionViewControllerDelegate;

@interface MzAttributeOptionViewController : UITableViewController

// Our delegate
@property (nonatomic, weak) id <MzAttributeOptionViewControllerDelegate> delegate;

// UIButton that caused us to be presented modally
@property (nonatomic, strong) UIButton *modalButton;

@end

// Protocol used to communicate back the user's selection to the viewController
// that instantiated us
@protocol MzAttributeOptionViewControllerDelegate <NSObject>

@optional

-(void)controller:(MzAttributeOptionViewController *)optionController selection:(NSString *)selectedString;

@end
