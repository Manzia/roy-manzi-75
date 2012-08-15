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

// Constants
#define kSearchButtonsPerCell 3

@interface MzAddSearchViewController ()

// Model properties
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@property (nonatomic, strong) NSFetchedResultsController *fetchController;
@property (nonatomic, assign) BOOL fetchSucceeded;

// TableView, TableViewCell properties
//@property (nonatomic, weak) IBOutlet UIButton *leftSearchButton;
//@property (nonatomic, weak) IBOutlet UIButton *middleSearchButton;
//@property (nonatomic, weak) IBOutlet UIButton *rightSearchButton;
@property (nonatomic, strong) IBOutlet MzAddSearchCell *addSearchCell;

// Property below represents the text of the currently selected button
// in one of the tableViewCells
@property (nonatomic, strong) NSString *currentButtonText;

// Property below represents the sub-category that is presently selected
// in the tableViewHeader. The value of this property determines which
// search options are displayed on the buttons in the tableView
@property (nonatomic, strong) NSString *currentSectionName;

// Method called when any of the searchOption button is tapped
-(void)searchOptionTapped:(id)sender;

@end

@implementation MzAddSearchViewController

@synthesize managedContext;
@synthesize fetchController;
@synthesize currentButtonText;
@synthesize fetchSucceeded;
@synthesize currentSectionName;
@synthesize delegate;
@synthesize addSearchCell;
//@synthesize leftSearchButton;
//@synthesize middleSearchButton;
//@synthesize rightSearchButton;

// Database entity that we fetch from
static NSString *kTaskAttributeEntity = @"MzTaskAttribute";

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
    NSSortDescriptor * sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"taskAttributeName" ascending:YES];
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
}

-(void)viewWillDisappear:(BOOL)animated
{
    //Testing
    self.currentSectionName = nil;
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
    UIButton *leftButton;
    UIButton *middleButton;
    UIButton *rightButton;
    id <NSFetchedResultsSectionInfo> currentSection;
    
    // Use the dynamic prototype in Interface Builder which will automatically create the
    // cells for us
    MzAddSearchCell *cell = (MzAddSearchCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    assert(cell != nil);
    
    // Configure the cell...
        // configure the UIButton subviews
        //leftButton = (UIButton *)[cell.contentView viewWithTag:SearchOptionButtonLeft];
        leftButton = cell.leftOptionButton;
        assert(leftButton != nil);
        //middleButton = (UIButton *)[cell.contentView viewWithTag:SearchOptionButtonMiddle];
        middleButton = cell.middleOptionButton;
        assert(middleButton != nil);
        //rightButton = (UIButton *)[cell.contentView viewWithTag:SearchOptionButtonRight];
        rightButton = cell.rightOptionButton;
        assert(rightButton != nil);
        
                
        // Get the textlabel data
        NSArray *tempSections = [self.fetchController sections];
        assert(tempSections != nil);
        
        if ([tempSections count] > 0) {
            for (id <NSFetchedResultsSectionInfo> sectionItem in tempSections) {
                if ([[sectionItem name] isEqualToString:self.currentSectionName]) {
                    currentSection = sectionItem;
                }
            }
        }
        assert(currentSection != nil);
        
        // Set the Indexes
        NSUInteger leftIndex = (indexPath.row * kSearchButtonsPerCell) + SearchOptionButtonLeft;
        NSUInteger middleIndex = (indexPath.row * kSearchButtonsPerCell) + SearchOptionButtonMiddle;
        NSUInteger rightIndex = (indexPath.row *kSearchButtonsPerCell) + SearchOptionButtonRight;
        
        // We can now set the textLabels
        if (leftIndex < [currentSection numberOfObjects]) {
            leftButton.titleLabel.text = [(MzTaskAttribute *)[[currentSection objects] objectAtIndex:leftIndex] taskAttributeName];
        } else {
            leftButton.titleLabel.text = @"...";
        }
        
        if (middleIndex < [currentSection numberOfObjects]) {
            middleButton.titleLabel.text = [(MzTaskAttribute *)[[currentSection objects] objectAtIndex:middleIndex] taskAttributeName];
        } else {
            middleButton.titleLabel.text = @"...";
        }
        
        if (rightIndex < [currentSection numberOfObjects]) {
            rightButton.titleLabel.text = [(MzTaskAttribute *)[[currentSection objects] objectAtIndex:rightIndex] taskAttributeName];
        } else {
            rightButton.titleLabel.text = @"...";
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

@end
