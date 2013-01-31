//
//  MzResultsDetailViewController.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 11/12/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MzResultsDetailViewController : UIViewController <UIWebViewDelegate>

// URL String used to initialize the UIWebView
@property(nonatomic, strong) IBOutlet UIWebView *webView;
@property(nonatomic,copy) NSString *urlString;

@end
