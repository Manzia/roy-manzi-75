//
//  MzQualitiesListViewController.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 2/24/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzQualitiesListViewController.h"
#import "MzQualitiesListCell.h"
#import "MzQualityCollection.h"

@implementation MzQualitiesListViewController

@synthesize qualityArray;
@synthesize qCollection;

static NSString *kQualitiesCellIdentifier = @"kQualitiesDetailCellId";

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
    
    assert(self.qualityArray != nil);
    assert(self.qCollection != nil);
    
    // Test - Print the qualityArray values
    for (NSString *quality in self.qualityArray) {
        NSLog(@"Quality in Pushed Array: %@", quality);
    }
}

-(void)viewDidUnload
{
    self.qualityArray = nil;
    [super viewDidUnload];
}

-(void)viewWillAppear:(BOOL)animated
{
    assert(self.qualityArray != nil);
    [super viewWillAppear:animated];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    return [self.qualityArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    MzQualitiesListCell *cell = (MzQualitiesListCell *)[tableView dequeueReusableCellWithIdentifier:kQualitiesCellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    assert(cell != nil);
    cell.qualityLabel.text = [[self.qualityArray objectAtIndex:indexPath.row] copy];
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

#pragma mark - Qualities

// Save User Qualities
-(IBAction)saveQualities:(id)sender
{
    assert(self.qCollection != nil);
    assert(self.qualityArray != nil);
    if ([self.qualityArray count] > 0) {
        for (NSString *quality in self.qualityArray) {
            [self.qCollection addProductQuality:quality];
        }        
    }
}

@end
