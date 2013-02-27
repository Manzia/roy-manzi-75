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

@interface MzProductRankViewController : UIViewController <CPTBarPlotDataSource, CPTBarPlotDelegate>

@property (nonatomic, strong) IBOutlet CPTGraphHostingView *hostView;

@end
