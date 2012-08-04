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
    collectionCacheNames = [fileManager contentsOfDirectoryAtPath:[self pathToCachesDirectory] error:NULL];
    assert(collectionCacheNames != nil);
    
    // Enumerate through the Caches
    success = NO;
    for (NSString *cacheName in collectionCacheNames) {
        if ([cacheName hasSuffix:kSearchExtension]) {
            
            self.searchDirectory = cacheName;
            success = YES;
            break;      // return
        }
    }
    
    // If we didn't find a Search Directory, we create one
    if (![self.searchDirectory hasSuffix:kSearchExtension]) {
        collectionName = [NSString stringWithFormat:kSearchNameTemplate, [NSDate timeIntervalSinceReferenceDate], kSearchExtension];
        assert(collectionName != nil);
        success = YES;
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
    success = [searchItem writeSearchItemToFile:[self.searchDirectory stringByAppendingPathComponent:filename]];
    
    // Log success
    if (success) {
        [[QLog log] logWithFormat:@"Added Search Item to directory: %@", self.searchDirectory];
    } else {
        [[QLog log] logWithFormat:@"Failed to add Search Item to directory: %@", self.searchDirectory];
    }
    
    return  success;
}

// Remove a MzSearchItem from the Search Directory
-(BOOL)removeSearchItemWithTitle:(NSString *)searchTitle
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
    
    searchFiles = [fileManager contentsOfDirectoryAtPath:self.searchDirectory error:NULL];
    if (!searchFiles) {
        return NO;         // return if we have an empty Search Directory
    }

    assert(searchFiles != nil);
    success = NO;
    
    // Enumerate and delete the search file if found
    for (NSString *fileName in searchFiles) {
        if ([fileName hasPrefix:@"search"]) {
            searchItem = [NSDictionary dictionaryWithContentsOfFile:fileName]; 
            assert(searchItem != nil);
            
            if ([searchTitle isEqualToString:[searchItem objectForKey:kSearchItemTitle]]) {
                success = [fileManager removeItemAtPath:fileName error:NULL];
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
    BOOL success;
    
    searchTitle = searchItem.searchTitle;
    assert(searchTitle != nil);
    success = [self removeSearchItemWithTitle:searchTitle];
    
    return success;
}

// Remove all completed MzSearchItems from the Search Directory
-(BOOL)removeCompletedSearchItems
{
    BOOL success;
    NSUInteger count;
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
    
    searchFiles = [fileManager contentsOfDirectoryAtPath:self.searchDirectory error:NULL];
    if (!searchFiles) {
        return NO;         // return if we have an empty Search Directory
    }

    assert(searchFiles != nil);
    success = NO;
    for (NSString *fileName in searchFiles) {
        if ([fileName hasSuffix:kSearchExtension]) {
            
            searchItem = [NSDictionary dictionaryWithContentsOfFile:fileName]; 
            assert(searchItem != nil);
            
            if (SearchItemStateCompleted == [[searchItem objectForKey:kSearchItemState] intValue]) {
                success = [fileManager removeItemAtPath:fileName error:&error];
                
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
    
    // get all the files
    searchFiles = [fileManager contentsOfDirectoryAtPath:self.searchDirectory error:NULL];
    if (!searchFiles) {
        return nil;         // return if we have an empty Search Directory
    }
    
    assert(searchFiles != nil);
    items = [NSMutableArray array];
    assert(items != nil);
    
    // initialize the MzSearchItem objects
    for (NSString *fileName in searchFiles) {
        if ([fileName hasSuffix:kSearchExtension]) {
            searchItem = [NSDictionary dictionaryWithContentsOfFile:fileName]; 
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
            
            [items addObject:serializedItem];
        }
        
    }
    
    // Log
    [[QLog log] logWithFormat:@"Retrieved %d: Search Items from directory: %@", [items count], self.searchDirectory];
    
    return items;
}

@end
