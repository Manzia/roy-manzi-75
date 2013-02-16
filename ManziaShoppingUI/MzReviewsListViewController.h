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

// generate the reviews URL string, if an invalid productSku is specified we "pop" ourself
// and get off the screen
-(NSString *)generateReviewsURL:(NSString *)productSkuId;

@end
