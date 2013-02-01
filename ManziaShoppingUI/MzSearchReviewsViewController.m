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

@interface MzSearchReviewsViewController ()

@property (nonatomic, strong) NSFetchedResultsController *fetchController;
@property (nonatomic, strong) NSManagedObjectContext *managedContext;

@end

@implementation MzSearchReviewsViewController

// Synthesizers
@synthesize categoryButton;
@synthesize pickerView;
@synthesize searchBar;
@synthesize segmentedControl;
@synthesize fetchController;

// Database entity that we fetch from
static NSString *kTaskTypeEntity = @"MzTaskType";
static NSString *kQueryTypeInclude = @"Include";
static NSString *kQueryTypeExclude = @"Exclude";

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
    
    // We can now initialize our NSFetchedResultsController
    NSFetchRequest *mrequest = [NSFetchRequest fetchRequestWithEntityName:kTaskTypeEntity];
    assert(mrequest != nil);
    NSSortDescriptor *sortDescriptorType = [[NSSortDescriptor alloc] initWithKey:@"taskTypeName" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptorType, nil];
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
        [[QLog log] logWithFormat:@"Error fetching Categories to display from TaskTypes Entity: %@", error.localizedDescription];
        self.fetchController = nil;
    }
    
    // Set up the categoryButton
    assert(self.categoryButton != nil);
    [self.categoryButton addTarget:self action:@selector(selectCategory) forControlEvents:UIControlEventTouchUpInside];
    
}

// View Lifecycle
-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Keep the UIPickerView hidden until user taps the categoryButton
    assert(self.pickerView != nil);
    self.pickerView.hidden = YES;
    
    //
}


#pragma mark * UIPickerView DataSource Methods

// UIPickerView component count = 1
-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// UIPickerView row count per component
-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    // we return zero rows if we did not fetch any MzTaskTypes from the database
    if (self.fetchController != nil) {
        return [[self.fetchController fetchedObjects] count];
    } else {
        return 0;
    }
}

#pragma mark * UIPickerView Delegate Methods

// Return the appropriate category
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    assert(self.fetchController != nil);
    NSArray *categories = [[self.fetchController fetchedObjects] valueForKey:@"taskTypeName"];
    assert(categories != nil);
    return [categories objectAtIndex:row];
}

// Respond to a selection
- (void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    // Assign the selected String to the category UIButton
    assert(self.fetchController != nil);
    NSArray *categories = [[self.fetchController fetchedObjects] valueForKey:@"taskTypeName"];
    assert(categories != nil);
    NSString *selectedCategory = [categories objectAtIndex:row];
    assert(self.categoryButton != nil);
    assert(selectedCategory != nil);
    [self.categoryButton setTitle:selectedCategory forState:UIControlStateNormal];
    
    // Dismiss the UIPickerView from view
    self.pickerView.hidden = YES;    
}

// Bring up the UIPickerView
-(void)selectCategory
{
    assert(self.pickerView != nil);
    self.pickerView.hidden = NO;
}

#pragma mark * Memory Management

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark * Search Query Management

// User selects a query Type - Include or Exclude
-(IBAction)selectedQueryType:(id)sender
{
    NSString *queryType = [self.segmentedControl titleForSegmentAtIndex:self.segmentedControl.selectedSegmentIndex];
    assert(queryType != nil);
    
    if ([queryType isEqualToString:kQueryTypeInclude]) {
        
    } else if ([queryType isEqualToString:kQueryTypeExclude]) {
        
    }
}


@end
