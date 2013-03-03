//
//  MzRanksParserOperation.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 2/28/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MzRanksParserOperation : NSOperation

{
#if ! defined(NDEBUG)
NSTimeInterval debugDelay;
NSTimeInterval debugDelaySoFar;
#endif
BOOL storeCharacters;
}

// Initialize with XML data
- (id)initWithXMLData:(NSData *)data;


// properties specified at init time
@property (copy, readonly) NSData *xmldata;

// properties that can be changed before starting the operation
#if ! defined(NDEBUG)
@property (assign, readwrite) NSTimeInterval debugDelay;     // default is 0.0
#endif

// properties that are valid after the operation is finished

@property (copy, readonly) NSError *parseError;
@property (copy, readonly ) NSArray *parseResults;       // of NSDictionary, keys below

// Keys for the parseResults dictionaries.

extern NSString * kParserRankQuality;      // NSString
extern NSString * kParserRankRating; // NSString

@end
