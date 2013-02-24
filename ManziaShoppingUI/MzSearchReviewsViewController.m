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
#import "MzQualityCollection.h"

@interface MzSearchReviewsViewController ()

@property (nonatomic, strong) NSFetchedResultsController *fetchController;
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
//@property (nonatomic, strong) NSFetchedResultsController *fetchQualityController;
@property (nonatomic, strong) MzQualityCollection *qualityCollection;

// Stores the Product Qualities added to the Query by the User
@property (nonatomic, strong) NSMutableArray *usersQualities;

// Stores all the available for selection to the User
@property (nonatomic, strong) NSMutableArray *allQualities;

// Alerts User to select a Category to start
@property (nonatomic, strong) UIAlertView *searchAlert;

// Keeps track of the current UISegmentedControl segment, this is necessary to capture
// the case of where the User taps the same segment consecutively which will not fire
// the ValueChanged event
@property (nonatomic, assign) NSUInteger currentSegmentIdx;
@property (nonatomic, assign) BOOL sameSegmentTapped;

@end

@implementation MzSearchReviewsViewController

// Synthesizers
//@synthesize categoryButton;
@synthesize pickerView;
@synthesize searchBar;
@synthesize fetchController;
@synthesize mainMenu;
//@synthesize fetchQualityController;
@synthesize qualityCollection;
@synthesize usersQualities;
@synthesize allQualities;
@synthesize searchAlert;
@synthesize currentSegmentIdx;
@synthesize sameSegmentTapped;

// Database entity that we fetch from
static NSString *kTaskTypeEntity = @"MzTaskType";
static NSString *kTaskAttributeEntity = @"MzTaskAttribute";

// SearchItem Keys
static NSString *kSearchItemKeywordFormat = @"q%@";
static NSString *kSearchItemCategory = @"Category";
static NSString *kDefaultSearchItemTitle = @"No Title";
static NSString *kDefaultCategoryButtonString = @"Select Category";

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
    
    // We can now initialize our NSFetchedResultsController for the Categories
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
    self.fetchController.delegate = self;
    
    // Execute the fetch
    NSError *error = NULL;
    [self.fetchController performFetch:&error];
    
    // Error-checking
    if (error) {
        
        //Log
        [[QLog log] logWithFormat:@"Error fetching Categories to display from TaskTypes Entity: %@", error.localizedDescription];
        self.fetchController = nil;
    }
    
     // Set up the MzQualityCollection
    self.qualityCollection = [[MzQualityCollection alloc] init];
    assert(self.qualityCollection != nil);
    [self.qualityCollection addQualityCollection];
    
    // Set up the allQualities array
    self.allQualities = [NSMutableArray array];
    assert(self.allQualities != nil);
    self.usersQualities = [NSMutableArray array];
    //[[QLog log] logWithFormat:@"Qualities available for User Selection: %d ", [self.allQualities count]];
    
    // Set up the categoryButton
    //assert(self.categoryButton != nil);
    //[self.categoryButton addTarget:self action:@selector(selectCategory) forControlEvents:UIControlEventTouchUpInside];
    
    // Set up the UISearchBar
    assert(self.searchBar != nil);
    self.searchBar.delegate = self;
    self.searchBar.showsCancelButton = YES;
    
    // Add a Left "Add" Button to the UISearchBar
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithTitle:@"Add" style:UIBarButtonItemStyleBordered target:self action:@selector(addQualityTapped)];
    UIBarButtonItem *addSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIToolbar *toolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(10,133,290,45)];
    toolbar.barStyle = UIBarStyleBlackTranslucent;
        
    [toolbar setItems:[NSArray arrayWithObjects:addButton, addSpacer, nil] animated:NO];
    [self.view addSubview:toolbar];
    [self.view bringSubviewToFront:self.searchBar];
       
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
    
    // Set up the search Alert
    self.searchAlert = [[UIAlertView alloc] initWithTitle:@"Required" message:@"Select a Category to Start" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    assert(self.searchAlert != nil);
    
    // Initialize the initial segmentIndex to a "large" number that is impractical
    self.currentSegmentIdx = 1000;
    self.sameSegmentTapped = NO;   
}

// Release iVars
-(void) viewDidUnload
{
    self.managedContext = nil;
    self.fetchController = nil;
    //self.fetchQualityController = nil;
    self.searchBar.delegate = nil;
    self.qualityCollection = nil;
    self.usersQualities = nil;
    self.allQualities = nil;
    self.searchAlert = nil;
}

// View Lifecycle
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Keep the UIPickerView hidden until user taps the Select Category or Select Quality segments
    assert(self.pickerView != nil);
    self.pickerView.hidden = YES;    
}


#pragma mark * UIPickerView DataSource Methods

// Fetches the pre-defined product qualities from Core Data and returns an NSArray of NSString with quality strings
-(NSArray *)fetchQualitiesForCategory:(NSString *)quality
{
    // We can now initialize our NSFetchedResultsController for the Qualities
    assert(quality != nil);
    NSFetchRequest *qualityRequest = [NSFetchRequest fetchRequestWithEntityName:kTaskAttributeEntity];
    assert(qualityRequest != nil);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"taskType.taskTypeName like[c] %@", quality];
    NSSortDescriptor *sortQuality = [[NSSortDescriptor alloc] initWithKey:@"taskAttributeName" ascending:YES];
    NSArray *sortQualities = [NSArray arrayWithObject:sortQuality];
    [qualityRequest setSortDescriptors:sortQualities];
    [qualityRequest setPredicate:predicate];
    
    // Execute the fetch
    NSError *qualityError = NULL;
    NSArray *availableQualities = [self.managedContext executeFetchRequest:qualityRequest error:&qualityError];
    assert(availableQualities != nil);
    //[self.fetchQualityController performFetch:&qualityError];
    
    // Error-checking
    if (qualityError) {
        
        //Log
        [[QLog log] logWithFormat:@"Error fetching Qualities to display from TaskAttributes Entity: %@", qualityError.localizedDescription];        
    }
    return [availableQualities valueForKey:@"taskAttributeName"];
}

// UIPickerView component count = 1
-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// UIPickerView row count per component
-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    // we return the row count based on which Segment in the UISegmentedControl is selected
    NSUInteger menuIndex = [self.mainMenu selectedSegmentIndex];
    NSUInteger rowCount = 0;
    
    switch (menuIndex) {
        case 0:
            // we return zero rows if we did not fetch any MzTaskTypes from the database
            if (self.fetchController != nil) {
                rowCount = [[self.fetchController fetchedObjects] count];
            } else {
                rowCount = 0;
            }
            break;
        case 1:
            // we return zero rows if we did not fetch any MzTaskAttributes from the database
            if (self.allQualities != nil) {
                //rowCount = [[self.fetchQualityController fetchedObjects] count];
                //NSArray *qualitiesArray = [self.qualityCollection allProductQualities];
                //assert(qualitiesArray != nil);
                NSString *selectedCategory = [self.mainMenu titleForSegmentAtIndex:0];
                assert(selectedCategory != nil);
                assert(![selectedCategory isEqualToString:kDefaultCategoryButtonString]);
                NSArray *categoryQualities = [self fetchQualitiesForCategory:selectedCategory];
                assert(categoryQualities != nil);
                if (!sameSegmentTapped) {
                    [self.allQualities addObjectsFromArray:categoryQualities];
                    [self.allQualities addObjectsFromArray:[self.qualityCollection allProductQualities]];
                }                
                rowCount = [self.allQualities count];
                [[QLog log] logWithFormat:@"Qualities available for User Selection: %d for Category: %@", rowCount, selectedCategory];
            } else {
                rowCount = 0;
            }
            break;
            default:
            rowCount = 0;
            break;
    }
    return rowCount;
}

#pragma mark * UIPickerView Delegate Methods

// Return the appropriate category/quality
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    // Return the Title based on which Segment in the MainMenu UISegmentedControl is selected
    NSUInteger menuIndex = [self.mainMenu selectedSegmentIndex];
    NSString *rowTitle;
    
    switch (menuIndex) {
        case 0:
        {
            assert(self.fetchController != nil);
            NSArray *categories = [[self.fetchController fetchedObjects] valueForKey:@"taskTypeName"];
            assert(categories != nil);
            rowTitle = [categories objectAtIndex:row];
        }
            break;
        case 1:
        {
            assert(self.allQualities != nil);
            rowTitle = [self.allQualities objectAtIndex:row];
        }
            break;
            
        default:
            break;
    }
    return rowTitle;
    
}

// Respond to a selection
- (void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    NSUInteger menuIndex = [self.mainMenu selectedSegmentIndex];
    NSString *currentTitle = [self.mainMenu titleForSegmentAtIndex:menuIndex];
    assert(currentTitle != nil);
    
    switch (menuIndex) {
        case 0:
        {// Assign the selected String to the "Select Category" segment
            assert(self.fetchController != nil);
            NSArray *categories = [[self.fetchController fetchedObjects] valueForKey:@"taskTypeName"];
            assert(categories != nil);
            NSString *selectedCategory = [categories objectAtIndex:row];
            assert(selectedCategory != nil);
            
            // if we are changing from Category to another we "clear" all the Arrays dealing with Qualities
            // since these are all Category-specific
            if (![currentTitle isEqualToString:kDefaultCategoryButtonString]) {
                [self.allQualities removeAllObjects];
                [self.usersQualities removeAllObjects];
            }
            [self.mainMenu setTitle:selectedCategory forSegmentAtIndex:menuIndex];
            //[self.categoryButton setTitle:selectedCategory forState:UIControlStateNormal];
            
            // Dismiss the UIPickerView from view
            self.pickerView.hidden = YES;
        }
            break;
        case 1:
        {// Add quality to List of selected Qualities to display modally and notify User
            assert(self.usersQualities != nil);
            assert([self.allQualities count] > 0);
            NSString *selectedQuality = [self.allQualities objectAtIndex:row];
            assert(selectedQuality != nil);
            [self.usersQualities addObject:selectedQuality];
            
            // Dismiss the UIPickerView from view
            self.pickerView.hidden = YES;
            
            // Add the selected Quality to the UISearchBar
            self.searchBar.text = selectedQuality;
            
            // Notify User
            [self userQualityNotification];
        }
            break;
            
        default:
            break;
    }
    
}

// Bring up the UIPickerView if its hidden otherwise if its already on screen then dismiss it
-(IBAction)selectedMainMenu:(id)sender
{
    assert(self.pickerView != nil);
    
    // ensure that User first taps Select a Category
    assert([sender isKindOfClass:[UISegmentedControl class]]);
    UISegmentedControl *menu = (UISegmentedControl *)sender;
    NSUInteger selectedIndex = [menu selectedSegmentIndex];
    
    if (selectedIndex > 0) {
        if ([[menu titleForSegmentAtIndex:0] isEqualToString:kDefaultCategoryButtonString]) {
            
            // Display alert
            [self.searchAlert show];
        } else {
            // Reload the UIPickerView and call dataSource methods
            [self.pickerView reloadAllComponents];
        }
    } else {
        [self.pickerView reloadAllComponents];
    }
    
    if (self.pickerView.hidden) {
        self.pickerView.hidden = NO;
    } else {
        self.pickerView.hidden = YES;
    }
}

// Main Menu tapped
-(IBAction)tappedMainMenu:(id)sender
{
    assert(self.pickerView != nil);
    assert([sender isKindOfClass:[UISegmentedControl class]]);
    UISegmentedControl *menu = (UISegmentedControl *)sender;
    NSUInteger newIndex = [menu selectedSegmentIndex];
    
    if (newIndex == self.currentSegmentIdx) {
        self.sameSegmentTapped = YES;
        // User has tapped the same segment again so
        // 1- show the UIPickerView if not already on screen
        // 2- do step 1 above for all segments except the last
        // Note that if the user makes a selection the UIPickerView is dismissed
        if (newIndex != ([self.mainMenu numberOfSegments] - 1)) {
            if (self.pickerView.hidden) {
                self.pickerView.hidden = NO;
            }
        }
        
    } else {
        // Update the segment Index
        self.currentSegmentIdx = newIndex;
        self.sameSegmentTapped = NO;
    }    
}

#pragma mark * Product Qualities

// Notify the User that a quality has been added and also provide instructions on how to proceed
-(void)userQualityNotification
{
    
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

// User has the tapped the Add button next to the UISearchBar so we:
// 1- clear the text in the SearchBar
// 2- bring up the UIPickerView
-(void)addQualityTapped
{
    assert(self.searchBar != nil);
    self.searchBar.text = nil;
    if (self.pickerView.hidden) {
        self.pickerView.hidden = NO;
    }
}

// Verify that the User has selected a Category before they can enter a Query
-(BOOL) searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    assert(self.mainMenu != nil);
    if ([[self.mainMenu titleForSegmentAtIndex:0] isEqualToString:kDefaultCategoryButtonString]) {
        
        // Display alert
        [self.searchAlert show];
        
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
        assert(self.usersQualities != nil);
        MzSearchItem *searchItem = [self createSearchItemFromQuery:self.usersQualities andCategory:[self.mainMenu titleForSegmentAtIndex:0]];
        assert(self.delegate != nil);
        [self.delegate controller:self addSearchItem:searchItem];
        
        // Add MzSearchItem to MzSearchCollection
        MzSearchCollection *scollection = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] searchCollection];
        assert(scollection != nil);
        [scollection addSearchItem:searchItem];
        
        // resign UISearchBar form being First Responder
        [searchesBar resignFirstResponder];
        
        // Switch to the Results ViewController Hierarchy
        self.tabBarController.selectedIndex = 1;
    } else {
        
        // resign UISearchBar form being First Responder but nothing else
        [searchesBar resignFirstResponder];
    }    
}

// User finished entering query
-(void) searchBarTextDidEndEditing:(UISearchBar *)searchesBar
{
    // resign UISearchBar form being First Responder
    [searchesBar resignFirstResponder];
}

// Create a MzSearchItem from the user's query
// We set the MzSearchItem searchTitle property to the user-selected Category
-(MzSearchItem *) createSearchItemFromQuery:(NSArray *)queryStr andCategory:(NSString *)categoryStr
{
    MzSearchItem *searchItem = nil;
    if (queryStr != nil && categoryStr != nil && [queryStr count] > 0) {
        
        searchItem = [[MzSearchItem alloc] init];        
        //set the search Properties
        searchItem.searchTitle = [categoryStr copy];
        searchItem.searchStatus = SearchItemStateInProgress;
        searchItem.searchTimestamp = [NSDate date];
        searchItem.daysToSearch = [NSNumber numberWithInt:0];
        searchItem.priceToSearch = [NSNumber numberWithDouble:0.0];
        
        // create the subQueries from the selected Qualities
        NSMutableDictionary *searchDict = [NSMutableDictionary dictionary];
        [queryStr enumerateObjectsUsingBlock:^(NSString *query, NSUInteger idx, BOOL *stop) {
            [searchDict setObject:query forKey:[NSString stringWithFormat:kSearchItemKeywordFormat, [[NSNumber numberWithInt:idx]stringValue ]]];
        }];
        
        // set the other Search Options
        [searchDict setObject:categoryStr forKey:kSearchItemCategory];
        searchItem.searchOptions = [NSDictionary dictionaryWithDictionary:searchDict];
        
        // add the new MzSearchItem to the MzSearchCollection
        MzSearchCollection *searchCollection = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] searchCollection];
        BOOL success = searchCollection != nil;
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
    
    // Extend the Cancel button to dismiss the UIPickerView in the case
    // where the User has brought it up but decided not to make a selection
    if (self.pickerView.hidden = NO) {
        self.pickerView.hidden = YES;
    }
}

@end
