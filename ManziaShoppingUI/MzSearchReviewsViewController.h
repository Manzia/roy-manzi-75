//
//  MzSearchReviewsViewController.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 1/31/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

// Protocol implemented by delegates dealing with MzSearchItems'
@protocol MzSearchReviewsViewControllerDelegate;

@interface MzSearchReviewsViewController : UIViewController
<UIPickerViewDataSource, UIPickerViewDelegate, UISearchBarDelegate > {
    
}

// IBOutlets
@property(nonatomic, strong) IBOutlet UISearchBar* searchBar;
@property (nonatomic, strong) IBOutlet UISegmentedControl *segmentedControl;
@property (nonatomic, strong) IBOutlet UIPickerView *pickerView;
@property (nonatomic, strong) IBOutlet UIButton *categoryButton;

// Our delegate
@property (nonatomic, weak) id <MzSearchReviewsViewControllerDelegate> delegate;

// UISegmentedControl method
-(IBAction)selectedQueryType:(id)sender;

@end

@protocol MzSearchReviewsViewControllerDelegate <NSObject>

@optional

// Call delegate when we add a new MzSearchItem
-(void)controller:(MzSearchReviewsViewController *)searchController addSearchItem:(MzSearchItem *)searchItem;

@end