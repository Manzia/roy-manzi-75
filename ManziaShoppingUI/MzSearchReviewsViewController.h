//
//  MzSearchReviewsViewController.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 1/31/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class MzSearchItem;

// Protocol implemented by delegates dealing with MzSearchItems'
@protocol MzSearchReviewsViewControllerDelegate;

@interface MzSearchReviewsViewController : UIViewController
<UIPickerViewDataSource, UIPickerViewDelegate, UISearchBarDelegate, NSFetchedResultsControllerDelegate> {
    
}

// IBOutlets
@property(nonatomic, strong) IBOutlet UISearchBar* searchBar;
@property (nonatomic, strong) IBOutlet UIPickerView *pickerView;
@property (nonatomic, strong) IBOutlet UIButton *categoryButton;

// Our delegate
@property (nonatomic, weak) id <MzSearchReviewsViewControllerDelegate> delegate;

@end

@protocol MzSearchReviewsViewControllerDelegate <NSObject>

@optional

// Call delegate when we add a new MzSearchItem
-(void)controller:(MzSearchReviewsViewController *)searchController addSearchItem:(MzSearchItem *)searchItem;

@end