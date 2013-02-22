//
//  MzResultsListViewController.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MzSearchListViewController.h"
#import "MzSearchReviewsViewController.h"


@interface MzResultsListViewController : UITableViewController <MzSearchListViewControllerDelegate,
MzSearchReviewsViewControllerDelegate> {
    
}

// Pushes the MzReviewsListViewController
-(IBAction)selectedReviewsTapped:(id)sender;

@end
