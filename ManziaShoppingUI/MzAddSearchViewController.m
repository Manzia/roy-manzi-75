//
//  MzAddSearchViewController.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/13/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzAddSearchViewController.h"
#import "Logging.h"
#import <CoreData/CoreData.h>
#import "MzTaskCollection.h"
#import "MzTaskAttribute.h"
#import "MzAddSearchCell.h"
#import "MzAttributeOptionViewController.h"
#import "MzSearchItem.h"
#import <QuartzCore/QuartzCore.h>

// Constants
#define kSearchButtonsPerCell 3

@interface MzAddSearchViewController ()

// Model properties
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@property (nonatomic, strong) NSFetchedResultsController *fetchController;
@property (nonatomic, assign) BOOL fetchSucceeded;
@property(nonatomic, strong) id <NSFetchedResultsSectionInfo> currentSection;
//@property (nonatomic, strong) MzAddSearchHeaderView *searchHeaderView;

// TableView, TableViewCell properties
@property (nonatomic, strong) IBOutlet MzAddSearchCell *addSearchCell;

// Property below represents the currently selected button
// in one of the tableViewCells
@property (nonatomic, strong) UIButton *currentButton;

//Property below represents the position of the button tapped
@property (nonatomic, assign) NSUInteger buttonIndex;

//Property below represents the attributeOption string value that the user
// selects from the View Controller (tableView) that we present modally, we use
// delegation to set this value
@property (nonatomic, copy) NSString *attributeOption;

// Property below represents the sub-category that is presently selected
// in the tableViewHeader. The value of this property determines which
// search options are displayed on the buttons in the tableView
@property (nonatomic, strong) NSString *currentSectionName;

//Property below represents the search criteria selected by the user
@property (nonatomic, strong) MzSearchItem *searchItem;

// Property below keeps track of all the selections of the user, i.e the
// attributeOptions selected from the modally presented viewController
// for each taskAttribute
@property (nonatomic, strong) NSMutableOrderedSet *selectedOptions;


@end

@implementation MzAddSearchViewController

@synthesize managedContext;
@synthesize fetchController;
@synthesize currentButton;
@synthesize fetchSucceeded;
@synthesize currentSectionName;
@synthesize delegate;
@synthesize addSearchCell;
@synthesize currentSection;
@synthesize attributeOption;
@synthesize searchItem;
@synthesize buttonIndex;
@synthesize selectedOptions;

// Database entity that we fetch from
static NSString *kTaskAttributeEntity = @"MzTaskAttribute";

// Modal segue to the attributeOptions
static NSString *kAttributeOptionSegue = @"kAttributeOptionSegue";

// No option symbol
static NSString *kAttributeFillerString = @"...";

// Brand Attribute
static NSString *kBrandAttribute = @"Brand";
static NSString *kAllBrandsAttribute = @"All";

/*
 When the "Add Search" button in the tableHeaderView of the
 MzSearchListViewController is tapped, a Segue is fired that then instantiates
 an instance of MzAddSearchViewController which is then pushed on screen via a 
 Navigation Controller.
 */

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        
        // Custom initialization - 
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
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
    NSFetchRequest *mrequest = [NSFetchRequest fetchRequestWithEntityName:kTaskAttributeEntity];
    assert(mrequest != nil);
    [mrequest setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"taskType"]];
    NSSortDescriptor * sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"taskAttributeId" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    [mrequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *controller = [[NSFetchedResultsController alloc] initWithFetchRequest:mrequest managedObjectContext:self.managedContext sectionNameKeyPath:@"taskType.taskTypeName" cacheName:nil];
    assert(controller != nil);
    self.fetchController = controller;
    
    // Execute the fetch
    NSError *error = NULL;
    self.fetchSucceeded = [self.fetchController performFetch:&error];
        
    // Log success
    if (self.fetchSucceeded) {
        [[QLog log] logWithFormat:@"Success: Fetched %d objects from the Task Collection data store", [[self.fetchController fetchedObjects] count]];
    }
        
    //Log error
    if (error) {
        [[QLog log] logWithFormat:@"Error fetching from TaskAttribute Entity with error: %@", error.localizedDescription];
    }
    
    // initialize our tableView HeaderView
    CGRect headerViewRect = CGRectMake(0, 0, 320, 110);
    MzAddSearchHeaderView *searchHeaderView = [[MzAddSearchHeaderView alloc] initWithFrame:headerViewRect delegate:self];
    assert(searchHeaderView != nil);
    searchHeaderView.backgroundColor = [UIColor lightGrayColor];
    
    // Set self as delegate for the Preferred Price UITextField
    searchHeaderView.priceField.delegate = self;
    self.tableView.tableHeaderView = searchHeaderView;
    
    // Initialize the MzSearchItem we shall send back to our MzSearchListViewController delegate
    MzSearchItem *tempSearchItem = [[MzSearchItem alloc] init];
    assert(tempSearchItem != nil);
    self.searchItem = tempSearchItem;    
    
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    // Release the Model Objects
    self.managedContext = nil;
    self.fetchController = nil;
    
    // Release the views
    self.tableView.tableHeaderView = nil;
    
    // Release the MzSearchItem
    self.searchItem = nil;
    
    // Release the section info
    self.selectedOptions = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set the default values for the initial view
    if (self.currentSectionName == nil) {
        self.currentSectionName = @"Phones";
    }    
    
    // For now hard-code the currentSection here...
    // Get the textlabel data
    NSArray *tempSections = [NSArray arrayWithArray:[self.fetchController sections]];
    assert(tempSections != nil);
    
    if ([tempSections count] > 0) {
        for (id <NSFetchedResultsSectionInfo> sectionItem in tempSections) {
            NSLog(@"Section name: %@", [sectionItem name]);
            if ([[sectionItem name] isEqualToString:self.currentSectionName]) {
                self.currentSection = sectionItem;
            }
        }
    }
    assert(self.currentSection != nil);
    
    // Initialize the NSMutableOrderedSet that keeps track of all the user's choices
    if (self.selectedOptions == nil) {
        NSMutableArray *taskAttributes;
        taskAttributes = [NSMutableArray array];
        assert(taskAttributes != nil);
        [[self.currentSection objects] enumerateObjectsUsingBlock:^(MzTaskAttribute *attribute, NSUInteger idx, BOOL *stop) {
            [taskAttributes addObject:attribute.taskAttributeName];
        }];
        
        if ([taskAttributes count] > 0) {
            self.selectedOptions = [NSMutableOrderedSet orderedSetWithArray:taskAttributes];
            assert(self.selectedOptions != nil);
        }
    }        
}

-(void)viewWillDisappear:(BOOL)animated
{
    
    //Testing
    self.currentButton = nil;
    self.currentSectionName = nil;
    self.currentSection = nil;
    
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    // Note that we are using the NSFetchedResultsController in a slightly different
    // way than its typically used, although we indicated in the viewDidLoad method
    // that we have sections we ask the tableView to display one section.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{

    // Return the number of rows in the section. We get the number of items per section
    // mod 3 since there are 3 UIButton objects per UITableViewCell and return the max
    // number over all sections to be number of rows for the tableView
    if (self.fetchSucceeded) {
        
        NSArray *tempSections = [self.fetchController sections];
        [[QLog log] logWithFormat:@" %d sections retrieved from Task Collection", [tempSections count]];
        
        assert(tempSections != nil);
        NSUInteger maxSectionCount = 0;
        NSUInteger sectionCount = 0;
        
        // Find the section with most number of items
        if ([tempSections count] > 0) {
            for (id <NSFetchedResultsSectionInfo> sectionItem in tempSections) {
                sectionCount = [sectionItem numberOfObjects];
                maxSectionCount = sectionCount > maxSectionCount ? sectionCount : maxSectionCount;
            }
        } else {
            
            [[QLog log] logWithFormat:@"Zero rows from Task Collection returned for TableView"];
            return 0;
        }
        assert(maxSectionCount > 0);    // prevent zero division
        [[QLog log] logWithFormat:@"%d mod 3 rows from Task Collection returned for TableView", maxSectionCount];
        
        // apply the mod 3 test
        if (maxSectionCount % kSearchButtonsPerCell == 0 || maxSectionCount % kSearchButtonsPerCell == 2) {
            return (maxSectionCount/kSearchButtonsPerCell);
        } else {
            return (maxSectionCount/kSearchButtonsPerCell) + 1;
        }   

    } else {
        
        // We just return zero
        [[QLog log] logWithFormat:@"Return zero rows after Fetch from Task Collection failed"];
        return 0;
    }
        
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"kAddSearchCellId";
        
    // Use the dynamic prototype in Interface Builder which will automatically create the
    // cells for us
    MzAddSearchCell *cell = (MzAddSearchCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    assert(cell != nil);
    
    // Configure the cell.
                
        // Set the Indexes
        NSUInteger leftIndex = (indexPath.row * kSearchButtonsPerCell) + SearchOptionButtonLeft;
        NSUInteger middleIndex = (indexPath.row * kSearchButtonsPerCell) + SearchOptionButtonMiddle;
        NSUInteger rightIndex = (indexPath.row * kSearchButtonsPerCell) + SearchOptionButtonRight;
        
        // We can now set the textLabels
        if (leftIndex < [self.currentSection numberOfObjects]) {
            cell.leftOptionButton.titleLabel.numberOfLines = 2;
            cell.leftOptionButton.titleLabel.textAlignment = UITextAlignmentCenter;
            NSString *leftTitle = [(MzTaskAttribute *)[[self.currentSection objects] objectAtIndex:leftIndex] taskAttributeName];
            [cell.leftOptionButton setTitle:leftTitle forState:UIControlStateNormal];
            [cell.leftOptionButton setTitle:leftTitle forState:UIControlStateHighlighted];
            
            // Reset the button's titleLabel from its attribute value to the attributeOption value
            // if the button was tapped (i.e touchUpInside event occurred and caused us to modally
            // present a table viewcontroller with attribute options)
            if (self.attributeOption != nil && leftIndex == self.buttonIndex) {
                [cell.leftOptionButton setTitle:self.attributeOption forState:UIControlStateNormal];
            }
            
        } else {
            [cell.leftOptionButton setTitle:kAttributeFillerString forState:UIControlStateNormal];
            [cell.leftOptionButton setTitle:kAttributeFillerString forState:UIControlStateHighlighted];
            cell.leftOptionButton.titleLabel.textAlignment = UITextAlignmentCenter;
        }
        
        if (middleIndex < [self.currentSection numberOfObjects]) {
            cell.middleOptionButton.titleLabel.numberOfLines = 2;
            cell.middleOptionButton.titleLabel.textAlignment = UITextAlignmentCenter;
            NSString *middleTitle = [(MzTaskAttribute *)[[self.currentSection objects] objectAtIndex:middleIndex] taskAttributeName];
            [cell.middleOptionButton setTitle:middleTitle forState:UIControlStateNormal];
            [cell.middleOptionButton setTitle:middleTitle forState:UIControlStateHighlighted];
            
            // Reset the button's titleLabel from its attribute value to the attributeOption value
            // if the button was tapped (i.e touchUpInside event occurred and caused us to modally
            // present a table viewcontroller with attribute options)
            if (self.attributeOption != nil && middleIndex == self.buttonIndex) {
                [cell.middleOptionButton setTitle:self.attributeOption forState:UIControlStateNormal];
            }

            
        } else {
            [cell.middleOptionButton setTitle:kAttributeFillerString forState:UIControlStateNormal];
            [cell.middleOptionButton setTitle:kAttributeFillerString forState:UIControlStateHighlighted];
            cell.middleOptionButton.titleLabel.textAlignment = UITextAlignmentCenter;
        }
        
        if (rightIndex < [self.currentSection numberOfObjects]) {
            cell.rightOptionButton.titleLabel.numberOfLines = 2;
            cell.rightOptionButton.titleLabel.textAlignment = UITextAlignmentCenter;
            NSString *rightTitle = [(MzTaskAttribute *)[[self.currentSection objects] objectAtIndex:rightIndex] taskAttributeName];
            [cell.rightOptionButton setTitle:rightTitle forState:UIControlStateNormal];
            [cell.rightOptionButton setTitle:rightTitle forState:UIControlStateHighlighted];
            
            // Reset the button's titleLabel from its attribute value to the attributeOption value
            // if the button was tapped (i.e touchUpInside event occurred and caused us to modally
            // present a table viewcontroller with attribute options)
            if (self.attributeOption != nil && rightIndex == self.buttonIndex) {
                [cell.rightOptionButton setTitle:self.attributeOption forState:UIControlStateNormal];
            }
            
        } else {
            [cell.rightOptionButton setTitle:kAttributeFillerString forState:UIControlStateNormal];
            [cell.rightOptionButton setTitle:kAttributeFillerString forState:UIControlStateHighlighted];
            cell.rightOptionButton.titleLabel.textAlignment = UITextAlignmentCenter;
        }    
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

#pragma mark - Update Table view modally

// Method called when any of the searchOption button is tapped
-(IBAction)searchOptionTapped:(id)sender
{
    // verify the sender is a UIButton
    assert([sender isKindOfClass:[UIButton class]]);
    
    // Boolean to verify containment
    BOOL continueCheckButton = YES;
    BOOL buttonPosition;
    
    // set our currentButton property
    UIButton *tempButton = (UIButton *)sender;
    self.currentButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.currentButton.titleLabel.text = [NSString stringWithString:tempButton.titleLabel.text];
    NSLog(@"Button with title :%@ was tapped", self.currentButton.titleLabel.text);
    
    // Determine the position(index) of the button that was tapped
    //Adjust the y-coordinate of the tempButton center to take into account the tableHeaderView
    assert(tempButton.superview != nil);
    CGPoint buttonPoint = [self.tableView convertPoint:tempButton.center fromView:tempButton.superview];
    NSIndexPath *senderIndexPath = [self.tableView indexPathForRowAtPoint:buttonPoint];
    assert(senderIndexPath != nil);
    NSLog(@"%d row was tapped", senderIndexPath.row);
    MzAddSearchCell *tempCell = (MzAddSearchCell *)[self.tableView cellForRowAtIndexPath:senderIndexPath];
    assert(tempCell != nil);
    
    buttonPosition = CGRectContainsPoint(tempCell.leftOptionButton.frame, tempButton.center);
    if (buttonPosition) {
        self.buttonIndex = (senderIndexPath.row * kSearchButtonsPerCell) + SearchOptionButtonLeft;
        NSLog(@"Left button tapped...");
        continueCheckButton = NO;
    }
    
    if (continueCheckButton) {
        buttonPosition = CGRectContainsPoint(tempCell.middleOptionButton.frame, tempButton.center);
        if (buttonPosition) {
            self.buttonIndex = (senderIndexPath.row * kSearchButtonsPerCell) + SearchOptionButtonMiddle;
            NSLog(@"Middle button tapped...");
            continueCheckButton = NO;
        }
    }
    
    if (continueCheckButton) {
        buttonPosition = CGRectContainsPoint(tempCell.rightOptionButton.frame, tempButton.center);
        if (buttonPosition) {
            self.buttonIndex = (senderIndexPath.row * kSearchButtonsPerCell) + SearchOptionButtonRight;
            NSLog(@"Right button tapped...");
            continueCheckButton = NO;
        }
    }
        
    // ignore the buttons with the "..." filler string
    if (![self.currentButton.titleLabel.text isEqualToString:kAttributeFillerString]) {
        
        // Perform the Segue and pass on the UIButton
        [self performSegueWithIdentifier:kAttributeOptionSegue sender:self.currentButton];
    } else {
        
        // Set the currentButton to nil since we shall not be modally presenting a view
        //controller in this case
        //self.currentButton = nil;
    }
    
}

// Add self as a delegate to the MzAttributeOptionViewController
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:kAttributeOptionSegue] && [sender isKindOfClass:[UIButton class]]) {
        MzAttributeOptionViewController *optionsController = [segue destinationViewController];
        optionsController.delegate = self;
        optionsController.modalButton = (UIButton *)sender;
    }
    
    // If categoryButton in headerView was tapped
    if ([[segue identifier] isEqualToString:kAttributeOptionSegue] && sender == nil) {
        MzAttributeOptionViewController *optionsController = [segue destinationViewController];
        optionsController.delegate = self;
        optionsController.modalButton = nil;
    }
}

// Method that updates our button labels and dismisses the viewController we modally presented
-(void)controller:(MzAttributeOptionViewController *)optionController selection:(NSString *)selectedString
{
    // set the new value our attributeOption property
    self.attributeOption = selectedString;
    NSLog(@"User selected : %@ from options", self.attributeOption);
    
    // Update the OrderedSet that tracks the user's selection
    if (optionController.modalButton != nil) {
        assert(self.selectedOptions != nil);
        [self.selectedOptions replaceObjectAtIndex:self.buttonIndex withObject:self.attributeOption];
        
        // dimiss the modally presented controller
        [self dismissModalViewControllerAnimated:YES];
        
        // reload our visible tableView data so we update tapped buttons
        [self.tableView reloadData];
        
    } else {
        
        // Update the categoryButton label
        MzAddSearchHeaderView * headerView = (MzAddSearchHeaderView *)self.tableView.tableHeaderView;
        assert(headerView != nil);
        [headerView.productCategory setTitle:selectedString forState:UIControlStateNormal];
        
        // set the currentSectionName before we appear on screen
        self.currentSectionName = selectedString;
        [self.tableView reloadData];
        
        // dismiss the modal Controller
        [self dismissModalViewControllerAnimated:YES];
    }    
}

#pragma mark - tableView HeaderView Delegate Methods

// Retrieve the Price value the user has entered
-(void)textFieldDidEndEditing:(UITextField *)textField
{
    
    //check if the user has input a price value
    NSNumber *preferredPrice;
    if ([textField.text length] > 0) {
        double priceText = [textField.text doubleValue];
        
        if (priceText !=0.0 && priceText != HUGE_VAL && priceText != -HUGE_VAL) {
            preferredPrice = [NSNumber numberWithDouble:priceText];
            assert(preferredPrice != nil);
        } else {
            
            // Log
            [[QLog log] logWithFormat:@"Invalid value for Price TextField entered"];
        }
        
    } else if (textField.text == nil) {
        preferredPrice = nil;
        [[QLog log] logWithFormat:@"No value for Price TextField entered"];
    }
    
    // Update the searchItem
    self.searchItem.priceToSearch = preferredPrice;
    [[QLog log] logWithFormat:@"Preferred Price value: %@", textField.text];
    
}

// If user taps "Done", remove the keyboard but keep the text in the TextField
-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    // we just clear the keyboard regardless of whether the user entered a price
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Search Item creation

// Method called when user taps Done button to indicate completion of the search
// criteria selection
-(IBAction)searchOptionsComplete:(id)sender
{
    // check our delegate
    assert(self.delegate != nil);
    
    // complete our instance variable MzSearchItem's dictionary property
    NSMutableDictionary *searchDictionary;
    assert(self.selectedOptions != nil);
    assert(self.currentSection != nil);
    searchDictionary = [NSMutableDictionary dictionary];
    assert(searchDictionary != nil);
    
    [[self.currentSection objects] enumerateObjectsUsingBlock:
    ^(MzTaskAttribute *attribute, NSUInteger idx, BOOL *stop) {
        
        // Populate the dictionary - note that its possible for the key and value to have
        // the same string value
        [searchDictionary setObject:[self.selectedOptions objectAtIndex:idx] forKey:attribute.taskAttributeName];
    }];
    
    if ([searchDictionary count] > 0) {
        self.searchItem.searchOptions = searchDictionary;
    }
    
    // create the Search Title from the product Category and selected Brand
    // note that this requires that all sub-categories have a brand attribute
    NSString *searchItemTitle;
    NSString *searchItemBrand;
    NSString *searchItemCategory;
    
    searchItemBrand = [searchDictionary objectForKey:kBrandAttribute];
    assert(searchItemBrand != nil);     // fail if no brand attribute
    
    if ([searchItemBrand isEqualToString:kBrandAttribute]) {
        
        // In this case no specific brand has been selected
        searchItemBrand = kAllBrandsAttribute;
    }
    
    // Get the current product Category
    MzAddSearchHeaderView *headerView = (MzAddSearchHeaderView *)self.tableView.tableHeaderView;
    assert(headerView != nil);
    searchItemCategory = headerView.productCategory.titleLabel.text;
    assert(searchItemCategory != nil);
    
    searchItemTitle = [searchItemBrand stringByAppendingFormat:@" %@", searchItemCategory];
    assert(searchItemTitle != nil);
    
    self.searchItem.searchTitle = searchItemTitle;
    
    // Set the search status
    self.searchItem.searchStatus = SearchItemStateInProgress;
    
    // Set the search Timestamp
    self.searchItem.searchTimestamp = [NSDate date];
    
    // We can now pass the MzSearchItem to our delegate who will also dismiss us
    // from the screen
    [self.delegate controller:self newSearchItem:self.searchItem];
}

// Delegate method from the tableView HeaderView
-(void)tableHeaderView:(MzAddSearchHeaderView *)headerView selectedDuration:(NSUInteger)duration
{
    // Update the header view's label to show the user the current value
    // selected from the UIStepper
    assert(self.tableView.tableHeaderView == headerView);
    NSNumber *currentDuration = [NSNumber numberWithInt:duration];
    assert(currentDuration != nil);
    headerView.durationLabel.text = currentDuration.stringValue; 
    
    // Get the current value from the UIStepper control and add to the
    // MzSearchItem
    self.searchItem.daysToSearch = currentDuration;
}

// Delegate method from the tableView HeaderView
-(void)tableHeaderView:(MzAddSearchHeaderView *)headerView categoryButtonState:(BOOL)isTapped
{
    // Modally present a viewController so user can select the product Category
    if (isTapped) {
        // Perform the Segue and pass nil for the UIButton
        [self performSegueWithIdentifier:kAttributeOptionSegue sender:nil];
    }
}

@end
