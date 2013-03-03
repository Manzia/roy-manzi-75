//
//  MzResultsDetailViewController.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 11/12/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzResultsDetailViewController.h"

@interface MzResultsDetailViewController ()

@end

@implementation MzResultsDetailViewController

@synthesize webView;
@synthesize urlString;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	assert(self.webView != nil);
    self.webView.delegate = self;
    
}

-(void)viewDidUnload
{
    
    [super viewDidUnload];
    self.webView.delegate = nil;
}

// Retrieve the ProductItem mobile URL
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // Do any additional setup after loading the view.
    assert(self.urlString != nil);
    NSURL *productURL = [NSURL URLWithString:self.urlString];
    assert(productURL != nil);
    NSURLRequest *productRequest = [NSURLRequest requestWithURL:productURL];
    assert(productRequest != nil);
    assert(self.webView != nil);
    [self.webView loadRequest:productRequest];
}

// Clear for the ProductItem selection
-(void)viewWillDisappear:(BOOL)animated
{
    self.urlString = nil;
    if (!self.webView.loading) {
        [self.webView stopLoading];
    }
}

// Rotation
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return  interfaceOrientation == UIInterfaceOrientationPortrait ? YES : NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark UIWebView Delegate Methods
// Allows the user to interact with mobile URL displayed
-(BOOL)webView:(UIWebView *)productView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}

@end
