//
//  MzSearchListViewController.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzSearchListViewController.h"
#import "MzSearchListCell.h"
#import "MzSearchCollection.h"
#import "MzAddSearchViewController.h"

#define NUMBER_SECTIONS 1
#define kAddSearchButtonTag 1

@interface MzSearchListViewController ()

@property (nonatomic, strong) NSArray *searchItems;

// Selector that is called when AddSearchButton is tapped
-(void)addSearchSelected;

@end

@implementation MzSearchListViewController

@synthesize searchCell;
@synthesize searchCollection;
@synthesize searchItems;

// Segue Identifiers
static NSString *kAddSearchSegue = @"addSearchSegue";   // to Add Search VC 
static NSString *kSearchDetailsSegue = @"searchDetailsSegue";   // to Search Details VC

// Override the setter

#pragma mark - Initialization

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        
        
    }
    
    // Add the tableView Header
    
    return self;
}

#pragma mark - UIStoryboardSegue Interaction methods

/* Selector that is called when AddSearchButton is tapped
-(void)addSearchSelected
{
    // We fire the Segue
    [self performSegueWithIdentifier:kAddSearchSegue sender:self];
} */

// Add self as a delegate to the MzAddSearchViewController
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:kAddSearchSegue]) {
        MzAddSearchViewController *addSearchController = [segue destinationViewController];
        addSearchController.delegate = self;        
    }
}


#pragma mark - View LifeCycle methods
- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Retrieve all the MzSearchItems currently in the Search Directory
    //Initialize the MzSearchCollection
    searchCollection = [[MzSearchCollection alloc] init];
    assert(searchCollection != nil);
    [searchCollection addSearchCollection];
    searchItems = [self.searchCollection allSearchItems];
    //assert(searchItems != nil);
    
    // Display the tableViewHeader across the top of the tableView
    CGRect headerFrame = CGRectMake(0, 0, 320, 60);
    MzSearchListHeaderView *headerView = [[MzSearchListHeaderView alloc] initWithFrame:headerFrame delegate:self];
    assert(headerView != nil);
    
    // set self as target for the AddSearch button
    headerView.addSearchButton.tag = kAddSearchButtonTag;
    //[headerView.addSearchButton addTarget:self action:@selector(addSearchSelected) forControlEvents:UIControlEventTouchUpInside];
    
    self.tableView.tableHeaderView = headerView;    
        
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    self.searchCollection = nil;
    self.searchItems = nil;
    self.tableView.tableHeaderView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{

    // Initially to keep it simple, we have a table with just one section
    return NUMBER_SECTIONS;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    
    return searchItems != nil ? [searchItems count] : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"searchItemCell";
    MzSearchListCell *cell = (MzSearchListCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell...
    if (cell) {
        // If searchItems array is nil or empty this method is never called...no need to check
        [cell setSearchItem:[searchItems objectAtIndex:indexPath.row]];
        
    } else {
        
        // we instantiate a new cell
        UINib *cellNib = [UINib nibWithNibName:@"MzSearchListCell" bundle:nil];
        assert(cellNib != nil);
        [cellNib instantiateWithOwner:self options:nil];
        cell = self.searchCell;
        self.searchCell = nil;
        
        // configure the cell
        [cell setSearchItem:[searchItems objectAtIndex:indexPath.row]];
    }
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


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

#pragma mark - Table View Header Delegate

-(void)tableHeaderView:(MzSearchListHeaderView *)sectionHeaderView buttonState:(BOOL)isTapped
{
    // If User taps the Add a Search button we push the MzAddSearchViewController
    assert(self.tableView.tableHeaderView == sectionHeaderView);
    if (isTapped) {
        [self performSegueWithIdentifier:kAddSearchSegue sender:nil];
    }
}

@end
