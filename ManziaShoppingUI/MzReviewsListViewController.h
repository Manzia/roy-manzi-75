//
//  MzReviewsListViewController.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 2/2/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@class MzProductItem;

@interface MzReviewsListViewController : UITableViewController <NSFetchedResultsControllerDelegate>

// MzProductItem whose MzReviewItems will be displayed - this property
// will always be set by the ViewController that presents us via a Push UIStoryBoardSegue
@property (nonatomic, strong) MzProductItem *productItem;

// Category selected by User from the MzSearchReviewsViewController. This is a required query
// parameter when retrieveing Review from the Manzia backend. This value is set by the ViewController
// that pushes "us" onto screen
@property (nonatomic, strong) NSString *reviewCategory;

// generate the reviews URL string, if an invalid productSku is specified we "pop" ourself
// and get off the screen
-(NSString *)generateReviewsURL:(NSString *)productSkuId;

// Method called when User taps the Selected Reviews method
-(IBAction)selectedReviewsTapped:(id)sender;

@end
