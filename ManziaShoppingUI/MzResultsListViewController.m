//
//  MzResultsListViewController.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzResultsListViewController.h"
#import "MzSearchItem.h"
#import "MzAppDelegate.h"
#import "Logging.h"
#import "MzSearchCollection.h"
#import "MzProductCollection.h"

@interface MzResultsListViewController ()

// Dictionary with Search URLs as Keys and associated Product Collection cache directories
// as Values
@property (nonatomic, strong, readwrite) NSMutableDictionary *productSearchMap;

@end

@implementation MzResultsListViewController

@synthesize productSearchMap;

// Base URL for Search URLs
static NSString *manziBaseURL = @"http://192.168.1.102:8080/ManziaWebServices/searches";

// SearchItem's Title string separator, format is "Brand Category" e.g "HP Laptop"
static NSString *kSearchTitleSeparator = @" ";

// SearchItem Keys
static NSString *kSearchCategoryKey = @"Category";
static NSString *KSearchPriceKey = @"Regular Price";
static NSString *KSearchProfileKey = @"Profile";

// Extension for the ProductCollection Cache directory
static NSString * kCollectionExtension    = @"collection";
static NSString * kCollectionFileName = @"ProductCollectionInfo.plist";
static NSString * kCollectionKeyCollectionURLString = @"collectionURLString";

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
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Search URL creation

- (NSURL *)createURLFromSearchItem:(MzSearchItem *)aSearchItem
{
    // check input
    if (aSearchItem == nil) { return nil;   }
    
    // Create the Path Parameters
    NSString *deviceId = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] uniqueDeviceId];
    assert(deviceId != nil);
    NSString *deviceDays = [aSearchItem.daysToSearch stringValue];
    assert(deviceDays != nil);
    NSString *deviceStatus = [[NSNumber numberWithInt:aSearchItem.searchStatus] stringValue];
    assert(deviceStatus != nil);
    NSString *deviceProfile = [aSearchItem.searchOptions objectForKey:KSearchProfileKey];
    assert(deviceProfile != nil);
    NSString *pathString = [NSString stringWithFormat:@"/%@/%@/%@/%@", deviceId, deviceDays, deviceStatus, deviceProfile];
    assert(pathString != nil);
    assert(pathString.length > 0);
    
    // Create the Query Parameters
    NSString *queryCategory = [[aSearchItem.searchTitle componentsSeparatedByString:kSearchTitleSeparator] objectAtIndex:1];
    assert(queryCategory != nil);
    NSMutableDictionary * queryOptions = [NSMutableDictionary dictionaryWithDictionary:aSearchItem.searchOptions];
    assert(queryOptions != nil);
    [queryOptions setObject:queryCategory forKey:kSearchCategoryKey];
    [queryOptions setObject:[aSearchItem.priceToSearch stringValue] forKey:KSearchPriceKey];
    
    // Generate the query String
    __block NSString *queryString = [NSString string];
    [queryOptions enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        NSString *queryParam = [NSString stringWithFormat:@"%@=%@", key, value];
        queryString = [queryString stringByAppendingFormat:@"%@&", queryParam];
    }];
    
    // Remove the last & ampersand
    assert(queryString.length > 0);
    queryString = [queryString substringToIndex:[queryString length] - 1];
    
    // Create URL
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", pathString, queryString];
    assert(urlString != nil);
    NSURL *searchURL = [NSURL URLWithString:urlString relativeToURL:[NSURL URLWithString:manziBaseURL]];
    assert(searchURL != nil);
    
    //Log
    [[QLog log] logWithFormat:@"Created Search URL: %@", [searchURL absoluteString]];
    return searchURL;        
}

#pragma mark - Generate Product Collection

/*
 This method operates asynchronously so as not to block the main thread and does the
 following
 1- retrieve all the MzSearchItems in the MzSearchCollection
 2- For all active MzSearchItems, generate a Search URL for each
 3- Iterate through the Product Collection caches, and the compare the collection's URL string
 stored in the cache .pList file to the Search URL
 4- If there is no match for a Search URL, instantiate a new Product Collection and start 
 Synchronizing (i.e hit the network to retrieve ProductItems asynchrounously)
 5- If a collection's URL string has no associated Search URL, mark that collection for
 deletion
 6- Generate a Dictionary whose Keys are the Search URLs and Values are the associated Product
 Collection cache Path
 7- Add the Product Collection caches and associated Search URLs to the dictonary in 6 above
 8- Assign the dictionary to an ivar - since the MzResultListViewController is "alive" throughout
 the app lifetime becoz its child of a NavgiationController that a child of TabBarController
 that's loaded automatically by the app from the storyboard, we'll always have access to this
 dictionary
 
 NOTE: The first time the App is launched and MzSearchItems are created this method will actually
 result in the creation of new Product Collections and their synchronization but afterwards its
 anticipated that all existing Product Collection caches will always have an active Search Item
 associated with them so there will be no need for synchronization. This is because this class
 MzResultListViewController is a delegate to the MzSearchListViewController and so gets notified
 whenever a MzSearchItem is created or deleted so as to keep the Product Collection caches up to
 date
 */
-(NSDictionary *)generateProductCollections
{
    // Retrieve all the MzSearchItems
    MzSearchCollection *scollection = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] searchCollection];
    assert(scollection != nil);
    NSArray *searchItems = [scollection allSearchItems];
    assert(searchItems != nil);
    
    if ([searchItems count] > 0) {
        
    }
}

// Returns a path to the CachesDirectory
-(NSString *)pathToCachesDirectory
{
    NSString *cacheDir;
    NSArray *cachesPaths;
    
    cacheDir = nil;
    cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ( (cachesPaths != nil) && ([cachesPaths count] != 0) ) {
        assert([[cachesPaths objectAtIndex:0] isKindOfClass:[NSString class]]);
        cacheDir = [cachesPaths objectAtIndex:0];
    }
    return cacheDir;
}

/* For each Product Collection cache
 1- Iterate through all the Search URLs from the input searchArray
 2- If there is a match, add an entry to the productSearckMap
 3- If there is no match, mark the Product Collection for deletion
 4- For the unmatched Search URLs, instantiate new Product Collection Caches
*/
-(void)updateProductCollectionCaches:(NSArray *)searchArray
{
    assert(searchArray != nil);
    if ([searchArray count] > 0) {
        
        NSString *productCachesDir = [self pathToCachesDirectory];
        assert(productCachesDir != nil);
        
        NSFileManager *fileManager;
        NSArray *possibleCollections;
        NSString *searchResult;
        NSMutableArray *collectionsToDelete;
        
        // Iterate through the Caches Directory and sub-Directories and check each plist
        // file encountered
        fileManager = [NSFileManager defaultManager];
        assert(fileManager != nil);
        
        possibleCollections = [fileManager contentsOfDirectoryAtPath:productCachesDir error:NULL];
        assert(possibleCollections != nil);
                
        searchResult = nil;
        for (NSString *collectionName in possibleCollections) {
            if ([collectionName hasSuffix:kCollectionExtension]) {
                
                NSDictionary *collectionInfo;
                NSString *collectionInfoURLString;
                
                collectionInfo = [NSDictionary dictionaryWithContentsOfFile:[[productCachesDir stringByAppendingPathComponent:collectionName] stringByAppendingPathComponent:kCollectionFileName]];
                if (collectionInfo != nil) {
                    collectionInfoURLString = [collectionInfo objectForKey:kCollectionKeyCollectionURLString];
                                        
                    // Iterate over the array of Search URLs
                    for (NSString *searchURL in searchArray) {
                        if ( [searchURL isEqual:collectionInfoURLString] ) {
                            searchResult = [productCachesDir stringByAppendingPathComponent:collectionName];
                            [self.productSearchMap setObject:searchResult forKey:searchURL];
                            break;
                        }                    
                    }
                    
                }
            }
        }
        
        // Log
        [[QLog log] logWithFormat:@"Found %d existing Product Collections with KNOWN Search URLs", [self.productSearchMap count]];
        
        // Do the Updates
        // 1- All search URLs not in the productSearchMap are to be created
        // 2- All the Collection Caches not in the productSearchMap are to be deleted
        NSMutableSet *addSearches = [NSMutableSet setWithArray:searchArray];
        assert(addSearches != nil);
        NSMutableSet *deleteCollections = [NSMutableSet setWithArray:possibleCollections];
        assert(deleteCollections != nil);
        
        // Note that we'll have empty sets if the productSearchMap is empty which is fine
        NSSet *existingSearches = [NSSet setWithArray:[self.productSearchMap allKeys]];
        assert(existingSearches != nil);
        NSSet *existingCollections = [NSSet setWithArray:[self.productSearchMap allValues]];
        assert(existingCollections != nil);
        
        // Update
        [addSearches minusSet:existingSearches];
        [deleteCollections minusSet:existingCollections];
        
        // Mark for deletion by deleting the Collection pList file which causes the Collection Cache
        // to be deleted when the App goes into background
        [[QLog log] logWithFormat:@"Deleting %d Product Collections with UNKNOWN Search URLs", [deleteCollections count]];
        [deleteCollections enumerateObjectsUsingBlock:^(NSString *cachePath, BOOL *stop) {
            [MzProductCollection markForRemoveCollectionCacheAtPath:cachePath];
        }];
        
        // Asynchrouously instantiate and synchronize new Product Collections, then add them to our
        // productSearchMap
        [[QLog log] logWithFormat:@"Creating %d Product Collections for NEW Search URLs", [addSearches count]];
        

    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
#warning Incomplete method implementation.
    // Return the number of rows in the section.
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell...
    
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
