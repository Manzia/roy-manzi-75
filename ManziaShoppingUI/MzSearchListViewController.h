//
//  MzSearchListViewController.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MzSearchListHeaderView.h"

@class MzSearchListCell;
@class MzSearchCollection;

@interface MzSearchListViewController : UITableViewController 
<MzSearchListHeaderViewDelegate> {
    
}

@property (nonatomic, strong) IBOutlet MzSearchListCell *searchCell;
@property (nonatomic, strong) MzSearchCollection *searchCollection;

@end
