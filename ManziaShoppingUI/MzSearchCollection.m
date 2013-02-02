//
//  MzSearchCollection.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzSearchCollection.h"
#import "MzSearchItem.h"
#import "Logging.h"

@interface MzSearchCollection()

@property (nonatomic, copy, readwrite) NSString *searchDirectory;

@end

@implementation MzSearchCollection

@synthesize searchDirectory;

// Format for the Search Directory
static NSString * kSearchNameTemplate = @"Search%.9f.%@";

// Format for the MzSearchItem files
static NSString *kSearchFileTemplate = @"search-file%.9f";

// Extension for the Search directory
static NSString * kSearchExtension    = @"search";

// File Prefix
static NSString *kSearchFilePrefix = @"search-file";

#pragma mark Search Directory Setup

// assigns an existing Search Directory or creates a new one if none
// is found
-(BOOL)addSearchCollection {
    
    NSArray *collectionCacheNames;
    NSFileManager *fileManager;
    NSString *collectionName;
    BOOL success;
    
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    
    // Check if we already have a Search Directory
    //collectionCacheNames = [fileManager contentsOfDirectoryAtPath:[self pathToCachesDirectory] error:NULL];
    collectionCacheNames = [fileManager contentsOfDirectoryAtURL:[self pathToCachesDirectory] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
    assert(collectionCacheNames != nil);
    
    // Enumerate through the Caches
    success = NO;
    for (NSURL *cacheName in collectionCacheNames) {
        if ([[cacheName lastPathComponent] hasSuffix:kSearchExtension]) {
            
            self.searchDirectory = [cacheName lastPathComponent];
            success = YES;
            break;      // return
        }
    }
    
    // If we didn't find a Search Directory, we create one
    if (![self.searchDirectory hasSuffix:kSearchExtension]) {
        collectionName = [NSString stringWithFormat:kSearchNameTemplate, [NSDate timeIntervalSinceReferenceDate], kSearchExtension];
        assert(collectionName != nil);
        self.searchDirectory = collectionName;
        assert(self.searchDirectory != nil);
        
        // create the directory
        NSError *dirError = NULL;
        NSURL *dirPath = [[self pathToCachesDirectory] URLByAppendingPathComponent:self.searchDirectory isDirectory:YES];
        assert(dirPath != nil);
        [fileManager createDirectoryAtURL:dirPath withIntermediateDirectories:YES attributes:nil error:&dirError];
        
        if (!dirError) {
            success = YES;
        }        
    }
    
    // Log success
    if (success) {
        [[QLog log] logWithFormat:@"Assigned or Created a Search Directory: %@", self.searchDirectory];
    } else {
        [[QLog log] logWithFormat:@"Failed to Assign/Create a Search Directory: %@", self.searchDirectory];
    }
    
    return success;    
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

#pragma mark Search Directory Management

// Add a MzSearchItem to the Search Directory
-(BOOL)addSearchItem:(MzSearchItem *)searchItem
{
    assert(searchItem != nil);
    
    // check that we can execute operation
    if (self.searchDirectory == nil) {
        [self addSearchCollection];
    }
    
    NSFileManager *fileManager;
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    NSString *filename;
    BOOL success;
        
    filename = [NSString stringWithFormat:kSearchFileTemplate, [NSDate timeIntervalSinceReferenceDate]];
    assert(filename != nil);
    success = NO;
    
    // write to Search Directory
    NSURL *dirPath = [[self pathToCachesDirectory] URLByAppendingPathComponent:self.searchDirectory isDirectory:YES];
    assert(dirPath != nil);
    success = [searchItem writeSearchItemToFile:[dirPath URLByAppendingPathComponent:filename]];
    
    // Log success
    if (success) {
        [[QLog log] logWithFormat:@"Added Search Item to directory: %@", self.searchDirectory];
    } else {
        [[QLog log] logWithFormat:@"Failed to add Search Item to directory: %@", self.searchDirectory];
    }
    
    return  success;
}

// Remove a MzSearchItem from the Search Directory
-(BOOL)removeSearchItemWithTitle:(NSString *)searchTitle andTimestamp:(NSDate *)timestamp
{
    assert(searchTitle != nil);
    BOOL success;
    
    // check that we can execute operation
    if (self.searchDirectory == nil) {
        [self addSearchCollection];
    }
    
    NSFileManager *fileManager;
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    NSArray *searchFiles;
    NSDictionary *searchItem;
    
    NSURL *dirPath = [[self pathToCachesDirectory] URLByAppendingPathComponent:self.searchDirectory isDirectory:YES];
    assert(dirPath != nil);
    searchFiles = [fileManager contentsOfDirectoryAtURL:dirPath includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
    if (!searchFiles) {
        return NO;         // return if we have an empty Search Directory
    }

    assert(searchFiles != nil);
    success = NO;
    
    // Enumerate and delete the search file if found
    //NSString *completeFileName;
    for (NSURL *fileName in searchFiles) {
        if ([[fileName lastPathComponent] hasPrefix:kSearchFilePrefix] && fileName.isFileURL) {
            //completeFileName = [dirPath URLByAppendingPathComponent:fi isDirectory:<#(BOOL)#>:fileName];
            //assert(completeFileName != nil);
            searchItem = [NSDictionary dictionaryWithContentsOfURL:fileName]; 
            assert(searchItem != nil);
            
            // check the searchTitle and the Timestamp            
            if ([searchTitle hasSuffix:[searchItem objectForKey:kSearchItemTitle]] && [timestamp isEqualToDate:[searchItem objectForKey:kSearchItemTimestamp]]) {
                
                success = [fileManager removeItemAtURL:fileName error:nil];
                break;
            }            
        }
    }
    
    // Log success
    if (success) {
        [[QLog log] logWithFormat:@"Removed Search Item from directory: %@", self.searchDirectory];
    } else {
        [[QLog log] logWithFormat:@"Failed to remove Search Item from directory: %@", self.searchDirectory];
    }

    
    return  success;    
}

// Remove a MzSearchItem from the Search Directory
-(BOOL)removeSearchItem:(MzSearchItem *)searchItem
{
    assert(searchItem != nil);
    NSString *searchTitle;
    NSDate *itemTimestamp;
    BOOL success;
    
    searchTitle = searchItem.searchTitle;
    assert(searchTitle != nil);
    itemTimestamp = searchItem.searchTimestamp;
    assert(itemTimestamp != nil);
    success = [self removeSearchItemWithTitle:searchTitle andTimestamp:itemTimestamp];
    
    return success;
}

// Remove all completed MzSearchItems from the Search Directory
-(BOOL)removeSearchItemsWithStatus:(SearchItemState)searchStatus
{
    BOOL success;
    NSUInteger count = 0;
    NSError *error = NULL;
    
    // check that we can execute operation
    if (self.searchDirectory == nil) {
        [self addSearchCollection];
    }
    
    NSFileManager *fileManager;
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    NSArray *searchFiles;
    NSDictionary *searchItem;
    
    NSURL *dirPath = [[self pathToCachesDirectory] URLByAppendingPathComponent:self.searchDirectory isDirectory:YES];
    assert(dirPath != nil);
    searchFiles = [fileManager contentsOfDirectoryAtURL:dirPath includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
    if (!searchFiles) {
        return NO;         // return if we have an empty Search Directory
    }

    assert(searchFiles != nil);
    success = NO;
    //NSString *completeFileName;
    for (NSURL *fileName in searchFiles) {
        if ([[fileName lastPathComponent] hasPrefix:kSearchFilePrefix] && fileName.isFileURL) {
            //completeFileName = [dirPath stringByAppendingPathComponent:fileName];
            //assert(completeFileName != nil);
            searchItem = [NSDictionary dictionaryWithContentsOfURL:fileName]; 
            assert(searchItem != nil);
            
            if (searchStatus == [[searchItem objectForKey:kSearchItemState] intValue]) {
                success = [fileManager removeItemAtURL:fileName error:&error];
                
                if (error) count++;     // Just keep a count of any errors
            }

        }
                            
    }
    // Log results
    [[QLog log] logWithFormat:@"Removed all Search Items from directory: %@ with %d errors", self.searchDirectory, count];
    
    // Note that returning success = NO just means we had 1 or more errors during removal, but
    // we may have indeed removed all the search files.
    return  success;
}

// Get all the "deserialized" MzSearchItems from the Search Directory
-(NSArray *)allSearchItems
{
    // check that we can execute operation
    if (self.searchDirectory == nil) {
        [self addSearchCollection];
    }
    
    NSFileManager *fileManager;
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    NSArray *searchFiles;
    NSDictionary *searchItem;
    NSMutableArray *items;
    MzSearchItem *serializedItem;
    NSError *error = NULL;
    
    // get all the files
    NSURL *dirPath = [[self pathToCachesDirectory] URLByAppendingPathComponent:self.searchDirectory isDirectory:YES];
    assert(dirPath != nil);
    searchFiles = [fileManager contentsOfDirectoryAtURL:dirPath includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
    if (!searchFiles) {
        return nil;         // return if we have an empty Search Directory
    }
    
    // Log errors
    if (error) {
        [[QLog log] logWithFormat:@"Error: %@ retrieving Search Items from directory: %@", error.localizedDescription, self.searchDirectory];
    }
    
    assert(searchFiles != nil);
    items = [NSMutableArray array];
    assert(items != nil);
    
    // initialize the MzSearchItem objects
    //NSString *completeFileName;
    for (NSURL *fileName in searchFiles) {
        if ([[fileName lastPathComponent] hasPrefix:kSearchFilePrefix] && fileName.isFileURL) {
            //completeFileName = [dirPath stringByAppendingPathComponent:fileName];
            //assert(completeFileName != nil);
            searchItem = [NSDictionary dictionaryWithContentsOfURL:fileName]; 
            assert(searchItem != nil);
            serializedItem = [[MzSearchItem alloc] init];
            assert(serializedItem != nil);
            serializedItem.daysToSearch = [searchItem objectForKey:kSearchItemDays];
            assert(serializedItem.daysToSearch != nil);
            serializedItem.priceToSearch = [searchItem objectForKey:kSearchItemPrice];
            assert(serializedItem.priceToSearch != nil);
            serializedItem.searchTitle = [searchItem objectForKey:kSearchItemTitle];
            assert(serializedItem.searchTitle != nil);
            serializedItem.searchOptions = [searchItem objectForKey:kSearchItemOptions];
            assert(serializedItem.searchOptions != nil);
            serializedItem.searchStatus = [[searchItem objectForKey:kSearchItemState] intValue];
            serializedItem.searchTimestamp = [searchItem objectForKey:kSearchItemTimestamp];
            assert(serializedItem.searchTimestamp != nil);
            
            [items addObject:serializedItem];
        }
        
    }
    
    // Log
    [[QLog log] logWithFormat:@"Retrieved %d: Search Items from directory: %@", [items count], self.searchDirectory];
    
    return items;
}

// Return the most recent, i.e newest MzSearchItem in the MzSearchCollection's Search Directory wher recency is based
// on the MzSearchItem's timestamp
-(MzSearchItem *)recentSearchItemInDirectory
{
    // Get all the MzSearchItems
    NSArray *searchItems;
    NSArray *sortedItems;
    searchItems = [self allSearchItems];
    assert(searchItems != nil);
    
    // We sort using a comparator
    sortedItems = [searchItems sortedArrayUsingComparator:^(MzSearchItem *searchOne, MzSearchItem *searchTwo) {
        return [searchOne.searchTimestamp compare:searchTwo.searchTimestamp];
    }];
    assert(sortedItems != nil);
    
    // return nil if we have an empty array else return the last object which will be the most recent
    if ([sortedItems count] == 0) return nil;
    NSUInteger mostRecentIdx = [sortedItems count] - 1;
    return [sortedItems objectAtIndex:mostRecentIdx];
}

// Delete the Search Directory and thus all the "serialized" MzSearchItems
-(void) deleteSearchDirectory
{
    assert(self.searchDirectory != nil);
    NSFileManager *fileManager;
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    
    // create the directory
    NSError *dirError = NULL;
    NSURL *dirPath = [[self pathToCachesDirectory] URLByAppendingPathComponent:self.searchDirectory isDirectory:YES];
    assert(dirPath != nil);
    [fileManager removeItemAtURL:dirPath error:&dirError];
    if (dirError) {
        // Log
        [[QLog log] logWithFormat:@"Error while deleting Search Directory at Path: %@", [dirPath path]];
    }
}

@end
