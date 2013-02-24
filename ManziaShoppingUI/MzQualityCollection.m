//
//  MzQualityCollection.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 2/23/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzQualityCollection.h"
#import "Logging.h"
#import "RecursiveDeleteOperation.h"

#define kMAX_COLLECTION_DURATION 604800        // 1 week or 7 days in Seconds

@interface MzQualityCollection()

@property (nonatomic, copy, readwrite) NSString *qualitiesDirectory;
@property (nonatomic, strong) NSMutableArray *qualitiesArray;

@end

@implementation MzQualityCollection

@synthesize qualitiesDirectory;
@synthesize qualitiesArray;

// Format for the Qualities Directory
static NSString * kQualityNameTemplate = @"Quality%.9f.%@";

// Format for the MzSearchItem files
static NSString *kQualityFileTemplate = @"quality-file%.9f";

// Extension for the Search directory
static NSString * kQualityExtension    = @"quality";

// File Prefix
static NSString *kQualityFilePrefix = @"quality-file";

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

// assigns an existing Search Directory or creates a new one if none
// is found
-(BOOL)addQualityCollection {
    
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
        if ([[cacheName lastPathComponent] hasSuffix:kQualityExtension]) {
            
            self.qualitiesDirectory = [cacheName lastPathComponent];
            success = YES;
            break;      // return
        }
    }
    
    // If we didn't find a Search Directory, we create one
    if (![self.qualitiesDirectory hasSuffix:kQualityExtension]) {
        collectionName = [NSString stringWithFormat:kQualityNameTemplate, [NSDate timeIntervalSinceReferenceDate], kQualityExtension];
        assert(collectionName != nil);
        self.qualitiesDirectory = collectionName;
        assert(self.qualitiesDirectory != nil);
        
        // create the directory
        NSError *dirError = NULL;
        NSURL *dirPath = [[self pathToCachesDirectory] URLByAppendingPathComponent:self.qualitiesDirectory isDirectory:YES];
        assert(dirPath != nil);
        [fileManager createDirectoryAtURL:dirPath withIntermediateDirectories:YES attributes:nil error:&dirError];
        
        if (!dirError) {
            success = YES;
        }
    }
    
    // Log success
    if (success) {
        [[QLog log] logWithFormat:@"Assigned or Created a Qualities Directory: %@", self.qualitiesDirectory];
    } else {
        [[QLog log] logWithFormat:@"Failed to Assign/Create a Qualities Directory: %@", self.qualitiesDirectory];
    }
    
    // Init our qualitiesDictionary
    self.qualitiesArray = [NSMutableArray array];
    return success;
}

// Add a Product Quality to the Quality Collection
-(void)addProductQuality:(NSString *)productQuality
{
    assert(productQuality != nil);
    assert(self.qualitiesArray != nil);
    
    // check that we can execute operation
    if (self.qualitiesDirectory == nil) {
        [self addQualityCollection];
    }
    // Add to Array
    [self.qualitiesArray addObject:productQuality];
}

// Get all the "deserialized" Qualities from the Qualities Directory
-(NSArray *)allProductQualities
{
    // check that we can execute operation
    if (self.qualitiesDirectory == nil) {
        [self addQualityCollection];
    }
    
    NSFileManager *fileManager;
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    NSArray *searchFiles;
    NSArray *items;
    NSError *error = NULL;
    
    // get all the files
    NSURL *dirPath = [[self pathToCachesDirectory] URLByAppendingPathComponent:self.qualitiesDirectory isDirectory:YES];
    assert(dirPath != nil);
    searchFiles = [fileManager contentsOfDirectoryAtURL:dirPath includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
    if (!searchFiles) {
        return nil;         // return if we have an empty Search Directory
    }
    
    // Log errors
    if (error) {
        [[QLog log] logWithFormat:@"Error: %@ retrieving Product Qualities from directory: %@", error.localizedDescription, self.qualitiesDirectory];
    }
    
    assert(searchFiles != nil);
    
    // Iterate
    for (NSURL *fileName in searchFiles) {
        if ([[fileName lastPathComponent] hasPrefix:kQualityFilePrefix] && fileName.isFileURL) {
                       
            items = [NSArray arrayWithContentsOfURL:fileName];
            assert(items != nil);
            break;
        }        
    }    
    // Log
    [[QLog log] logWithFormat:@"Retrieved %d: Quality Items from directory: %@", [items count], self.qualitiesDirectory];
    
    return items;
}

// Saves all Product Qualities to an existing Qualities Directory
-(BOOL)saveQualityCollection
{
    // check that we can execute operation
    if (self.qualitiesDirectory == nil) {
        [self addQualityCollection];
    }
    assert(self.qualitiesArray != nil);
    BOOL success;
    
    if ([self.qualitiesArray count] > 0) {
        
        NSFileManager *fileManager;
        fileManager = [NSFileManager defaultManager];
        assert(fileManager != nil);
        NSString *filename;
                
        filename = [NSString stringWithFormat:kQualityFileTemplate, [NSDate timeIntervalSinceReferenceDate]];
        assert(filename != nil);
        success = NO;
        
        // write to Search Directory
        NSURL *dirPath = [[self pathToCachesDirectory] URLByAppendingPathComponent:self.qualitiesDirectory isDirectory:YES];
        assert(dirPath != nil);
        success = [self.qualitiesArray writeToURL:[dirPath URLByAppendingPathComponent:filename] atomically:YES];
        
        // Log success
        if (success) {
            [[QLog log] logWithFormat:@"Added Qualities File to directory: %@", self.qualitiesDirectory];
        } else {
            [[QLog log] logWithFormat:@"Failed to add Qualities File to directory: %@", self.qualitiesDirectory];
        }

    }
        
    return  success;
}

// Removes old Files ( > 1 week) from the Qualities Directory
-(void)cleanQualitiesDirectory
{
    
    // check that we can execute operation
    if (self.qualitiesDirectory == nil) {
        [self addQualityCollection];
    }
    
    NSFileManager *fileManager;
    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    NSArray *searchFiles;
    NSMutableArray *filesToDelete;
    NSError *error = NULL;
    
    // get all the files
    NSURL *dirPath = [[self pathToCachesDirectory] URLByAppendingPathComponent:self.qualitiesDirectory isDirectory:YES];
    assert(dirPath != nil);
    searchFiles = [fileManager contentsOfDirectoryAtURL:dirPath includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants error:nil];
    if (!searchFiles) {
        return;         // return if we have an empty Qualities Directory
    }
    
    // Log errors
    if (error) {
        [[QLog log] logWithFormat:@"Error: %@ cleaning Qualities Directory: %@", error.localizedDescription, self.qualitiesDirectory];
    }
    
    assert(searchFiles != nil);
    
    // Iterate
    NSDate *modifiedDate;
    filesToDelete = [NSMutableArray array];
    for (NSURL *fileName in searchFiles) {
        if ([[fileName lastPathComponent] hasPrefix:kQualityFilePrefix] && fileName.isFileURL) {
            
            /*
             1- Get the modified dates of all the files associated with the Quality Collection
             caches
             */
            modifiedDate = [[fileManager attributesOfItemAtPath:[fileName path] error:NULL] objectForKey:NSFileModificationDate];
            if (modifiedDate == nil) {
                [[QLog log] logWithFormat:@"Invalid Qualities File: '%@'", [fileName path]];
                [filesToDelete addObject:fileName];
            } else {
                assert([modifiedDate isKindOfClass:[NSDate class]]);
                if ([modifiedDate timeIntervalSinceNow] <= -kMAX_COLLECTION_DURATION) {
                    [[QLog log] logWithFormat:@"File in Qualities Directory: %@ exceeds Max Duration: %d, will be deleted!", [fileName path], kMAX_COLLECTION_DURATION];
                    [filesToDelete addObject:fileName];
                }
            }
        }
    }
    
    /*
     As a final step:
     1- start an NSOperation to delete the marked Files
    */
    
    if ( [filesToDelete count] > 0 ) {
        static NSOperationQueue *collectionDeleteQueue;
        RecursiveDeleteOperation *operation;
        
        collectionDeleteQueue = [[NSOperationQueue alloc] init];
        assert(collectionDeleteQueue != nil);
        
        operation = [[RecursiveDeleteOperation alloc] initWithPaths:filesToDelete];
        assert(operation!= nil);
        
        if ( [operation respondsToSelector:@selector(setThreadPriority:)] ) {
            [operation setThreadPriority:0.1];
        }
        
        [collectionDeleteQueue addOperation:operation];
    }
}

@end
