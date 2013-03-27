//
//  MzSearchReviews2ViewController.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 3/27/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class MzSearchItem;
@class MzSearchSegmentedControl;

// Protocol implemented by delegates dealing with MzSearchItems'
@protocol MzSearchReviews2ViewControllerDelegate;

@interface MzSearchReviews2ViewController : UIViewController
<UIPickerViewDataSource, UIPickerViewDelegate, UITextViewDelegate, NSFetchedResultsControllerDelegate> {
    
}

// IBOutlets
@property(nonatomic, strong) IBOutlet UITextView* textView;
@property (nonatomic, strong) IBOutlet UIPickerView *pickerView;
@property (nonatomic, strong) IBOutlet MzSearchSegmentedControl *mainMenu;
//@property (nonatomic, strong) IBOutlet UILabel *textGuide;

// Our delegate
@property (nonatomic, weak) id <MzSearchReviews2ViewControllerDelegate> delegate;
@property (nonatomic, weak) id <MzSearchReviews2ViewControllerDelegate> qualityDelegate;

// Main Menu Value Changed
-(IBAction)selectedMainMenu:(id)sender;

// Rank Button
-(IBAction)rankButtonSelected:(id)sender;

@end

@protocol MzSearchReviews2ViewControllerDelegate <NSObject>

@optional

// Call delegate when we add a new MzSearchItem
-(void)controller:(MzSearchReviews2ViewController *)searchController addSearchItem:(MzSearchItem *)searchItem;

// User changed the Search/Ranking Category
-(void)controller:(MzSearchReviews2ViewController *)searchController changedCategory:(BOOL)changed;

@end

