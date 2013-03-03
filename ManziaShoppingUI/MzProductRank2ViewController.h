//
//  MzProductRankViewController.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 2/26/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CorePlot-CocoaTouch.h"
#import "CPDConstants.h"
#import "CPDStockPriceStore.h"

// Synchronization States
enum RankingSyncState {
    
    RankingSyncStateStopped,
    RankingSyncStateGetting,
    RankingSyncStateParsing,
    RankingSyncStateCommitting
};
typedef enum RankingSyncState RankingSyncState;

@interface MzProductRank2ViewController : UIViewController <CPTBarPlotDataSource, CPTBarPlotDelegate>

// Graph-related Properties
@property (nonatomic, strong) IBOutlet CPTGraphHostingView *hostView;

// Network-related Properties
@property (nonatomic, copy, readwrite) NSString *rankingURLString;

/* Properties that enable the control of the syncing process
 @property (nonatomic, assign, readonly, getter=isSynchronizing) BOOL synchronizing;
 @property (nonatomic, assign, readonly) RankingSyncState  stateOfSync;
 @property (nonatomic, copy, readonly) NSString *statusOfSync;
 @property (nonatomic, copy, readonly) NSDate *dateLastSynced;
 @property (nonatomic, copy, readonly) NSError *errorFromLastSync;
 @property (nonatomic, copy, readonly) NSDateFormatter *dateFormatter; */


@end
