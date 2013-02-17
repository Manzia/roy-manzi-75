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
#import "MzReviewCollection.h"
#import "MzAppDelegate.h"

@interface MzReviewsListViewController ()

// Data Management
//@property (nonatomic, strong) NSFetchedResultsController *fetchController;
//@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@property (nonatomic, strong) MzReviewCollection *reviewCollection;
@property (nonatomic, strong, readonly) NSMutableArray *reviewItems;

@end

@implementation MzReviewsListViewController

//Synthesize
@synthesize productItem;
//@synthesize fetchController;
//@synthesize managedContext;
@synthesize reviewCollection;
@synthesize reviewCategory;
@synthesize reviewItems;

// MzReviewItem Entity
static NSString *kReviewItemEntity = @"MzReviewItem";
static NSString *kReviewCellId = @"kReviewCellIdentifier";

// Reviews URL path
static NSString *kReviewURLPath = @"ManziaWebService/service/reviews";
static NSString *kReviewURLFormat = @"%@/%@/%@?%@";
static NSString *kProductSkuQueryFormat = @"sku=%@&Category=%@";

// KVO context - we observe the "statusOfSync" property of our MzReviewCollection in
// order to determine when to fetch the MzReviewItems from CoreData
static void *ReviewCollectionContext = &ReviewCollectionContext;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - View Lifecycle
/*
 During the view loading process we do the following:
 1- Instantiate a MzReviewCollection object and download MzReviewItems from the network, note
 that the MzReviewCollection will only insert "new" MzReviewItems in the MzReviewItem table and
 ignore those that already exist. We download in groups of 10.
 2- Instantiate a NSFetchedResultsController that retrieves objects from the MzReviewItem table
 3- Set "self" as a delegate to the NSFetchedResultsController so we update our tableView when
 the MzReviewItems have been downloaded from the network and stored in CoreData.
 4- If the User "pushes" us off the screen while the MzReviewCollection is still syncing, we stop
 the syncing process and save any MzReviewItems we may have downloaded and nil out all our properties
 5-  
 */
- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Check that our productItem property has been set and generate the Reviews URL
    assert(self.productItem != nil);
    NSString *reviewsURL = [self generateReviewsURL:self.productItem.productID];
    if (reviewsURL == nil) {
        // Pop off the stack - get off screen
        if (self.navigationController.topViewController == self) {
            self.productItem = nil;
            [[QLog log] logWithFormat:@"Null Review URL was generated...exit MzReviewsListViewController!"];
            [self.navigationController popViewControllerAnimated:NO];
        }
    }
    
    // Start the ReviewCollection - asynchronously retrieves MzReviewItems from the Network
    MzReviewCollection *collection = [[MzReviewCollection alloc] initWithCollectionURLString:reviewsURL andProductItem:self.productItem];
    assert(collection != nil);
    self.reviewCollection = collection;
    [self.reviewCollection addObserver:self forKeyPath:@"statusOfSync" options:NSKeyValueObservingOptionNew context:ReviewCollectionContext];
    [self.reviewCollection startCollection];
    
    // Core Data - intialize array of ReviewItems
    self->reviewItems = [NSMutableArray array];
    
    /* we initialize our NSManagedObjectContext
    self.managedContext = self.productItem.managedObjectContext;
    assert(self.managedContext != nil);
        
    // We can now initialize our NSFetchedResultsController
    NSFetchRequest *mrequest = [NSFetchRequest fetchRequestWithEntityName:kReviewItemEntity];
    assert(mrequest != nil);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"reviewSku like[c] %@", self.productItem.productID];
    assert(predicate != nil);
    [mrequest setPredicate:predicate];
    
    // Sort Results by the Review submissionTime, i.e newest Reviews first
    NSSortDescriptor *sortDescriptorType = [[NSSortDescriptor alloc] initWithKey:@"reviewSubmitTime" ascending:NO comparator:^(MzReviewItem *reviewOne, MzReviewItem *reviewTwo) {
        return [reviewOne.reviewSubmitTime compare:reviewTwo.reviewSubmitTime];
    }];
    NSSortDescriptor *sortByRating = [[NSSortDescriptor alloc] initWithKey:@"reviewRating" ascending:NO];
    assert(sortByRating != nil);
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortByRating];
    [mrequest setSortDescriptors:sortDescriptors];
    
    // We set up only one section i.e one component for the UIPickerView
    NSFetchedResultsController *controller = [[NSFetchedResultsController alloc] initWithFetchRequest:mrequest
                                                                                 managedObjectContext:self.managedContext
                                                                                   sectionNameKeyPath:nil
                                                                                            cacheName:nil];
    assert(controller != nil);
    self.fetchController = controller;
    assert(self.fetchController != nil);
    self.fetchController.delegate = self;       // Set "ourself" as delegate
    
    // Execute the fetch
    NSError *error = NULL;
    [self.fetchController performFetch:&error];
    
    // Error-checking
    if (error) {
        
        //Log
        [[QLog log] logWithFormat:@"Error fetching Review Items to display from MzReviewiTem Entity: %@", error.localizedDescription];
        self.fetchController = nil;
    } */

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    self.productItem = nil;
}

// We are going off screen so we stop the Review Collection and nil out our properties
-(void)viewWillDisappear:(BOOL)animated
{
    [self.reviewCollection removeObserver:self forKeyPath:@"statusOfSync" context:ReviewCollectionContext];
    self.productItem = nil;    
}

-(void)viewWillUnload
{
    // If Review Collection is syncing then stop it
    if (self.reviewCollection.isSynchronizing) {
        [self.reviewCollection stopCollection];
    }
    //self.managedContext = nil;
    //self.fetchController = nil;
    self->reviewItems = nil;
}

-(void)viewDidUnload
{
    self.reviewCollection = nil;
}

#pragma mark - Review Collection management

// generate the reviews URL string, if an invalid productSku is specified we "pop" ourself
// and get off the screen
-(NSString *)generateReviewsURL:(NSString *)productSkuId
{
    // check inputs
    if (productSkuId == nil || [productSkuId length] < 1) {
        // Log
        [[QLog log] logWithFormat:@"Cannot generate URL from Null or Empty productSkuId..!"];
        return nil;
        
    } else {
        // Create the reviews URL
        NSString *productSkuQuery = [NSString stringWithFormat:kProductSkuQueryFormat, productSkuId, self.reviewCategory];
        assert(productSkuQuery != nil);
        NSString *baseURL = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] searchesURL];
        if(baseURL == nil) {
            baseURL = @"http://ec2-50-18-112-205.us-west-1.compute.amazonaws.com:8080";
        }
        NSString *deviceId = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] uniqueDeviceId];
        assert(deviceId != nil);
        NSString *reviewsURL = [NSString stringWithFormat:kReviewURLFormat, baseURL, kReviewURLPath, deviceId, productSkuQuery];
        assert(reviewsURL != nil);
        NSString *encodedURLString = [reviewsURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        assert(encodedURLString != nil);
        return encodedURLString;
    }
}


// KVO implementation
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == ReviewCollectionContext) {
        
        // ReviewCollection is synchronizing or has synchronized
        if ([keyPath isEqualToString:@"statusOfSync"]) {
            assert([object isKindOfClass:[MzReviewCollection class]]);
            
            if ((change != nil) && ([[change objectForKey:NSKeyValueChangeKindKey] intValue] == NSKeyValueChangeSetting)) {
                
                NSString *statusValue = [change objectForKey:NSKeyValueChangeNewKey];
                assert(statusValue != nil);
                
                if ([statusValue isEqualToString:@"Update Failed"] || [statusValue isEqualToString:@"Update cancelled"] ) {
                    
                    // Log
                    [[QLog log] logWithFormat:@"Update Failed/Cancelled for Review Collection Cache for Product ID: %@", self.productItem.productID];
                                        
                    // Get off the screen
                    if (self.navigationController.visibleViewController == self) {
                        [self.navigationController popViewControllerAnimated:YES];
                    }
                    
                } else if ([statusValue hasPrefix:@"Updated:"]) {
                    
                    // Synchronization succeeded so we fetch the ReviewItems
                    [[QLog log] logWithFormat:@"Fetching ReviewItems after synchronization of Review Collection Cache for Product ID: %@", self.productItem.productID ];
                    [self.reviewCollection fetchReviewsInCollection];
                    [self.reviewItems addObjectsFromArray:[self.reviewCollection.reviewItems objectForKey:self.productItem.productID]];
                    
                    // Reload tableView since we may have new ReviewItems
                    [self.tableView reloadData];
                }
            }
        }
    }
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
    assert(self.reviewItems != nil);
    //NSUInteger rowCount = [[self.fetchController fetchedObjects] count];
    NSUInteger rowCount = [self.reviewItems count];
    [[QLog log] logWithFormat:@"Number of Reviews to be Displayed: %d", rowCount];
    return rowCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    assert(self.reviewItems != nil);
    
    MzReviewsListCell *cell = (MzReviewsListCell *)[tableView dequeueReusableCellWithIdentifier:kReviewCellId forIndexPath:indexPath];
    
    // Configure the cell by setting its reviewItem property..which causes all other
    // properties to be set as well
    //NSArray *reviewItems = [self.fetchController fetchedObjects];
    //assert(reviewItems != nil);
    if ([self.reviewItems count] > 0) {
        cell.reviewItem = [self.reviewItems objectAtIndex:indexPath.row];
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

#pragma mark - NSFetchedResultsController delegate

// Begin updates
-(void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

// End updates
-(void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
    [self.tableView reloadData];
}

// Insert MzReviewItems
- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;
            
    }
}

@end
