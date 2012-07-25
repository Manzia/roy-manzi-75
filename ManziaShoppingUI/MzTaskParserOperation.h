//
//  MzTaskParserOperation.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 7/24/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MzTaskParserOperation : NSOperation {
    NSData *xmlData;
    NSError *parseError;
#if ! defined(NDEBUG)
    NSTimeInterval debugDelay;
    NSTimeInterval debugDelaySoFar;
#endif
    NSXMLParser *collectionParser;
    NSMutableArray *mutableResults;
    NSMutableDictionary *tasksProperties;    
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

extern NSString *kTaskParserResultCategoryId;      // NSString
extern NSString *kTaskParserResultCategoryName;
extern NSString *kTaskParserResultCategoryImageURL;
extern NSString *kTaskParserResultTaskTypeId;
extern NSString *kTaskParserResultTaskTypeImageURL;
extern NSString *kTaskParserResultTaskTypeName;
extern NSString *kTaskParserResultTaskAttributeId;
extern NSString *kTaskParserResultTaskAttributeName;
extern NSString *kTaskParserResultAttributeOptionId;
extern NSString *kTaskParserResultAttributeOptionName;

@end
