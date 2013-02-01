//
//  MzSearchReviewsViewController.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 1/31/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MzSearchReviewsViewController : UIViewController
<UIPickerViewDataSource, UIPickerViewDelegate > {
    
}

// IBOutlets
@property(nonatomic, strong) IBOutlet UISearchBar* searchBar;
@property (nonatomic, strong) IBOutlet UISegmentedControl *segmentedControl;
@property (nonatomic, strong) IBOutlet UIPickerView *pickerView;
@property (nonatomic, strong) IBOutlet UIButton *categoryButton;

// UISegmentedControl method
-(IBAction)selectedQueryType:(id)sender;

@end
