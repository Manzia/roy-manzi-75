//
//  MzQualitiesListViewController.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 2/24/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MzSearchReviewsViewController.h"

@class MzQualityCollection;

@interface MzQualitiesListViewController : UITableViewController <MzSearchReviewsViewControllerDelegate>

// Array of Qualities to display
@property (nonatomic, strong) NSArray *qualityArray;

// QualityCollection
@property (nonatomic, strong) MzQualityCollection *qCollection;

// Save User Qualities
-(IBAction)saveQualities:(id)sender;

@end
