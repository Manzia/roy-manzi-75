//
//  MzSearchListViewController.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MzSearchListHeaderView.h"
#import "MzAddSearchViewController.h"

@class MzSearchListCell;
@class MzSearchCollection;

// Protocol implemented by delegates dealing with MzSearchItems'
@protocol MzSearchListViewControllerDelegate;

@interface MzSearchListViewController : UITableViewController 
<MzSearchListHeaderViewDelegate, MzAddSearchViewControllerDelegate> {
    
}

@property (nonatomic, strong) IBOutlet MzSearchListCell *searchCell;
@property (nonatomic, strong) MzSearchCollection *searchCollection;

// Our delegate
@property (nonatomic, weak) id <MzSearchListViewControllerDelegate> delegate;

@end

@protocol MzSearchListViewControllerDelegate <NSObject>

@optional

// Call delegate when we add a new MzSearchItem
-(void)controller:(MzSearchListViewController *)searchController addedSearchItem:(MzSearchItem *)searchItem;

// Call delegate when we delete a MzSearchItem
-(void)controller:(MzSearchListViewController *)searchController deletedSearchItem:(MzSearchItem *)searchItem;

@end