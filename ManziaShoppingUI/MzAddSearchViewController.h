//
//  MzAddSearchViewController.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/13/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MzSearchItem.h"

// Protocol to be implement by delegates
@protocol MzAddSearchViewControllerDelegate;

// Tags for the Search Option UIButton views
enum SearchOptionButton {
    
    SearchOptionButtonLeft, 
    SearchOptionButtonMiddle, 
    SearchOptionButtonRight
};
typedef enum SearchOptionButton SearchOptionButton;

@interface MzAddSearchViewController : UITableViewController


// Our delegate
@property (nonatomic, weak) id <MzAddSearchViewControllerDelegate> delegate;

// Property that can be used to access the ManagedObject context
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedContext;


@end

// Protocol used to communicate back the newly created MzSearchItem to the viewController
// that instantiated us
@protocol MzAddSearchViewControllerDelegate <NSObject>

@optional

-(void)controller:(MzAddSearchViewController *)searchController newSearchItem:(MzSearchItem *)searchItem;

@end


