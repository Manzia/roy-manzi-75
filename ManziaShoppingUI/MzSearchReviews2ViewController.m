//
//  MzSearchReviews2ViewController.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 3/27/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzSearchReviews2ViewController.h"
#import "MzTaskCollection.h"
#import "Logging.h"
#import "MzResultsListViewController.h"
#import "MzSearchCollection.h"
#import "MzAppDelegate.h"
#import "MzQualityCollection.h"
#import "MzSearchSegmentedControl.h"
#import "MzQualitiesListViewController.h"
#import <QuartzCore/QuartzCore.h>

// UILabel Frame
#define LABEL_X 0
#define LABEL_Y 0
#define LABEL_WIDTH_FACTOR 7.5
#define LABEL_HEIGHT 40
#define LABEL_SPACING 15


@interface MzSearchReviews2ViewController ()

@property (nonatomic, strong) NSFetchedResultsController *fetchController;
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
//@property (nonatomic, strong) NSFetchedResultsController *fetchQualityController;
@property (nonatomic, strong) MzQualityCollection *qualityCollection;

// Stores the Product Qualities added to the Query by the User
@property (nonatomic, strong) NSMutableArray *usersQualities;

// Array that stores saved Qualities retrieved from the Qualities Directory in the Local Cache
@property (nonatomic, strong) NSArray *savedQualities;

// Stores all the available for selection to the User
@property (nonatomic, strong) NSMutableArray *allQualities;

// Alerts User to select a Category to start
@property (nonatomic, strong) UIAlertView *searchAlert;

// Keeps track of the current UISegmentedControl segment, this is necessary to capture
// the case of where the User taps the same segment consecutively
@property (nonatomic, assign) NSInteger currentSegmentIdx;
@property (nonatomic, assign) BOOL sameSegmentTapped;

// Keeps track of when the User taps and selects the same Category, this is necessary
// to prevent duplicating the category-specific qualities shown in the UIPickerView
@property (nonatomic, assign) BOOL categoryHasChanged;
@property (nonatomic, copy) NSString *currentCategory;

// Keeps track of the Maximum X-value of the UILabel subviews in the UIScrollView property
//@property (nonatomic, assign) CGFloat maxLabelsX;

// Custom Ranking Button that brings up the MzResultsListViewController
//@property (nonatomic, strong) UIButton *rankingButton;

@end

@implementation MzSearchReviews2ViewController

// Synthesizers
//@synthesize categoryButton;
@synthesize pickerView;
@synthesize textView;
@synthesize fetchController;
@synthesize mainMenu;
//@synthesize fetchQualityController;
@synthesize qualityCollection;
@synthesize usersQualities;
@synthesize allQualities;
@synthesize searchAlert;
@synthesize currentSegmentIdx;
@synthesize sameSegmentTapped;
@synthesize savedQualities;
@synthesize categoryHasChanged;
@synthesize currentCategory;
@synthesize delegate;
@synthesize qualityDelegate;
//@synthesize textGuide;
//@synthesize maxLabelsX;
//@synthesize rankingButton;

// Database entity that we fetch from
static NSString *kTaskTypeEntity = @"MzTaskType";
static NSString *kTaskAttributeEntity = @"MzTaskAttribute";

// SearchItem Keys
static NSString *kSearchItemKeywordFormat = @"q%@";
static NSString *kSearchItemCategory = @"Category";
//static NSString *kDefaultSearchItemTitle = @"No Title";
//static NSString *kDefaultCategoryButtonString = @"Select Category";

// Push Segue
//static NSString *kQualitiesDetailPushSegue = @"kQualitiesDetailSegue";

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
        
        //Log and exit
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
    
    // Set up the Qualities related arrays
    self.allQualities = [NSMutableArray array];
    assert(self.allQualities != nil);
    self.usersQualities = [NSMutableArray array];
    self.savedQualities = [self.qualityCollection allProductQualities];
    
    
    /* Set up the UISearchBar
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
    [self.view bringSubviewToFront:self.searchBar]; */
    
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
                                           [MzResultsListViewController conformsToProtocol:@protocol(MzSearchReviews2ViewControllerDelegate)]) {
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
    
    // Initialize Segment Tracking
    self.currentSegmentIdx = -1;
    self.sameSegmentTapped = NO;
    self.mainMenu.selectedSegmentIndex = -1;
    self.categoryHasChanged = NO;
    self.currentCategory = [NSString string];
    
    // Set Self as delegate to textView
    assert(self.textView != nil);
    self.textView.delegate = self;
    //self.maxLabelsX = 0.0f;
    
    /* Create and configure the Rank UIButton
    CGRect buttonFrame = CGRectMake(BUTTON_X, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT);
    UIButton *rankButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rankButton.frame = buttonFrame;
    [rankButton setBackgroundColor:[UIColor darkGrayColor]];
    [rankButton setTitle:@"Rank" forState:UIControlStateNormal];
    [rankButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    rankButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    rankButton.titleLabel.shadowOffset = CGSizeMake (1.0, 0.0);
    rankButton.userInteractionEnabled = YES;
    rankButton.layer.borderColor = [UIColor blackColor].CGColor;
    rankButton.layer.borderWidth = 0.5f;
    rankButton.layer.cornerRadius = 10.0f;
    [rankButton addTarget:self action:@selector(rankButtonSelected) forControlEvents:UIControlEventTouchUpInside];
    self.rankingButton = rankButton;
    [self.view addSubview:self.rankingButton]; */
}

// Release iVars
-(void) viewDidUnload
{
    self.managedContext = nil;
    self.fetchController = nil;
    //self.fetchQualityController = nil;
    self.textView = nil;
    self.qualityCollection = nil;
    self.usersQualities = nil;
    self.allQualities = nil;
    self.searchAlert = nil;
    self.savedQualities = nil;
    //self.rankingButton = nil;
}

// View Lifecycle
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Keep the UIPickerView hidden until user taps the Select Category or Select Quality segments
    assert(self.pickerView != nil);
    self.pickerView.hidden = YES;
    //self.textGuide.hidden = YES;
}

// Animate the UILabel textGuide
-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    /* Setup Animation
    NSTimeInterval delay = 1.0;
    NSTimeInterval duration = 1.0;
    assert(self.textGuide != nil);
    
    [UIView animateWithDuration:duration delay:delay options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        
        self.textGuide.hidden = NO;
        
    }completion:^(BOOL finished) {
        
    }]; */
}

// Rotation
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return  interfaceOrientation == UIInterfaceOrientationPortrait ? YES : NO;
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
                //NSString *selectedCategory = [self.mainMenu titleForSegmentAtIndex:0];
                //assert(selectedCategory != nil);
                //assert(![selectedCategory isEqualToString:kDefaultCategoryButtonString]);
                assert([self.currentCategory length] > 0);
                NSArray *categoryQualities = [self fetchQualitiesForCategory:self.currentCategory];
                assert(categoryQualities != nil);
                if (!self.sameSegmentTapped && self.categoryHasChanged) {
                    [self.allQualities addObjectsFromArray:categoryQualities];
                    if (self.savedQualities != nil) {
                        [self.allQualities addObjectsFromArray:self.savedQualities];
                    }
                }
                if ([self.allQualities count] == 0) {
                    [self.allQualities addObjectsFromArray:categoryQualities];
                    if (self.savedQualities != nil) {
                        [self.allQualities addObjectsFromArray:self.savedQualities];
                    }
                }
                rowCount = [self.allQualities count];
                [[QLog log] logWithFormat:@"Qualities available for User Selection: %d for Category: %@", rowCount, self.currentCategory];
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
    //NSString *currentTitle = [self.mainMenu titleForSegmentAtIndex:menuIndex];
    //assert(currentTitle != nil);
    
    switch (menuIndex) {
        case 0:
        {// Assign the selected String to the "Select Category" segment
            assert(self.fetchController != nil);
            NSArray *categories = [[self.fetchController fetchedObjects] valueForKey:@"taskTypeName"];
            assert(categories != nil);
            NSString *selectedCategory = [categories objectAtIndex:row];
            assert(selectedCategory != nil);
            
            // Track and Manage Category changes
            self.categoryHasChanged = [selectedCategory isEqualToString:self.currentCategory] ? NO : YES;
            
            // if we are changing from Category to another
            // 1- clear all the Arrays dealing with Qualities since these are category-specific
            // 2- clear the text from the UITextView
            if (self.categoryHasChanged) {
                [self.allQualities removeAllObjects];
                if ([self.textView.text length] > 0) {
                    self.textView.text = nil;
                }
                //self.maxLabelsX = 0.0f;
                
                // Add category String to our TextView
                self.textView.text = selectedCategory;                
            }            
            
            // Update the current Category
            self.currentCategory = selectedCategory;
            
            // Dismiss the UIPickerView from view
            self.pickerView.hidden = YES;
            self.mainMenu.selectedSegmentIndex = -1;
        }
            break;
        case 1:
        {// Add quality to List of selected Qualities to display modally and notify User
            assert(self.usersQualities != nil);
            assert([self.allQualities count] > 0);
            NSString *selectedQuality = [self.allQualities objectAtIndex:row];
            assert(selectedQuality != nil);
            [self.usersQualities addObject:selectedQuality];
            
            // Append the added Quality to the textView
            NSString *textViewStr = self.textView.text;
            assert(textViewStr != nil);
            self.textView.text = [NSString stringWithFormat:@"%@  %@", textViewStr, selectedQuality];
            
            // Dismiss the UIPickerView from view
            self.pickerView.hidden = YES;
            self.mainMenu.selectedSegmentIndex = -1;
            
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
    assert([sender isKindOfClass:[MzSearchSegmentedControl class]]);
    UISegmentedControl *menu = (MzSearchSegmentedControl *)sender;
    NSUInteger selectedIndex = [menu selectedSegmentIndex];
    //NSString *newCategory = [menu titleForSegmentAtIndex:0];
    
    // Tracking
    self.sameSegmentTapped = selectedIndex == self.currentSegmentIdx ? YES : NO;
    //self.categoryHasChanged = [newCategory isEqualToString:self.currentCategory] ? NO : YES;
    
    // Logic
    switch (selectedIndex) {
        case 0:
            [self.pickerView reloadAllComponents];
            self.pickerView.hidden = self.pickerView.hidden ? NO : YES;
            break;
        case 1:
            if (![self.textView.text length] > 0) {
                // Display alert
                [self.searchAlert show];
            } else {
                // Reload the UIPickerView and call dataSource methods
                [self.pickerView reloadAllComponents];
                self.pickerView.hidden = self.pickerView.hidden ? NO : YES;
            }
            break;
        /*case 2:
            if ([[menu titleForSegmentAtIndex:0] isEqualToString:kDefaultCategoryButtonString]) {
                // Display alert
                [self.searchAlert show];
            } else {
                // User selected the last segment
                [self performSegueWithIdentifier:kQualitiesDetailPushSegue sender:self];
            } */
        default:
            break;
    }
    
    // Remove all Qualities for the userQualities array thats "Pushed" to the MzQualitiesViewController
    if (self.categoryHasChanged) {
        
        [self.usersQualities removeAllObjects];
        [self.pickerView reloadAllComponents];
    }
    
    // Update the Segment Trackers
    self.currentSegmentIdx = selectedIndex;
    //self.currentCategory = newCategory;
}

// Helper method to dismiss UIPickerView
-(void)dismissPickerView
{
    assert(self.pickerView != nil);
    self.pickerView.hidden = YES;
}

#pragma mark * Product Qualities

// Send Query to MzResultsListViewController
-(IBAction)rankButtonSelected:(id)sender
{
    
    // Send query to Delegate...method immediately starts the synchronization process
    // and also pushes the delegate onto screen
    assert(self.usersQualities != nil);
    
    if ([self.usersQualities count] > 0) {
        MzSearchItem *searchItem = [self createSearchItemFromQuery:self.usersQualities andCategory:self.currentCategory];
        assert(self.delegate != nil);
        [self.delegate controller:self addSearchItem:searchItem];
        
        // Add MzSearchItem to MzSearchCollection
        MzSearchCollection *scollection = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] searchCollection];
        assert(scollection != nil);
        [scollection addSearchItem:searchItem];
        
        // Disable the Rank Button so that User cannot re-rank using the same qualities. The Rank Button is re-enabled for
        // user interactions when the Add Button is tapped and a quality is added
        //self.rankingButton.userInteractionEnabled = NO;
        
        // Switch to the Results ViewController Hierarchy and Activate the Results Tab BarItem
        UITabBarItem *resultsTabBar = [[[self.tabBarController viewControllers] objectAtIndex:1] tabBarItem];
        assert(resultsTabBar != nil);
        resultsTabBar.enabled = YES;
        self.tabBarController.selectedIndex = 1;
        
    } else {
        
        // Send User an Alert
        UIAlertView *rankAlert = [[UIAlertView alloc] initWithTitle:@"No Product Qualities" message:@"Select a Quality or Enter a Quality in the SearchBar" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        assert(rankAlert != nil);
        [rankAlert show];
        
    }    
    
}


/* Push the ViewController that will display the Qualities
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:kQualitiesDetailPushSegue]) {
        MzQualitiesListViewController *qualityController = [segue destinationViewController];
        assert(qualityController != nil);
        qualityController.qualityArray = [[NSArray alloc] initWithArray:self.usersQualities];
        qualityController.qCollection = self.qualityCollection;
        self.qualityDelegate = qualityController;
    }
    
}*/

#pragma mark * Memory Management

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark * TextView Delegate methods

// Generate a new UILable for every selection the User makes in the UIPickerView. This label
/* will be displayed in the UIScrollView.
-(UILabel *)generateLabel:(NSString *)labelTitle
{
    assert(labelTitle != nil);
    CGFloat labelWidth = [labelTitle length] * LABEL_WIDTH_FACTOR;
    CGRect labelFrame = CGRectMake(LABEL_X, LABEL_Y, labelWidth, LABEL_HEIGHT);
    UILabel *addLabel = [[UILabel alloc] initWithFrame:labelFrame];
    addLabel.text = labelTitle;
    addLabel.textAlignment = UITextAlignmentLeft;
    addLabel.textColor = [UIColor purpleColor];
    addLabel.font = [UIFont systemFontOfSize:13.0f];
    addLabel.userInteractionEnabled = NO;
    addLabel.lineBreakMode = UILineBreakModeTailTruncation;
    //addLabel.backgroundColor = [UIColor lightGrayColor];
    return addLabel;
} */

#pragma mark * Search Query Management

// User has the tapped the Add button next to the UISearchBar so we:
// 1- clear the text in the SearchBar
// 2- bring up the UIPickerView
// 3- enable the Rank Button if its disabled
/*-(void)addQualityTapped
{
    // dismiss PickerView
    [self dismissPickerView];
    
    assert(self.searchBar != nil);
    assert(self.usersQualities != nil);
    
    // If the SearchBar is empty do nothing and return
    if (self.searchBar.text == nil || [self.searchBar.text length] < 1 ) return;
    
    NSSet *checkDups;
    NSString *query = [[NSString alloc] initWithString:self.searchBar.text];
    if (query != nil && [query length] > 0) {
        
        // Check for duplicates before we add to the Array
        checkDups = [NSSet setWithArray:self.usersQualities];
        assert(checkDups != nil);
        if ([checkDups member:query] == nil) {
            
            [self.usersQualities addObject:query];
        }
        //NSLog(@"Query added to Array: %@", query);    //testing
    }
    // clear SearchBar
    self.searchBar.text = nil;
    
    
    // Notify User
    [self userQualityNotification];
    
    // Enable Rank Button
    // We can enable the Rank Button since at this point we are sure we have at least one
    // quality in the usersQualities array
    self.rankingButton.userInteractionEnabled = YES;
} */

// Verify that the User has selected a Category before they can enter a Query
/*-(BOOL) searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    // dismiss PickerView
    [self dismissPickerView];
    
    assert(self.mainMenu != nil);
    if ([[self.mainMenu titleForSegmentAtIndex:0] isEqualToString:kDefaultCategoryButtonString]) {
        
        // Display alert
        [self.searchAlert show];
        
        return NO;
    } else {
        return YES;
    }
} */

// Respond to the User's selection on the UIAlertView
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonsIndex
{
    // We don't do anything
    return;
}

/* User is going to enter the query
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
        [self.usersQualities addObject:query];      // Add new Query
        MzSearchItem *searchItem = [self createSearchItemFromQuery:self.usersQualities andCategory:[self.mainMenu titleForSegmentAtIndex:0]];
        assert(self.delegate != nil);
        [self.delegate controller:self addSearchItem:searchItem];
        
        // Add MzSearchItem to MzSearchCollection
        MzSearchCollection *scollection = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] searchCollection];
        assert(scollection != nil);
        [scollection addSearchItem:searchItem];
        
        // resign UISearchBar form being First Responder
        [searchesBar resignFirstResponder];
        
        // Switch to the Results ViewController Hierarchy and Activate the Results Tab BarItem
        UITabBarItem *resultsTabBar = [[[self.tabBarController viewControllers] objectAtIndex:1] tabBarItem];
        assert(resultsTabBar != nil);
        resultsTabBar.enabled = YES;
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
} */

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

/* User cancelled entering query
-(void) searchBarCancelButtonClicked:(UISearchBar *)searchesBar
{
    // dismiss PickerView
    [self dismissPickerView];
    
    assert(self.searchBar != nil);
    [searchesBar resignFirstResponder];
    
} */


@end
