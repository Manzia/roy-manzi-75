//
//  MzReviewsListViewController.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 2/2/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzReviewsListViewController.h"
#import "Logging.h"
#import "MzProductItem.h"
#import "MzReviewsListCell.h"

@interface MzReviewsListViewController ()

// Data Management
@property (nonatomic, strong) NSFetchedResultsController *fetchController;
@property (nonatomic, strong) NSManagedObjectContext *managedContext;

@end

@implementation MzReviewsListViewController

//Synthesize
@synthesize productItem;
@synthesize fetchController;
@synthesize managedContext;

// MzReviewItem Entity
static NSString *kReviewItemEntity = @"MzReviewItem";
static NSString *kReviewCellId = @"kReviewCellIdentifier";

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Check that our productItem property has been set
    assert(self.productItem != nil);
    
    // Core Data
    // we initialize our NSManagedObjectContext
    self.managedContext = self.productItem.managedObjectContext;
    assert(self.managedContext != nil);
        
    // We can now initialize our NSFetchedResultsController
    NSFetchRequest *mrequest = [NSFetchRequest fetchRequestWithEntityName:kReviewItemEntity];
    assert(mrequest != nil);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ANY reviewSku like[c] %@", self.productItem.productID];
    assert(predicate != nil);
    [mrequest setPredicate:predicate];
    
    // Sort Results by the Review submissionTime, i.e newest Reviews first
    NSSortDescriptor *sortDescriptorType = [[NSSortDescriptor alloc] initWithKey:@"reviewSubmitTime" ascending:NO comparator:^(MzReviewItem *reviewOne, MzReviewItem *reviewTwo) {
        return [reviewOne.reviewSubmitTime compare:reviewTwo.reviewSubmitTime];
    }];
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
        [[QLog log] logWithFormat:@"Error fetching Review Items to display from MzReviewiTem Entity: %@", error.localizedDescription];
        self.fetchController = nil;
    }

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
   // We only have 1 section.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Number of rows in the section.
    assert(self.fetchController != nil);
    return [[self.fetchController fetchedObjects] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    assert(self.fetchController != nil);
    
    MzReviewsListCell *cell = (MzReviewsListCell *)[tableView dequeueReusableCellWithIdentifier:kReviewCellId forIndexPath:indexPath];
    
    // Configure the cell by setting its reviewItem property..which causes all other
    // properties to be set as well
    NSArray *reviewItems = [self.fetchController fetchedObjects];
    assert(reviewItems != nil);
    if ([reviewItems count] > 0) {
        cell.reviewItem = [reviewItems objectAtIndex:indexPath.row];
    }
    
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
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


// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}


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
