//
//  MzAttributeOptionViewController.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 9/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzAttributeOptionViewController.h"
#import "MzTaskCollection.h"
#import "Logging.h"
#import "MzTaskAttribute.h"
#import "MzTaskAttributeOption.h"
#import "MzTaskType.h"

@interface MzAttributeOptionViewController ()

@property (nonatomic, copy) NSString *taskAttributeString;
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@property (nonatomic, strong) NSFetchedResultsController *fetchController;
@property (nonatomic, assign) BOOL fetchSucceeded;
@property (nonatomic, strong) NSFetchedResultsController *categoryFetchController;

@end

@implementation MzAttributeOptionViewController

@synthesize modalButton;
@synthesize delegate;
@synthesize taskAttributeString;
@synthesize managedContext;
@synthesize fetchController;
@synthesize fetchSucceeded;
@synthesize categoryFetchController;

// declare string constants
static NSString *kTaskAttributeEntity = @"MzTaskAttribute";
static NSString *kTaskAttributeOptionEntity = @"MzTaskAttributeOption";
static NSString *kTaskTypeEntity = @"MzTaskType";


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
    
    //From the UIButton that modally presented we retrieve the attributeOptions values from the database
    NSError *taskError = NULL;
    NSArray *retrievedAttribute;
    NSArray *retrievedOption;
    NSError *optionError = NULL;
    
    if (self.modalButton != nil) {
        NSString *attributeName = self.modalButton.titleLabel.text;
        assert(attributeName != nil);
        NSLog(@"Modal button name: %@", attributeName );
        
        //Now retrieve the corresponding taskAttributeId from the database
        NSFetchRequest *taskRequest = [NSFetchRequest fetchRequestWithEntityName:kTaskAttributeEntity];
        NSPredicate *taskPredicate = [NSPredicate predicateWithFormat:@"taskAttributeName like[c] %@", attributeName];
        assert(taskPredicate != nil);
        assert(taskRequest != nil);
        [taskRequest setPredicate:taskPredicate];
        
        retrievedAttribute = [self.managedContext executeFetchRequest:taskRequest error:&taskError];
        assert(retrievedAttribute != nil);
        
        // Log any errors
        if (taskError) {
            [[QLog log] logOption:kLogOptionSyncDetails withFormat:
             @"Encountered error: %@ during taskAttribute fetch from Task Collection",[taskError localizedDescription]];
        }
        else {
            // Get the taskAttributeId corresponding to the UIButton's taskAttributeName value
            if ([retrievedAttribute count] > 0) {
                MzTaskAttribute *attribute = [retrievedAttribute objectAtIndex:0];
                self.taskAttributeString = attribute.taskAttributeId;
                assert(self.taskAttributeString != nil);
                NSLog(@"Retrieved taskAttributeId: %@", self.taskAttributeString);
                
            } else {
                
                /*
                 if the retrievedAttribute array is empty then we check to see if the titleLabel
                 of the UIButton passed to us is a taskAttributeOption value as opposed to a 
                 taskAttribute value. In the former case, we make a call to the database to retrieve
                 the corresponding attributeOptionId
                 */
                NSFetchRequest *optionRequest = [NSFetchRequest fetchRequestWithEntityName:kTaskAttributeOptionEntity];
                assert(optionRequest != nil);
                NSPredicate *optionPredicate = [NSPredicate predicateWithFormat:@"attributeOptionName like[c] %@", attributeName];
                assert(optionPredicate != nil);
                [optionRequest setPredicate:optionPredicate];
                
                retrievedOption = [self.managedContext executeFetchRequest:optionRequest error:&optionError];
                assert(retrievedOption != nil);
                
                // Log errors
                if (optionError) {
                    [[QLog log] logOption:kLogOptionSyncDetails withFormat:
                     @"Encountered error: %@ during attributeOptionName fetch from Task Collection",[optionError localizedDescription]];
                } else {
                    
                    // get the attributeOptionId corresponding to the fetched attributeOptionName
                    if ([retrievedOption count] > 0) {
                        MzTaskAttributeOption *optionAttribute = [retrievedOption objectAtIndex:0];
                        self.taskAttributeString = optionAttribute.attributeOptionId;
                        assert(self.taskAttributeString != nil);
                        NSLog(@"Retrieved attributeOptionId: %@", self.taskAttributeString);
                    }
                }
            }
            
        }
        
        // We now setup a NSFetchedResultsController to retrieve all the attributeOptionName values
        // using the taskAttributeId we retrieved above
        NSFetchRequest *mrequest = [NSFetchRequest fetchRequestWithEntityName:kTaskAttributeOptionEntity];
        assert(mrequest != nil);
        [mrequest setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"taskAttribute"]];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"attributeOptionId like[c] %@", self.taskAttributeString];
        [mrequest setPredicate:predicate];
        NSSortDescriptor * sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"attributeOptionName" ascending:YES];
        NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
        [mrequest setSortDescriptors:sortDescriptors];
        
        NSFetchedResultsController *controller = [[NSFetchedResultsController alloc] initWithFetchRequest:mrequest managedObjectContext:self.managedContext sectionNameKeyPath:nil cacheName:nil];
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
            [[QLog log] logWithFormat:@"Error fetching from TaskAttributeOption Entity with error: %@", error.localizedDescription];
        }
        
    } else {
        
        // In this case, where our modal Button is nil, the user has tapped the categoryButton
        // in the tableView HeaderView so we retrieve from the MzTaskType entity
        
        NSFetchRequest *categoryRequest = [NSFetchRequest fetchRequestWithEntityName:kTaskTypeEntity];
        assert(categoryRequest != nil);
        NSSortDescriptor * sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"taskTypeName" ascending:YES];
        NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
        [categoryRequest setSortDescriptors:sortDescriptors];
        NSFetchedResultsController *controller = [[NSFetchedResultsController alloc] initWithFetchRequest:categoryRequest managedObjectContext:self.managedContext sectionNameKeyPath:nil cacheName:nil];
        assert(controller != nil);
        self.categoryFetchController = controller;
        
        // Execute the fetch
        NSError *error = NULL;
        self.fetchSucceeded = [self.categoryFetchController performFetch:&error];
        
        // Log success
        if (self.fetchSucceeded) {
            [[QLog log] logWithFormat:@"Success: Fetched %d objects from the Task Collection data store", [[self.categoryFetchController fetchedObjects] count]];
        }
        
        //Log error
        if (error) {
            [[QLog log] logWithFormat:@"Error fetching from TaskType Entity with error: %@", error.localizedDescription];
        }
    }        
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.managedContext = nil;
    self.fetchController = nil;
    self.taskAttributeString = nil;
    self.modalButton = nil;
    self.categoryFetchController = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{

    // Return the number of rows in the section.
    if (self.modalButton != nil) {
        
        return [[self.fetchController fetchedObjects] count];
        
    } else {
        
        return [[self.categoryFetchController fetchedObjects] count];
    }    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"kAttributeOptionCellId";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell...
    if (self.modalButton != nil) {
        
        MzTaskAttributeOption *attributeOption = [[self.fetchController fetchedObjects] objectAtIndex:indexPath.row];
        assert(attributeOption != nil);
        cell.textLabel.text = attributeOption.attributeOptionName;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];
    } else {
        
        MzTaskType *taskType = [[self.categoryFetchController fetchedObjects] objectAtIndex:indexPath.row];
        assert(taskType != nil);
        cell.textLabel.text = taskType.taskTypeName;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];
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
    // Get the user's selection
    NSString *selectedString;
    if (self.modalButton != nil) {
        MzTaskAttributeOption *attributeOption = [[self.fetchController fetchedObjects] objectAtIndex:indexPath.row];
        assert(attributeOption != nil);
        selectedString = attributeOption.attributeOptionName;
        assert(selectedString != nil);
    } else {
        
        MzTaskType *taskType = [[self.categoryFetchController fetchedObjects] objectAtIndex:indexPath.row];
        assert(taskType != nil);
        selectedString = taskType.taskTypeName;
        assert(selectedString != nil);
    }
        
    //Pass user's selection to our delegate - this method also causes our delegate to dismiss us
    [self.delegate controller:self selection:selectedString];
}

@end
