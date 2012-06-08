//
//  MzCollectionParserOperation.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 6/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.


#import <Foundation/Foundation.h>

@interface MzCollectionParserOperation : NSOperation 
{
    NSData *xmlData;
    NSError *parseError;
#if ! defined(NDEBUG)
    NSTimeInterval debugDelay;
    NSTimeInterval debugDelaySoFar;
#endif
    NSXMLParser *collectionParser;
    NSMutableArray *mutableResults;
    NSMutableDictionary *productItemProperties;
    BOOL storeCharacters;
    NSMutableString *currentStringValue;
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

extern NSString * kCollectionParserResultTitle;      // NSString
extern NSString * kCollectionParserResultDetailsPath; // NSString
extern NSString * kCollectionParserResultImagePath; // NSString
extern NSString * kCollectionParserResultThumbNailPath; //NSString
extern NSString * kCollectionParserResultProductID;     //NSString
extern NSString * kCollectionParserResultDescription;   //NSString
extern NSString * kCollectionParserResultLanguage;      //NSString
extern NSString * kCollectionParserResultCountry;       //NSString
extern NSString * kCollectionParserResultClassID;       //NSString
extern NSString * kCollectionParserResultSubClassID;    //NSString
extern NSString * kCollectionParserResultPriceUnit;     //NSString
extern NSString * kCollectionParserResultPriceAmount;   //NSString
extern NSString * kCollectionParserResultBrand;         //NSString
extern NSString * kCollectionParserResultCondition;     //NSString
extern NSString * kCollectionParserResultAvailability;  //NSString

@end
