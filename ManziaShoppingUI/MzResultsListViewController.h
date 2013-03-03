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
-(IBAction)reviewRanksTapped:(id)sender;

// Generates a URL for a given MzSearchItem and Product SKU value that can be used to
// the Rank Results for that Product
-(NSURL *)createRankingURL:(MzSearchItem *)searchItem forProduct:(NSString *)prodSku;

@end
