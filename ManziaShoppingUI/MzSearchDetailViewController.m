//
//  MzSearchDetailViewController.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 9/21/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzSearchDetailViewController.h"

@interface MzSearchDetailViewController ()

@property (nonatomic, strong) NSArray *searchOptionKeys;

@end

@implementation MzSearchDetailViewController

@synthesize searchItem;
@synthesize searchOptionKeys;

// String indicating no selection
static NSString *kNoOptionSelected = @"None";

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
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.searchItem = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    assert(self.searchItem.searchOptions != nil);
    self.searchOptionKeys = [self.searchItem.searchOptions allKeys];
    assert(self.searchOptionKeys != nil);
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.searchOptionKeys = nil;
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
    // Return the number of rows in the section. This is equivalent to the number of entries
    // in the searchOptions dictionary of our assigned searchItem.
    assert(self.searchOptionKeys!= nil);
    
    return [self.searchOptionKeys count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"kSearchDetailCellId";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell...
    NSString *attributeKey;
    NSString *attributeValue;
    
    attributeKey = [self.searchOptionKeys objectAtIndex:indexPath.row];
    assert(attributeKey != nil);
    attributeValue = [self.searchItem.searchOptions objectForKey:attributeKey];
    assert(attributeValue != nil);
    
    // compare the keys to values
    if ([attributeKey isEqualToString:attributeValue]) {
        
        //In this case, user made no selection
        cell.textLabel.text = attributeKey;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
        cell.textLabel.textAlignment = UITextAlignmentRight;
        cell.detailTextLabel.text = kNoOptionSelected;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14.0];
        cell.detailTextLabel.textAlignment = UITextAlignmentLeft;
    } else {
        
        // In this case the user made a selection
        cell.textLabel.text = attributeKey;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
        cell.textLabel.textAlignment = UITextAlignmentRight;
        cell.detailTextLabel.text = attributeValue;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14.0];
        cell.detailTextLabel.textAlignment = UITextAlignmentLeft;
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
