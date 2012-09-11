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

// Constants
#define kSearchButtonsPerCell 3

@interface MzAddSearchViewController ()

// Model properties
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@property (nonatomic, strong) NSFetchedResultsController *fetchController;
@property (nonatomic, assign) BOOL fetchSucceeded;
@property(nonatomic, strong) id <NSFetchedResultsSectionInfo> currentSection;

// TableView, TableViewCell properties
@property (nonatomic, strong) IBOutlet MzAddSearchCell *addSearchCell;

// Property below represents the currently selected button
// in one of the tableViewCells
@property (nonatomic, strong) UIButton *currentButton;

//Property below represents the attributeOption string value that the user
// selects from the View Controller (tableView) that we present modally, we use
// delegation to set this value
@property (nonatomic, copy) NSString *attributeOption;

// Property below represents the sub-category that is presently selected
// in the tableViewHeader. The value of this property determines which
// search options are displayed on the buttons in the tableView
@property (nonatomic, strong) NSString *currentSectionName;


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

// Database entity that we fetch from
static NSString *kTaskAttributeEntity = @"MzTaskAttribute";

// Modal segue to the attributeOptions
static NSString *kAttributeOptionSegue = @"kAttributeOptionSegue";

// No option symbol
static NSString *kAttributeFillerString = @"...";

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
 
    // display an Edit button in the navigation bar for this view controller.
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
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
    
    // initialize the currentButton property
    //self.currentButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    //assert(self.currentButton != nil);
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    // Release the Model Objects
    self.managedContext = nil;
    self.fetchController = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    // Testing only - set the currentSectionName
    self.currentSectionName = @"Phones";
    
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
}

-(void)viewWillDisappear:(BOOL)animated
{
    //Testing
    self.currentSectionName = nil;
    self.currentSection = nil;
    self.currentButton = nil;
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
    NSString *currentTitle = self.currentButton.titleLabel.text;
    NSLog(@"Current title value: %@", self.currentButton.titleLabel.text); 
            
        // Set the Indexes
        NSUInteger leftIndex = (indexPath.row * kSearchButtonsPerCell) + SearchOptionButtonLeft;
        NSUInteger middleIndex = (indexPath.row * kSearchButtonsPerCell) + SearchOptionButtonMiddle;
        NSUInteger rightIndex = (indexPath.row *kSearchButtonsPerCell) + SearchOptionButtonRight;
        
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
            if (currentTitle != nil && self.attributeOption != nil) {
                if ([currentTitle isEqualToString:leftTitle]) {
                    
                    //change the value to that selected by the user
                    //cell.leftOptionButton.titleLabel.text = self.attributeOption;
                    [cell.leftOptionButton setTitle:self.attributeOption forState:UIControlStateNormal];
                    //[cell.leftOptionButton setTitle:self.attributeOption forState:UIControlStateHighlighted];
                } 
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
            if (currentTitle != nil && self.attributeOption != nil) {
                if ([currentTitle isEqualToString:middleTitle]) {
                    
                    //change the value to that selected by the user
                    [cell.middleOptionButton setTitle:self.attributeOption forState:UIControlStateNormal];
                    [cell.middleOptionButton setTitle:self.attributeOption forState:UIControlStateHighlighted];
                }
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
            if (currentTitle != nil && self.attributeOption != nil) {
                if ([currentTitle isEqualToString:rightTitle]) {
                    
                    //change the value to that selected by the user
                    [cell.rightOptionButton setTitle:self.attributeOption forState:UIControlStateNormal];
                    [cell.rightOptionButton setTitle:self.attributeOption forState:UIControlStateHighlighted];
                }
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
    
    // set our currentButton property
    UIButton *tempButton = (UIButton *)sender;
    self.currentButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.currentButton.titleLabel.text = [NSString stringWithString:tempButton.titleLabel.text];
    NSLog(@"Button with title :%@ was tapped", self.currentButton.titleLabel.text);
    
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
}

// Method that updates our button labels and dismisses the viewController we modally presented
-(void)controller:(MzAttributeOptionViewController *)optionController selection:(NSString *)selectedString
{
    // set the new value our attributeOption property
    self.attributeOption = selectedString;
    NSLog(@"User selected : %@ from options", self.attributeOption);
    
    // Get the title value from the UIButton whose titleLabel value will change
    NSString *oldTitle = [NSString stringWithString:optionController.modalButton.titleLabel.text];
    assert(oldTitle != nil);
    
    // set currentButton's title property if null
    if (self.currentButton == nil) {
        self.currentButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        assert(self.currentButton != nil);
    }
    
    if (self.currentButton.titleLabel.text == nil || [self.currentButton.titleLabel.text length] < 1) {
        self.currentButton.titleLabel.text = [NSString stringWithString:oldTitle];
        //self.currentButton.titleLabel.text = self.attributeOption;
        NSLog(@"New value for selected button: %@", self.currentButton.titleLabel.text);
    }
    
    //[self.tableView reloadRowsAtIndexPaths:[self.tableView indexPathsForVisibleRows] withRowAnimation:UITableViewRowAnimationNone];
    
    // dimiss the modally presented controller
    [self dismissModalViewControllerAnimated:YES];
    
    // reload our visible tableView data so we update tapped buttons
    [self.tableView reloadData];
}


@end
