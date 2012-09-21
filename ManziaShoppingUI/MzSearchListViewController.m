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
#import "Logging.h"

#define NUMBER_SECTIONS 1
#define kAddSearchButtonTag 1

@interface MzSearchListViewController ()

@property (nonatomic, strong) NSMutableArray *searchItems;

@end

@implementation MzSearchListViewController

@synthesize searchCell;
@synthesize searchCollection;
@synthesize searchItems;

// Segue Identifiers
static NSString *kAddSearchSegue = @"addSearchSegue";   // to Add Search VC 
static NSString *kSearchDetailsSegue = @"searchDetailsSegue";   // to Search Details VC

// Search Title Template
static NSString *kSearchTitleTemplate = @"Search %d: %@";

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
    BOOL success;
    self.searchCollection = [[MzSearchCollection alloc] init];
    assert(searchCollection != nil);
    success = [self.searchCollection addSearchCollection];
    if (success) {
        [[QLog log] logWithFormat:@"Successfully initialized Search Collection"];
    } else {
        [[QLog log] logWithFormat:@"Failed to initialize Search Collection"];
    }
    
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
    
    // Temporary call to remove all SearchItem
    //[self.searchCollection removeSearchItemsWithStatus:SearchItemStateInProgress];
    // Release any retained subviews of the main view.
    self.searchCollection = nil;
    //self.searchItems = nil;
    self.tableView.tableHeaderView = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // get all the MzSearchItems we need to display
    self.searchItems = [NSMutableArray arrayWithArray:[self.searchCollection allSearchItems]];
    assert(self.searchItems != nil);
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // clear the searchItems property
    self.searchItems = nil;
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
        MzSearchItem *tempSearchItem = [self.searchItems objectAtIndex:indexPath.row];
        assert(tempSearchItem != nil);
        NSString *oldTitle = tempSearchItem.searchTitle;
        assert(oldTitle != nil);
        NSString *newTitle = [NSString stringWithFormat:kSearchTitleTemplate, indexPath.row + 1, oldTitle];
        assert(newTitle != nil);
        tempSearchItem.searchTitle = newTitle;
        [cell setSearchItem:tempSearchItem];
        
    } else {
        
        // we instantiate a new cell
        UINib *cellNib = [UINib nibWithNibName:@"MzSearchListCell" bundle:nil];
        assert(cellNib != nil);
        [cellNib instantiateWithOwner:self options:nil];
        cell = self.searchCell;
        self.searchCell = nil;
        
        // configure the cell
        MzSearchItem *tempSearchItem = [self.searchItems objectAtIndex:indexPath.row];
        assert(tempSearchItem != nil);
        NSString *oldTitle = tempSearchItem.searchTitle;
        assert(oldTitle != nil);
        NSString *newTitle = [NSString stringWithFormat:kSearchTitleTemplate, indexPath.row, oldTitle];
        assert(newTitle != nil);
        tempSearchItem.searchTitle = newTitle;
        [cell setSearchItem:tempSearchItem];        
    }
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



// Override to support editing the table view. We only allow the user to delete MzSearchItems
// from the tableView
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        // Delete the associated MzSearchItem from the MzSearchCollection
        MzSearchItem *itemToDelete = [self.searchItems objectAtIndex:indexPath.row];
        assert(itemToDelete != nil);
        [self.searchCollection removeSearchItem:itemToDelete];
        [self.searchItems removeObjectAtIndex:indexPath.row];
        
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


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

#pragma mark - Add Search delegate methods

-(void)controller:(MzAddSearchViewController *)searchController newSearchItem:(MzSearchItem *)searchItem
{
    assert(searchItem != nil);
    assert(self.searchCollection != nil);
    
    // add the new Search Item
    [self.searchCollection addSearchItem:searchItem];
    
    // Remove the AddSearchViewController from screen
    [self.navigationController popViewControllerAnimated:YES];
    
    // Reload our table
    [self.tableView reloadData];
}

@end
