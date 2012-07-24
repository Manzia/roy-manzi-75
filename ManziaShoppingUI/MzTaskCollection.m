//
//  MzTaskCollection.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 7/23/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskCollection.h"
#import "MzTaskParserOperation.h"
#import "MzTaskCollectionContext.h"

@interface MzTaskCollection() 

// private properties
@property (nonatomic, copy, readwrite) NSString *tasksURLString;
@property (nonatomic, retain, readwrite)NSEntityDescription *tasksEntity;
@property (nonatomic, retain, readwrite)MzTaskCollectionContext* taskCollectionContext;
@property (nonatomic, copy, readonly) NSString *tasksCachePath;
@property (nonatomic, assign, readwrite) TaskCollectionSyncState stateOfSync;
@property (nonatomic, retain, readwrite) NSTimer *timeToSave;
@property (nonatomic, retain, readwrite) NSTimer *timeToRefresh;
@property (nonatomic, copy, readwrite) NSDate *dateLastSynced;
@property (nonatomic, copy, readwrite) NSError *errorFromLastSync;
@property (nonatomic, retain, readwrite) RetryingHTTPOperation *getTasksOperation;
@property (nonatomic, retain, readwrite) MzTaskParserOperation *parserOperation;

// This property will hold the value of the relativePath that was appended to
// the collectionURLString to create the NSURLRequest for the HTTP GET
//@property (nonatomic, copy, readwrite) NSString * variableRelativePath;

// Keys are relativePaths and values are an array of old parserResults
// and time parseOperation completed
//@property (retain, readonly) NSMutableDictionary *pathsOldResults;

// forward declarations

- (void)startParserOperationWithData:(NSData *)data;
- (void)commitParserResults:(NSArray *)latestResults;

@end


@implementation MzTaskCollection

// Synthesize properties
@synthesize tasksURLString;
@synthesize tasksEntity;
@synthesize taskCollectionContext;
@synthesize tasksCachePath;
@synthesize stateOfSync;
@synthesize timeToSave;
@synthesize dateFormatter;
@synthesize dateLastSynced;
@synthesize errorFromLastSync;
@synthesize getTasksOperation;
@synthesize parserOperation;
@synthesize timeToRefresh;
@synthesize synchronizing;
//@synthesize pathsOldResults;
//@synthesize variableRelativePath;

// Other Getters
-(id)managedObjectContext
{
    return self.taskCollectionContext;
}

//Override getter and maintain KVC compliance
- (NSString *)tasksCachePath
{
    assert(self.taskCollectionContext != nil);
    return self.taskCollectionContext.tasksCachePath;
}




@end
