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
#import "MzResultListCell.h"
#import "MzProductItem.h"
#import "MzResultsDetailViewController.h"
#import "MzReviewsListViewController.h"

@interface MzResultsListViewController ()

// Dictionary with Search URLs as Keys and associated Product Collection cache directories
// as Values
@property (nonatomic, strong, readonly) NSMutableDictionary *productSearchMap;

//Dictionary with Search URLs as Keys and associated MzSearchItem as Value
@property (nonatomic, strong, readonly) NSMutableDictionary *allSearches;

//Dictionary with Product Collection cache names as Keys and an NSArray of fetched productItems
// as the Value
@property (nonatomic, strong, readonly) NSMutableDictionary *allProductItems;

// Array that keeps track of all the active Collections for this View Controller
// and also keeps them alive for the lifetime of this View Controller and also ensure
// a Product Collection does not get released while its still syncing etc.
@property (nonatomic, strong, readonly) NSMutableArray *activeCollections;

// Sorted Sections
@property(nonatomic, strong) NSArray *sortedSections;

// Device Identifier
@property (nonatomic, copy) NSString *deviceIdentifier;

// BOOLs that capture various possible scenarios
@property(nonatomic, assign) BOOL noSearchesFound;
@property(nonatomic, assign) BOOL noProductItemsFound;

// Array that keeps track of all MzProductItems whose thumbnailStatus property
// we are observing
@property (nonatomic, strong, readwrite) NSMutableArray *observedItems;

// String that keeps track of the user-selected Category of the current Search
@property (nonatomic, copy) NSString *searchCategory;

@end

@implementation MzResultsListViewController

@synthesize productSearchMap;
@synthesize allSearches;
@synthesize allProductItems;
@synthesize activeCollections;
@synthesize sortedSections;
@synthesize noProductItemsFound;
@synthesize noSearchesFound;
@synthesize deviceIdentifier;
@synthesize observedItems;
@synthesize searchCategory;

// Segue Identifier
static NSString *kResultsDetailId = @"KResultsDetailSegue";
static NSString *kReviewsListSegueId = @"kReviewsListSegue";

// Base URL for Search URLs
//static NSString *manziBaseURL = @"http://192.168.1.102:8080";
static NSString *manziaServerPath = @"/ManziaWebService/searches";

// SearchItem's Title string separator, format is "Brand Category" e.g "HP Laptop"
static NSString *kSearchTitleSeparator = @" ";

// SearchItem Keys
static NSString *kSearchCategoryKey = @"Category";
static NSString *KSearchPriceKey = @"Regular Price";
static NSString *KSearchProfileKey = @"Profile";

// Default User Profile - this value is assigned to the MzSearchItems whose KSearchProfileKey
// returns nil
static NSString *defaultUserProfile = @"average";

// For brevity in the UI we use "Phones" but the server expects "Mobile Phones" as the category
static NSString *kMobilePhonesCategory = @"Mobile Phones";
static NSString *kPhonesCategory = @"Phones";

// Extension for the ProductCollection Cache directory
static NSString * kCollectionExtension    = @"collection";
static NSString * kCollectionFileName = @"ProductCollectionInfo.plist";
static NSString * kCollectionKeyCollectionURLString = @"collectionURLString";

// KVO contexts - for each Product Collection cache we observe the "collectionCachePath"
// & "statusOfSync" properties
static void *NewProductCollectionContext = &NewProductCollectionContext;
static void *ExistingProductCollectionContext = &ExistingProductCollectionContext;
static void *ThumbnailStatusContext = &ThumbnailStatusContext;


- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self->productSearchMap = [NSMutableDictionary dictionary];
        assert(self.productSearchMap != nil);
        self->activeCollections = [NSMutableArray array];
        assert(self.activeCollections != nil);
        self->allProductItems = [NSMutableDictionary dictionary];
        assert(self.allProductItems != nil);
        self->allSearches = [NSMutableDictionary dictionary];
        assert(self.allSearches != nil);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Display an Edit button in the navigation bar for this view controller.
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Set our DeviceId
    self.deviceIdentifier = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] uniqueDeviceId];
    
    // Setup the Model Dictionaries. Note that the entries in these dictionaries can change
    // at any time during the lifetime of the ViewController. ProductItems can be removed or
    // added after ProductCollection synchronizations, SearchItems can be added or deleted at
    // any time by the user which also triggers deletions or insertions of associated
    // Product Collections.
    self->productSearchMap = [NSMutableDictionary dictionary];
    assert(self.productSearchMap != nil);
    self->activeCollections = [NSMutableArray array];
    assert(self.activeCollections != nil);
    self->allProductItems = [NSMutableDictionary dictionary];
    assert(self.allProductItems != nil);
    self->allSearches = [NSMutableDictionary dictionary];
    assert(self.allSearches != nil);
    
    // Search Dictionary
    NSDictionary *searchDict = [self generateSearchItemDictionary];
    if (searchDict != nil && [searchDict count] > 0) {
        [self.allSearches addEntriesFromDictionary:searchDict];
    } else {
        [[QLog log] logWithFormat:@"Could not create SearchItemDictionary of Search URLs!"];    
    }
    
    NSArray *searchArray = [self.allSearches allKeys];
    assert(searchArray != nil);
    if ([searchArray count] > 0) {
        self.noSearchesFound = NO;
        // Sets up all the other dictionaries
            [self updateProductCollectionCaches:searchArray];        
    } else {
        self.noSearchesFound = YES;
        [[QLog log] logWithFormat:@"Zero Search URLs were created..No SearchItems Found!"];
    }
}

- (void)viewDidUnload
{
    // Release all observers
    if ([self.activeCollections count] > 0) {
        for (MzProductCollection *collection in self.activeCollections) {
            [collection removeObserver:self forKeyPath:@"productItems" context:ExistingProductCollectionContext];
            [collection removeObserver:self forKeyPath:@"cacheSyncStatus" context:ExistingProductCollectionContext];
            [collection removeObserver:self forKeyPath:@"cachePath" context:
             NewProductCollectionContext];
            
            // Save all changes in the collections
            [collection saveCollection];
        }
    }
    
    // Release the Collections
    self->allSearches = nil;
    self->activeCollections = nil;
    self->allProductItems = nil;
    self->productSearchMap = nil;
    self.sortedSections = nil;
    
    // Release Category
    self.searchCategory = nil;
    
    [super viewDidUnload];
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Reload our tableView
    [self.tableView reloadData];
}

-(void) viewWillDisappear:(BOOL)animated
{
    // Remove all the MzProductItem observers
    if (self.observedItems != nil && [self.observedItems count] > 0) {
        [self.observedItems enumerateObjectsUsingBlock:^(MzProductItem *productItem, NSUInteger idx, BOOL *stop) {
            if (productItem.hasObserver) {
                [productItem removeObserver:self forKeyPath:@"thumbnailStatus" context:ThumbnailStatusContext]; 
            }
            productItem.hasObserver = NO;
        }];
    }
    // Release Array of Observed Items
    self.observedItems = nil;
    
    [super viewWillDisappear:animated];
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
    NSString *deviceId = self.deviceIdentifier;
    // self.deviceIdentifier will be nil if we are called from the MzSearchListViewControllerDelegate
    // methods since our view has not loaded and viewDidLoad has not yet been called.
    if (deviceId == nil)
        deviceId = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] uniqueDeviceId];
    assert(deviceId != nil);
    NSString *deviceDays = [aSearchItem.daysToSearch stringValue];
    assert(deviceDays != nil);
    NSString *deviceStatus = [[NSNumber numberWithInt:aSearchItem.searchStatus] stringValue];
    assert(deviceStatus != nil);
    NSString *deviceProfile = [aSearchItem.searchOptions objectForKey:KSearchProfileKey];
    if (deviceProfile == nil) {
        deviceProfile = defaultUserProfile;
    }
    assert(deviceProfile != nil);
    NSString *pathString = [NSString stringWithFormat:@"/%@/%@/%@/%@", deviceId, deviceDays, deviceStatus, deviceProfile];
    assert(pathString != nil);
    assert(pathString.length > 0);
    
    // Create the Query Parameters
    // Modified Feb 2, 2013 - Category Key is inserted in the MzSearchReviewsViewController
    /*NSString *queryCategory;
    if ([aSearchItem.searchTitle length] > 0) {
        queryCategory = [[aSearchItem.searchTitle componentsSeparatedByString:kSearchTitleSeparator] objectAtIndex:1];
    }    
    assert(queryCategory != nil);
    
    // Adjust the Mobile Phone category
    NSRange phonesRange = [queryCategory rangeOfString:kPhonesCategory options:NSCaseInsensitiveSearch];
    if (phonesRange.location != NSNotFound) {
        queryCategory = kMobilePhonesCategory;
    }*/
    
    NSMutableDictionary * queryOptions = [NSMutableDictionary dictionaryWithDictionary:aSearchItem.searchOptions];
    assert(queryOptions != nil);
    //[queryOptions setObject:queryCategory forKey:kSearchCategoryKey];
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
    NSString *urlString = [NSString stringWithFormat:@"%@%@?%@", manziaServerPath, pathString, queryString];
    assert(urlString != nil);
    NSString *encodedURLString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    assert(encodedURLString != nil);
    NSLog(@"Path & Query String: %@\n", encodedURLString);
    NSString *mzBaseURL = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] searchesURL];
    assert(mzBaseURL != nil);
    NSURL *searchURL = [NSURL URLWithString:encodedURLString relativeToURL:[NSURL URLWithString:mzBaseURL]];
    assert(searchURL != nil);
    
    //Log
    [[QLog log] logWithFormat:@"Created Search URL: %@", [searchURL absoluteString]];
    return searchURL;        
}

#pragma mark - Generate Product Collection

/*
 The methods in this section operate asynchronously so as not to block the main thread and do the
 following using KVO mostly:
 1- retrieve all the MzSearchItems in the MzSearchCollection
 2- For all active MzSearchItems, generate a Search URL for each
 3- Iterate through the Product Collection caches, and the compare the collection's URL string
 stored in the cache .pList file to the Search URL
 4- If there is no match for a Search URL, instantiate a new Product Collection and start 
 Synchronizing (i.e hit the network to retrieve ProductItems asynchrounously)
 5- If synchronization succeeds, then fetch the Product Collection's productItems else mark
 the new ProductCollection for deletion. This means we'll get a chance to re-sync when the viewDidLoad
 method of this viewController gets called the next time (i.e App moves from background)
 6- If a collection's URL string has no associated Search URL, mark that collection for
 deletion
 7- If there is a match for the Search URL, then instantiate the associated ProductCollection and
 fetch its ProductItems
 8- Populate the required Dictionaries that will be used as our tableView datasources
 
 The dictionaries are all ivars - since the MzResultListViewController is "alive" throughout
 the app's lifetime becoz its a child of a NavgiationController that's a child of the TabBarController
 that's loaded automatically by the app from the storyboard, we'll always have access to these
 dictionaries and associated ProductCollection objects
 
 NOTE: The first time the App is launched and MzSearchItems are created this method will actually
 result in the creation of new Product Collections and their synchronization but afterwards its
 anticipated that all existing Product Collection caches will always have an active Search Item
 associated with them so there will be no need for synchronization. This is because this class
 MzResultListViewController is a delegate to the MzSearchListViewController and so gets notified
 whenever a MzSearchItem is created or deleted so as to keep the Product Collection caches up to
 date
 */
-(NSDictionary *)generateSearchItemDictionary
{
    // Retrieve all the MzSearchItems
    NSMutableDictionary *searchDict;
    MzSearchCollection *scollection = [(MzAppDelegate *)[[UIApplication sharedApplication] delegate] searchCollection];
    assert(scollection != nil);
    
    /*
     Modified: Feb 01, 2013
     Instead of retrieving and using all "serialized" MzSearchItems, we only use the most recent one
     */
    //NSArray *searchItems = [scollection allSearchItems];
    NSArray *searchItems = [NSArray arrayWithObject:[scollection recentSearchItemInDirectory]];
    assert(searchItems != nil);
    
    if ([searchItems count] > 0) {
        searchDict = [NSMutableDictionary dictionary];
        for (MzSearchItem *searchItem in searchItems) {
            NSURL *sURL = [self createURLFromSearchItem:searchItem];
            assert(sURL != nil);
            [searchDict setObject:searchItem forKey:[sURL absoluteString]];
        }
        // Log
        [[QLog log] logWithFormat:@"Created %d Search URLs for SearchItems", [searchDict count]];
    }
    return searchDict;
}

// Returns a path to the CachesDirectory
-(NSURL *)pathToCachesDirectory
{
    NSURL *cacheDir;
    NSArray *cachesPaths;
    NSFileManager *fileMgr;
    fileMgr = [NSFileManager defaultManager];
    assert(fileMgr != nil);
    
    cachesPaths = [fileMgr URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];
    if ( (cachesPaths != nil) && ([cachesPaths count] != 0) ) {
        assert([[cachesPaths objectAtIndex:0] isKindOfClass:[NSURL class]]);
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
        
        NSURL *productCachesDir = [self pathToCachesDirectory];
        assert(productCachesDir != nil);
        
        NSFileManager *fileManager;
        NSArray *possibleCollections;
        NSURL *searchResult;
        NSMutableArray *actualCollections;
               
        // Iterate through the Caches Directory and sub-Directories and check each plist
        // file encountered
        fileManager = [NSFileManager defaultManager];
        assert(fileManager != nil);
        
        possibleCollections = [fileManager contentsOfDirectoryAtURL:productCachesDir includingPropertiesForKeys:nil
                                                            options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
        assert(possibleCollections != nil);
        actualCollections = [NSMutableArray array];
                
        searchResult = nil;
        if ([possibleCollections count] > 0) {
            for (NSURL *collectionName in possibleCollections) {
                if ([[collectionName lastPathComponent] hasSuffix:kCollectionExtension]) {
                    
                    [actualCollections addObject:collectionName];
                    NSDictionary *collectionInfo;
                    NSString *collectionInfoURLString;
                    
                    collectionInfo = [NSDictionary dictionaryWithContentsOfURL:[collectionName URLByAppendingPathComponent:kCollectionFileName]];
                    if (collectionInfo != nil) {
                        collectionInfoURLString = [collectionInfo objectForKey:kCollectionKeyCollectionURLString];
                        
                        // Iterate over the array of Search URLs
                        for (NSString *searchURL in searchArray) {
                            if ( [searchURL isEqual:collectionInfoURLString] ) {
                                searchResult = collectionName;
                                [self.productSearchMap setObject:searchResult forKey:searchURL];
                                break;
                            }                    
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
        NSMutableSet *deleteCollections = [NSMutableSet setWithArray:actualCollections];
        assert(deleteCollections != nil);
        
        // Note that we'll have empty sets if the productSearchMap is empty which is fine
        NSSet *existingSearches = [NSSet setWithArray:[self.productSearchMap allKeys]];
        assert(existingSearches != nil);
        NSSet *existingCollections = [NSSet setWithArray:[self.productSearchMap allValues]];
        assert(existingCollections != nil);
        
        // Update
        if ([self.productSearchMap count] > 0) {
            [addSearches minusSet:existingSearches];
            [deleteCollections minusSet:existingCollections];
        }        
        
        // Mark for deletion by deleting the Collection pList file which causes the Collection Cache
        // to be deleted when the App goes into background
        [[QLog log] logWithFormat:@"Deleting %d Product Collections with UNKNOWN Search URLs", [deleteCollections count]];
        
        if ([deleteCollections count] > 0) {
            [deleteCollections enumerateObjectsUsingBlock:^(NSURL *cachePath, BOOL *stop) {
                [MzProductCollection markForRemoveCollectionCacheAtPath:cachePath];
            }];        
        }        
        
        // Create serial Queue for all Collection Synchronization operations
        // NOTE: Creating another thread/queue messes up the NetworkManager RunLoop call-backs and the 
        // NetworkOperation action selectors are never called since this thread/queue is destroyed after the
        // startCollection or startSynchronization methods
        //dispatch_queue_t collectionQueue = dispatch_queue_create("CollectionStarter", DISPATCH_QUEUE_SERIAL);
        //assert(collectionQueue != nil);
        
        // Asynchrouously instantiate and synchronize new Product Collections, then add them to our
        // productSearchMap
        [[QLog log] logWithFormat:@"Creating %d Product Collections for NEW Search URLs", [addSearches count]];
        if ([addSearches count] > 0) {
            
                        
            // Enumerate
            [addSearches enumerateObjectsUsingBlock:^(NSString *sURL, BOOL *stop) {
                MzProductCollection *collection = [[MzProductCollection alloc] initWithCollectionURLString:sURL];
                assert(collection != nil);
                
                // Start observing the new collections
                [collection addObserver:self forKeyPath:@"cachePath" options:NSKeyValueObservingOptionNew context:NewProductCollectionContext];
                [collection addObserver:self forKeyPath:@"cacheSyncStatus" options:NSKeyValueObservingOptionNew context:ExistingProductCollectionContext];
                [collection addObserver:self forKeyPath:@"productItems" options:NSKeyValueObservingOptionNew context:ExistingProductCollectionContext];
                
                // Start the collections asychronously
                //dispatch_async(collectionQueue, ^{
                    [collection startCollection];
               // });              
                
                [self.activeCollections addObject:collection]; 
            }];
            
        }
        
        // Retrieve the ProductItems for the existing Product Collections
        if ([existingSearches count] > 0) {
            [[QLog log] logWithFormat:@"Fetching from %d Product Collections with KNOWN Search URLs", [existingSearches count]];
            
            [existingSearches enumerateObjectsUsingBlock:^(NSString *sURL, BOOL *stop) {
                if (![self searchURLHasActiveCollection:sURL]) {
                    
                    MzProductCollection *collection = [[MzProductCollection alloc] initWithCollectionURLString:sURL];
                    assert(collection != nil);
                    
                    // We only observe the "productItems" and "statusOfSync" properties
                    [collection addObserver:self forKeyPath:@"productItems" options:NSKeyValueObservingOptionNew context:ExistingProductCollectionContext];
                    [collection addObserver:self forKeyPath:@"cacheSyncStatus" options:NSKeyValueObservingOptionNew context:ExistingProductCollectionContext];
                    
                    // Get the ProductItems (method below is asynchronous as well)
                    [collection fetchProductsInCollection];
                    [self.activeCollections addObject:collection];
                    //dispatch_async(collectionQueue, ^{
                    [collection startSynchronization:nil];
                   // });   
                } else {
                    
                    // Check if we have already fetched ProductItems from the ProductCollection
                    if (![self didAlreadyFetchProductsForSearchURL:sURL]) {
                        if (self.allProductItems != nil) {
                            MzProductCollection *collection = [self collectionForActiveSearchURL:sURL];
                            assert(collection != nil);
                            
                            // Get the current ProductItems if any and also re-synchronize
                            [collection fetchProductsInCollection];
                            //dispatch_async(collectionQueue, ^{
                            [collection startSynchronization:nil];
                            //});          
                                                      
                        } else {
                            [[QLog log] logWithFormat:@"Dictionary of ProductItems is NIL so did NOT fetch Products for provided Search URL!"]; 
                        }
                    } 
                }
            }];
        }
        // Release the Queue (will actually release when queue is empty)
        //dispatch_release(collectionQueue);
    }
    // Log
    [[QLog log] logWithFormat:@"Number of Active Collections instantiated: %d", [self.activeCollections count]];
}

// Helper method that returns the already instantiated MzProductCollection object associated with a given
// search URL. Returns nil if no instantiated MzProductCollection object is associated with the given
// search URL.
-(MzProductCollection *)collectionForActiveSearchURL:(NSString *)searchURL
{
    if (searchURL == nil || self.activeCollections == nil) {
        [[QLog log] logWithFormat:@"Array of Active Collections OR provided Search URL is NIL!"];
        return nil;
    }
    
    if ([self.activeCollections count] == 0) {
        return nil;
    }
    
    // Search
    NSUInteger searchIndex = [self.activeCollections indexOfObjectPassingTest:
                              ^(MzProductCollection *collection, NSUInteger idx, BOOL *stop) {
                                  if([collection.collectionURLString isEqualToString:searchURL]) {
                                      *stop = YES;
                                      return YES;
                                  } else { return NO; }
                              }];
    if (searchIndex != NSNotFound) {
        return [self.activeCollections objectAtIndex:searchIndex];
    } else { return nil; }
                                              
}

// Helper method to determine if we already have an active ProductCollection object for a given Search URL
// string. Returns YES if we do and NO if we dont.
-(BOOL)searchURLHasActiveCollection:(NSString *)searchURL
{
    BOOL success;
    MzProductCollection *collection = [self collectionForActiveSearchURL:searchURL];
    success = collection == nil ? NO : YES;
    return success;
}

// Helper method to determine if we've already fetched ProductItems from the ProductCollection associated with
// the given search URL, returns YES if we have else NO for all other scenarios including NIL input
-(BOOL)didAlreadyFetchProductsForSearchURL:(NSString *)searchURL
{
    // check input
    if (searchURL == nil || self.allProductItems == nil) { 
        [[QLog log] logWithFormat:@"Dictionary of all ProductItems OR provided Search URL is NIL!"];
        return NO; }
    
    if ([self.allProductItems count] == 0) { return NO; }
    
    // Search
    BOOL success = NO;
    MzProductCollection *collection = [self collectionForActiveSearchURL:searchURL];
    if (collection == nil) {
        return success;
    } else {
        NSString *productsKey = [collection.collectionCachePath path];
        assert(productsKey != nil);
        NSArray *productItems = [self.allProductItems objectForKey:productsKey];
        success = productItems != nil ? YES : NO;
    }
    return success;
}

// KVO implementation
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == NewProductCollectionContext) {
        
        // We are dealing with a newly created ProductCollection
        if ([keyPath isEqualToString:@"cachePath"]) {
            assert([object isKindOfClass:[MzProductCollection class]]);
            if ((change != nil) && ([[change objectForKey:NSKeyValueChangeKindKey] intValue] == NSKeyValueChangeSetting)) {
                
                // Assign the newly created ProductCollection
                NSDictionary *cacheDict = [change objectForKey:NSKeyValueChangeNewKey];
                assert([cacheDict count] > 0);
                [self.productSearchMap addEntriesFromDictionary:cacheDict];
                [[QLog log] logWithFormat:@"Success adding Product Collection Cache Name to MzResultListViewController at Path: %@", [[[cacheDict allValues] objectAtIndex:0] path ]];
            }                
        }
                
    } else if (context == ExistingProductCollectionContext) {
        
        // We are dealing with a existing ProductCollection
        if ([keyPath isEqualToString:@"productItems"]) {
            assert([object isKindOfClass:[MzProductCollection class]]);
            if ((change != nil) && ([[change objectForKey:NSKeyValueChangeKindKey] intValue] == NSKeyValueChangeSetting)) {
                
                // Assign the new dictionary
                // NOTE: if the key (ProductCollection) already exists in the allProductItems
                // dictionary the old NSArray will be replaced with the new one.
                NSDictionary *productDict = [change objectForKey:NSKeyValueChangeNewKey];
                assert(productDict != nil);
               // NSLog(@"Delegate was called with %d productItems", [productDict count]);
                if ([productDict count] > 0) {
                    NSUInteger prodCount = [[[productDict allValues] objectAtIndex:0] count];
                    [allProductItems addEntriesFromDictionary:productDict];
                    [[QLog log] logWithFormat:@"Success adding %d ProductItems from Product Collection Cache at Path: %@", prodCount, [[productDict allKeys] objectAtIndex:0]];
                    
                    // We also reload our tableView since we have new ProductItems
                    [self.tableView reloadData];                    
                }
            }
        }
        // In this case, an existing ProductCollection was refreshed/re-synchronized in which case
        // if the sync succeeded we re-fetch its productItems else we mark for deletion.
        if ([keyPath isEqualToString:@"cacheSyncStatus"]) {
            assert([object isKindOfClass:[MzProductCollection class]]);
            
            if ((change != nil) && ([[change objectForKey:NSKeyValueChangeKindKey] intValue] == NSKeyValueChangeSetting)) {
                
                NSDictionary *statusDict = [change objectForKey:NSKeyValueChangeNewKey];
                assert([statusDict count] > 0);
                NSString *statusValue = [[statusDict allValues] objectAtIndex:0];
                NSURL *collectionName = [[statusDict allKeys] objectAtIndex:0];
                
                if ([statusValue isEqualToString:@"Update Failed"] || [statusValue isEqualToString:@"Update cancelled"] ) {
                    
                    // Mark the ProductCollection for deletion
                    [[QLog log] logWithFormat:@"Marked for deletion after Update Failed/Cancelled for Product Collection Cache at Path: %@", [collectionName path ]];
                    [MzProductCollection markForRemoveCollectionCacheAtPath:collectionName];
                    
                    // Remove from activeCollections array
                    if ([self.activeCollections count] > 0) {
                        
                        [[QLog log] logWithFormat:@"Deleting MzProductCollection object after Update Failed/Cancelled at Path: %@", [collectionName path ]];
                        [self.activeCollections removeObjectIdenticalTo:object];
                    }               
                    
                } else if ([statusValue hasPrefix:@"Updated:"]) {
                    
                    // Synchronization succeeded so we re-fetch the ProductItems
                    if ([self.activeCollections count] > 0) {
                        
                        NSUInteger colIndex = [self.activeCollections indexOfObjectIdenticalTo:object];
                        if (colIndex != NSNotFound) {
                            [[QLog log] logWithFormat:@"Re-fetching ProductItems after re-synchronization for existing Product Collection Cache at Path: %@", [collectionName path ]];
                            [[self.activeCollections objectAtIndex:colIndex] fetchProductsInCollection];
                            
                            // save the collection that was updated
                            [[self.activeCollections objectAtIndex:colIndex] saveCollection];
                        }                        
                    }                    
                }                
            }
        }
    } else if (context == ThumbnailStatusContext) {
        
        // A Thumbnail has changed
        if ( [keyPath isEqualToString:@"thumbnailStatus"]) {
            assert([object isKindOfClass:[MzProductItem class]]);
            if ((change != nil) && ([[change objectForKey:NSKeyValueChangeKindKey] intValue] == NSKeyValueChangeSetting))
            {
                /* We do the following to update the Thumbnails on the visible cells
                 NOTE: Each time the dataSource (i.e self) is asked for a Cell via the "cellForRowAtIndexPath" method
                 we call the "getthumbnailImage" method of the MzProductItem we assigned to the Cell which returns
                 a PlaceHolder image or the actual Thumbnail. To get the actual Thumbnail, the method queries the
                 database and if no Thumbnail is available hits the network asynchronously. The only time we get called
                 in this "observeValueForKeyPath:..." method is if the actual Thumbnail was successfully fetched from
                 the network (either initially or via an update) in which case we do the following
                 1- Query the currently visible cells in our tableView to determine which one was assigned the MzProductItem that has notified us in this "observeValueForKeyPath:..." method. (We avoid calling the "reloadData" method on the tableView, since this will call the "getthumbnailImage" method again on each cell that will stop any GET and RESIZE operations that may be in progress for that cell's MzProductItem)
                 2- Set the retrieved Cell's imageView's image property to the actual Thumbnail and remove ourself as
                 the observer of the MzProductItems in our "viewWillDisappear" method
                 
                 NOTE ALSO: Its possible for a Cell to become visible, call the "getthumbnailImage" method and before the
                 actual Thumbnail image is returned, the Cell goes off screen and even off the tableView's reuse queue.
                 This is OK, since the MzProductItem assigned to each cell is retained in our allProductItems dictionary
                 so the next Cell that is dequeued and assigned this MzProductItem will not have to do a fetch off the
                 network as the actual Thumbnail will have already been fetched and persisted in the database.            
                 */
                NSString *thumbnailState = [change objectForKey:NSKeyValueChangeNewKey];
                if (thumbnailState != nil && [thumbnailState isEqualToString:@"Small Thumbnail"]) {
                    NSArray *cellsInView = [self.tableView visibleCells];
                    assert(cellsInView != nil);
                    if ([cellsInView count] > 0) {
                        NSUInteger sameProductItem = [cellsInView indexOfObjectPassingTest:
                                                      ^(MzResultListCell *cell, NSUInteger idx, BOOL *stop) {
                                                          if (cell.productItem == object) {
                                                              *stop = YES;
                                                              return YES;
                                                          } else { return NO; }
                                                      }];
                        if (sameProductItem != NSNotFound) {
                            MzResultListCell *updatedCell = [cellsInView objectAtIndex:sameProductItem];
                            UIImage *cellImage = [object getthumbnailImage:kSmallThumbnailImage];
                            assert(cellImage != nil);
                            updatedCell.productImage.image = cellImage;                            
                        }
                    }
                }
                
                
            }
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    if (self.noSearchesFound) {
        return 1;
    } else {
        if ([self.allSearches count] > 1) {
            self.sortedSections = [self.allSearches keysSortedByValueUsingComparator:^(MzSearchItem *searchOne, MzSearchItem *searchTwo) {
                return [searchOne.searchTimestamp compare:searchTwo.searchTimestamp];
            }];
            self.noSearchesFound = NO;
        } else {
            self.sortedSections = [self.allSearches allKeys];
            if ([self.sortedSections count] == 0) {
                self.noSearchesFound = YES;
                return 1;
            }            
        }
        return [self.sortedSections count];
    }    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section. First we sort by timestamp
    // Sort the array of sections (i.e, one section per SearchItem)
    if (self.noSearchesFound) {
        return 1;
    }
    assert(self.sortedSections != nil);
    NSURL *collectionName = [self.productSearchMap objectForKey:[self.sortedSections objectAtIndex:section]];
    if (collectionName == nil) {
        self.noProductItemsFound = YES;
        return 1;
    } else {
        self.noProductItemsFound = NO;
    }
    
    // Get the array of ProductItems
    NSArray *productsInSection = [self.allProductItems objectForKey:[collectionName path]];
    if(productsInSection == nil || [productsInSection count] == 0) {
        self.noProductItemsFound = YES;
        return 1;
    } else {
        self.noProductItemsFound = NO;
        return [productsInSection count];
    }    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"KResultProductCellId";
    MzResultListCell *cell = (MzResultListCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    assert(cell != nil);
    
    // Configure the cell...
    if (self.noSearchesFound) {
        
        // we have 1 section and 1 row in tableView and no SearchItems to display
        cell.productTitle.text = @"No Searches to Display";
        cell.productTitle.textColor = [UIColor redColor];
        cell.productTitle.textAlignment = UITextAlignmentLeft;
        cell.productPrice.text = nil;
        cell.priceLabel.text = nil;
        cell.productTitle.font = [UIFont systemFontOfSize:15.0];
        cell.selectedReviews.hidden = YES;
        cell.userInteractionEnabled = NO;
        cell.selectedReviews.userInteractionEnabled = NO;
    } else {
        
        // we have Searches to display
        assert(self.sortedSections != nil);
        NSArray *productsInSection;
        NSURL *collectionName = [self.productSearchMap objectForKey:[self.sortedSections objectAtIndex:indexPath.section]];
        self.noProductItemsFound = collectionName == nil ? YES : NO;
        if (collectionName != nil) {
            productsInSection = [self.allProductItems objectForKey:[collectionName path]];
            self.noProductItemsFound = productsInSection == nil ? YES : NO;
            self.noProductItemsFound = [productsInSection count] > 0 ? NO : YES;
        }      
        
        if (self.noProductItemsFound) {
            // we may have a section with no ProductItems to display
            cell.productTitle.text = @"No Products Found";
            cell.productTitle.textColor = [UIColor redColor];
            cell.productTitle.textAlignment = UITextAlignmentLeft;
            cell.productPrice.text = nil;
            cell.priceLabel.text = nil;
            cell.productTitle.font = [UIFont systemFontOfSize:15.0];
            cell.selectedReviews.hidden = YES;
            cell.selectedReviews.userInteractionEnabled = NO;
            cell.userInteractionEnabled = NO;
        } else {
            MzProductItem *productItem = [productsInSection objectAtIndex:indexPath.row];
            assert(productItem != nil);
            cell.productItem = productItem;
            //cell.productTitle.text = productItem.productTitle;
            //cell.productTitle.textAlignment = UITextAlignmentCenter;
            //cell.productPrice.text = productItem.productPriceAmount;
            UIImage *cellImage = [productItem getthumbnailImage:kSmallThumbnailImage];
            //UIImage *cellImage = [UIImage imageNamed:@"first@2x.png"];
            assert(cellImage != nil);
            cell.productImage.image = cellImage;
            cell.selectedReviews.hidden = NO;
            cell.userInteractionEnabled = YES;
            
            // Assign the Reviews UIButton a tag corresponding to the tableView row so we can reference it again
            cell.selectedReviews.tag = indexPath.row;
            
            // Observe our cell's thumbnail
            if (self.observedItems == nil) {
                self.observedItems = [NSMutableArray array];
            }
            [productItem addObserver:self forKeyPath:@"thumbnailStatus" options:NSKeyValueObservingOptionNew context:ThumbnailStatusContext];
            productItem.hasObserver = YES;
            [self.observedItems addObject:productItem];
        }        
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
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
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

// Generate Section Headers
-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    // Check if we have any Searches
    if (self.noSearchesFound) {
        return @"No Search:";
    } else {
        assert(self.sortedSections != nil);
        MzSearchItem *item = [self.allSearches objectForKey:[self.sortedSections objectAtIndex:section]];
        assert(item != nil);
        assert([item.searchTitle length] > 0);
        NSString *title = [NSString stringWithFormat:@"Search %d: %@", section+1, item.searchTitle];
        return title;
    }
}

#pragma mark - Search Item Delegate Methods

// Delegate Methods that deal with deletions and insertions of MzSearchItems by the User
/*
 NOTE: When our view is loaded, this viewController has the state to process deletions and 
 insertions of MzSearchItems, however the first time app starts (i.e becomes Active), the view
 is not loaded and we cannot process these delegate since alot of the state is setup in the 
 viewDidLoad method
 
 NOTE: we reload the tableView after KVO observing the additions to the allProductItems dictionary
 // via the "productItems" property we observe on each ProductCollection
 */
-(void)controller:(MzSearchListViewController *)searchController addedSearchItem:(MzSearchItem *)searchItem
{
    if (self.isViewLoaded == YES) {
    // Update the Model
        assert(searchItem != nil);
        NSURL *insertURL = [self createURLFromSearchItem:searchItem];
        assert(insertURL != nil);
        NSString *insertKey = [insertURL absoluteString];
        assert(insertKey != nil);
        NSArray *insertItems = [NSArray arrayWithObject:insertKey];
        assert(insertItems != nil);
        [self.allSearches setObject:searchItem forKey:insertKey];
        [self updateProductCollectionCaches:insertItems];
        [self.tableView reloadRowsAtIndexPaths:[self.tableView indexPathsForVisibleRows] withRowAnimation:UITableViewRowAnimationNone];
    } else {
        // Attempt to load our View which will update all the relevant Collections
        // and also because the User is likely to be coming to this screen next!
        [self view];
    }
}

// Note that this delegate method references the MzSearchReviewsViewController unlike the method above
-(void) controller:(MzSearchReviewsViewController *)searchController addSearchItem:(MzSearchItem *)searchItem
{
    if (self.isViewLoaded == YES) {
        
        assert(searchItem != nil);
        // Update Search Category
        self.searchCategory = searchItem.searchTitle;
        assert(self.searchCategory != nil);
        
        // Update the Model
        NSURL *insertURL = [self createURLFromSearchItem:searchItem];
        assert(insertURL != nil);
        NSString *insertKey = [insertURL absoluteString];
        assert(insertKey != nil);
        NSArray *insertItems = [NSArray arrayWithObject:insertKey];
        assert(insertItems != nil);
        [self.allSearches setObject:searchItem forKey:insertKey];
        [self updateProductCollectionCaches:insertItems];
        [self.tableView reloadRowsAtIndexPaths:[self.tableView indexPathsForVisibleRows] withRowAnimation:UITableViewRowAnimationNone];
    } else {
        // Attempt to load our View which will update all the relevant Collections
        // and also because the User is likely to be coming to this screen next!
        assert(searchItem != nil);
        // Update Search Category
        self.searchCategory = searchItem.searchTitle;
        assert(self.searchCategory != nil);
        [self view];
        
    }
}

// Note that this delegate method is deprecated!!! Instead, when the App moves to Background, all serialized
// MzSearchItems are deleted.
-(void)controller:(MzSearchListViewController *)searchController deletedSearchItem:(MzSearchItem *)searchItem
{
    if (self.isViewLoaded == YES) {
        // Delete the MzSearchItem for our Model, the corresponding ProductCollection if any will
        // deleted next time the App moves into background
        NSURL *deleteURL = [self createURLFromSearchItem:searchItem];
        assert(deleteURL != nil);
        NSString *deleteKey = [deleteURL absoluteString];
        assert(deleteKey != nil);
        if ([self.allSearches count] > 0) {
            [self.allSearches removeObjectForKey:deleteKey];
            [[QLog log] logWithFormat:@"Deleted Search Item as per User Request with Title: %@", searchItem.searchTitle];
        } else {
            [[QLog log] logWithFormat:@"User Requested delete unknown Search Item with Title: %@", searchItem.searchTitle];    
        }
        // Mark the ProductCollection for deletion
        if ([self.productSearchMap count] > 0) {
            NSURL *collectionName = [self.productSearchMap objectForKey:deleteKey];
            if (collectionName != nil) {
                [MzProductCollection markForRemoveCollectionCacheAtPath:collectionName];
                
                // Remove any KVO observers
                NSArray *removeItems = [self.allProductItems objectForKey:[collectionName path]];
                if (removeItems != nil && [removeItems count] > 0) {
                    [removeItems enumerateObjectsUsingBlock:^(MzProductItem *productItem, NSUInteger idx, BOOL *stop) {
                        if (productItem.hasObserver) {
                            [productItem removeObserver:self forKeyPath:@"thumbnailStatus" context:ThumbnailStatusContext];
                        }                        
                    }];
                }                
                [self.allProductItems removeObjectForKey:[collectionName path]];
                [[QLog log] logWithFormat:@"Deleted Search Item from Product Collection per User Request with Title: %@", searchItem.searchTitle];
            }
        }
        
        // Delete the MzSearchItem (section) from the tableView
        if (!noSearchesFound && [self.sortedSections count] > 0) {
            NSUInteger deleteIndex = [self.sortedSections indexOfObjectPassingTest:^(NSString *sURL, NSUInteger idx, BOOL *stop) {
                if ([sURL isEqualToString:deleteKey]) {
                    *stop = YES;
                    return YES;
                } else { return NO; }
            }];
            if (deleteIndex != NSNotFound) {
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:deleteIndex] withRowAnimation:UITableViewRowAnimationNone];
            }        
        }
        [self.tableView reloadRowsAtIndexPaths:[self.tableView indexPathsForVisibleRows] withRowAnimation:UITableViewRowAnimationNone];
    } else {
        // Attempt to load our View which will update all the relevant Collections
        // and also because the User is likely to be coming to this screen next!
        [self view];
    }
}

// Helper to compare 2 SearchItems and return YES if they are the same
-(BOOL)compareSearchItems:(MzSearchItem *)first secondItem:(MzSearchItem *)second
{
    assert(first != nil);
    assert(second != nil);
    if( [first.searchTitle isEqualToString:second.searchTitle] && [first.searchTimestamp compare:second.searchTimestamp] == NSOrderedSame) {
        return  YES;
    } else {
        return NO;
    }    
}

#pragma mark - UIStoryboardSegue Interaction methods

// Pass the MzProductItem to be displayed in a UIWebView
-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:kResultsDetailId]) {
        MzResultsDetailViewController *resultDetailController = [segue destinationViewController];
       
        // Get the selected Cell
        NSIndexPath *selectedPath = [self.tableView indexPathForSelectedRow];
        if (selectedPath != nil) {
            MzResultListCell *selectedCell = (MzResultListCell *)[self.tableView cellForRowAtIndexPath:selectedPath];
            assert(selectedCell != nil);
            resultDetailController.urlString = selectedCell.productItem.productDetailPath;
            assert(resultDetailController.urlString != nil);
        }
    }
    
    // Pass the MzProductItem whose MzReviewItems will be displayed
    if ([[segue identifier] isEqualToString:kReviewsListSegueId]) {
        assert([sender isKindOfClass:[UIButton class]]);
        UIButton *reviewButton = (UIButton *)sender;
        MzResultListCell *reviewCell = (MzResultListCell *)[self.tableView cellForRowAtIndexPath:
                                                            [NSIndexPath indexPathForRow:reviewButton.tag inSection:0]];
        assert(reviewCell != nil);
        assert(reviewCell.productItem != nil);
        
        // Pass the MzProductItem to the MzReviewsListViewController
        MzReviewsListViewController *reviewsController = [segue destinationViewController];
        reviewsController.productItem = reviewCell.productItem;
        assert(reviewsController.productItem != nil);
        reviewsController.reviewCategory = self.searchCategory;
        assert(reviewsController.reviewCategory != nil);
    }
    

}

@end
