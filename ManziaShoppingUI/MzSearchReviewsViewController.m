//
//  MzSearchReviewsViewController.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 1/31/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzSearchReviewsViewController.h"
#import "MzTaskCollection.h"
#import "Logging.h"
#import "MzResultsListViewController.h"
#import "MzSearchCollection.h"
#import "MzAppDelegate.h"

@interface MzSearchReviewsViewController ()

@property (nonatomic, strong) NSFetchedResultsController *fetchController;
@property (nonatomic, strong) NSManagedObjectContext *managedContext;

@end

@implementation MzSearchReviewsViewController

// Synthesizers
@synthesize categoryButton;
@synthesize pickerView;
@synthesize searchBar;
@synthesize fetchController;

// Database entity that we fetch from
static NSString *kTaskTypeEntity = @"MzTaskType";

// SearchItem Keys
static NSString *kSearchItemKeywords = @"Keywords";
static NSString *kSearchItemCategory = @"Category";
static NSString *kDefaultSearchItemTitle = @"No Title";
static NSString *kDefaultCategoryButtonString = @"Select a Category";

// Initializer
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
	
    // we initialize our NSManagedObjectContext
    NSManagedObjectContext *mcontext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    assert(mcontext != nil);
    if ([MzTaskCollection taskCollectionCoordinator] != nil) {
        [mcontext setPersistentStoreCoordinator:[MzTaskCollection taskCollectionCoordinator]];
        self.managedContext = mcontext;
    } else {
        
        //Log
        [[QLog log] logWithFormat:@"Error: Persistent Store Coordinator for Task Collection is nil"];
    }
    
    // We can now initialize our NSFetchedResultsController
    NSFetchRequest *mrequest = [NSFetchRequest fetchRequestWithEntityName:kTaskTypeEntity];
    assert(mrequest != nil);
    NSSortDescriptor *sortDescriptorType = [[NSSortDescriptor alloc] initWithKey:@"taskTypeName" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptorType];
    [mrequest setSortDescriptors:sortDescriptors];
    
    // We set up only one section i.e one component for the UIPickerView
    NSFetchedResultsController *controller = [[NSFetchedResultsController alloc] initWithFetchRequest:mrequest
                                                                                 managedObjectContext:self.managedContext
                                                                                   sectionNameKeyPath:nil
                                                                                            cacheName:nil];
    assert(controller != nil);
    self.fetchController = controller;
    assert(self.fetchController != nil);
    
    // Execute the fetch
    NSError *error = NULL;
    [self.fetchController performFetch:&error];
    
    // Error-checking
    if (error) {
        
        //Log
        [[QLog log] logWithFormat:@"Error fetching Categories to display from TaskTypes Entity: %@", error.localizedDescription];
        self.fetchController = nil;
    }
    
    // Set up the categoryButton
    assert(self.categoryButton != nil);
    [self.categoryButton addTarget:self action:@selector(selectCategory) forControlEvents:UIControlEventTouchUpInside];
    
    // Set up the UISearchBar
    assert(self.searchBar != nil);
    self.searchBar.delegate = self;
    self.searchBar.showsCancelButton = YES;
    
    // Set up the MzResultsListViewController as the delegate for insertions and deletions of
    // MzSearchItems.
    // 1- Get the delegate's Navigation Controller
    UINavigationController *delegateNavController = [[self.tabBarController viewControllers] objectAtIndex:1];
    assert(delegateNavController != nil);
    
    // 2- Find out whichever conforms to our protocol and set them as our delegate
    if ([delegateNavController.viewControllers count] > 0 ) {
        NSUInteger delegateIndex = [delegateNavController.viewControllers indexOfObjectPassingTest:
                                    ^(id viewController, NSUInteger idx, BOOL *stop) {
                                        if( [viewController isKindOfClass:[MzResultsListViewController class]] &&
                                           [MzResultsListViewController conformsToProtocol:@protocol(MzSearchReviewsViewControllerDelegate)]) {
                                            *stop = YES;
                                            return YES;
                                        } else {
                                            return  NO;
                                        }
                                    }];
        if (delegateIndex != NSNotFound) {
            self.delegate = [delegateNavController.viewControllers objectAtIndex:delegateIndex];
        } else {
            //Log
            [[QLog log] logWithFormat:@"WARNING: No ViewController was found to set as Delegate to the MzSearchReviewsViewController!!"];
        }
    } else {
        //Log
        [[QLog log] logWithFormat:@"MzSearchReviewsViewController delegate's NavigationViewController has zero ViewControllers!!"];
    }
   
}

// Release iVars
-(void) viewDidUnload
{
    self.managedContext = nil;
    self.fetchController = nil;
    self.searchBar.delegate = nil;
}

// View Lifecycle
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Keep the UIPickerView hidden until user taps the categoryButton
    assert(self.pickerView != nil);
    self.pickerView.hidden = YES;    
}


#pragma mark * UIPickerView DataSource Methods

// UIPickerView component count = 1
-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// UIPickerView row count per component
-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    // we return zero rows if we did not fetch any MzTaskTypes from the database
    if (self.fetchController != nil) {
        return [[self.fetchController fetchedObjects] count];
    } else {
        return 0;
    }
}

#pragma mark * UIPickerView Delegate Methods

// Return the appropriate category
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    assert(self.fetchController != nil);
    NSArray *categories = [[self.fetchController fetchedObjects] valueForKey:@"taskTypeName"];
    assert(categories != nil);
    return [categories objectAtIndex:row];
}

// Respond to a selection
- (void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    // Assign the selected String to the category UIButton
    assert(self.fetchController != nil);
    NSArray *categories = [[self.fetchController fetchedObjects] valueForKey:@"taskTypeName"];
    assert(categories != nil);
    NSString *selectedCategory = [categories objectAtIndex:row];
    assert(self.categoryButton != nil);
    assert(selectedCategory != nil);
    [self.categoryButton setTitle:selectedCategory forState:UIControlStateNormal];
    
    // Dismiss the UIPickerView from view
    self.pickerView.hidden = YES;    
}

// Bring up the UIPickerView if its hidden otherwise if its already on screen then dismiss it
-(void)selectCategory
{
    assert(self.pickerView != nil);
    
    if (self.pickerView.hidden) {
        self.pickerView.hidden = NO;
    } else {
        self.pickerView.hidden = YES;
    }
}

#pragma mark * Memory Management

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark * Search Query Management

/* User selects a query Type - Include or Exclude
-(IBAction)selectedQueryType:(id)sender
{
    NSString *queryType = [self.segmentedControl titleForSegmentAtIndex:self.segmentedControl.selectedSegmentIndex];
    assert(queryType != nil);
    
    if ([queryType isEqualToString:kQueryTypeInclude]) {
        self.includeQuery = YES;        
    } else if ([queryType isEqualToString:kQueryTypeExclude]) {
        self.includeQuery = NO;
    }
} */

// Verify that the User has selected a Category before they can enter a Query
-(BOOL) searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    assert(self.categoryButton != nil);
    if ([self.categoryButton.titleLabel.text isEqualToString:kDefaultCategoryButtonString]) {
        
        // Display an Alert
        UIAlertView *searchAlert;
        searchAlert = [[UIAlertView alloc] initWithTitle:@"Required" message:@"Tap to Select a Category" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        assert(searchAlert != nil);
        
        // Display alert
        [searchAlert show];
        
        return NO;
    } else {
        return YES;
    }
}

// Respond to the User's selection on the UIAlertView
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonsIndex
{
   // We don't do anything
    return;
}

// User is going to enter the query
-(void) searchBarSearchButtonClicked:(UISearchBar *)searchesBar
{
    NSString *query;
    assert(searchesBar != nil);
    query = searchesBar.text;
    if ([query length] > 0) {
        
        //Log
        [[QLog log] logWithFormat:@"User entered query: %@", query];
        
        // Send query to Delegate...method immediately starts the synchronization process
        // and also pushes the delegate onto screen
        MzSearchItem *searchItem = [self createSearchItemFromQuery:query andCategory:self.categoryButton.titleLabel.text];
        assert(self.delegate != nil);
        [self.delegate controller:self addSearchItem:searchItem];
        
        // Add MzSearchItem to MzSearchCollection
        MzSearchCollection *scollection = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] searchCollection];
        assert(scollection != nil);
        [scollection addSearchItem:searchItem];
    }
    // resign UISearchBar form being First Responder
    [searchesBar resignFirstResponder];
}

// User finished entering query
-(void) searchBarTextDidEndEditing:(UISearchBar *)searchesBar
{
    // resign UISearchBar form being First Responder
    [searchesBar resignFirstResponder];
}

// Create a MzSearchItem from the user's query
-(MzSearchItem *) createSearchItemFromQuery:(NSString *)queryStr andCategory:(NSString *)categoryStr
{
    MzSearchItem *searchItem = nil;
    if (queryStr != nil && categoryStr != nil) {
        
        searchItem = [[MzSearchItem alloc] init];        
        //set the search Properties
        searchItem.searchTitle = kDefaultSearchItemTitle;
        searchItem.searchStatus = SearchItemStateInProgress;
        searchItem.searchTimestamp = [NSDate date];
        searchItem.daysToSearch = [NSNumber numberWithInt:0];
        searchItem.priceToSearch = [NSNumber numberWithDouble:0.0];
        
        // set the search Options
        NSDictionary *searchDict;
        //queryType = self.includeQuery ? kQueryTypeInclude : kQueryTypeExclude;
        searchDict = [NSDictionary dictionaryWithObjectsAndKeys:queryStr, kSearchItemKeywords,
                      categoryStr, kSearchItemCategory, nil];
        searchItem.searchOptions = [NSDictionary dictionaryWithDictionary:searchDict];
        
        // add the new MzSearchItem to the MzSearchCollection
        MzSearchCollection *searchCollection = [[MzSearchCollection alloc] init];
        BOOL success = [searchCollection addSearchCollection];
        if (success) {
            [searchCollection addSearchItem:searchItem];
        } else {
            [[QLog log] logWithFormat:@"Failed to add new MzSearchItem to MzSearchCollection with Query: %@", queryStr];
        }        
    }
    return searchItem;
}

// User cancelled entering query
-(void) searchBarCancelButtonClicked:(UISearchBar *)searchesBar
{
    assert(self.searchBar != nil);
    [searchesBar resignFirstResponder];
}

@end
