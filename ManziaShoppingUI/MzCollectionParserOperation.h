//
//  MzCollectionParserOperation.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 6/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.

/*
 Below is sample XML product Item entry:
 <entry>
 <title type="text">Tadashi Shoji One Shoulder Lace Sheath Dress</title>
 <link rel="alternate" type="text/html" href="http://shop.nordstrom.com/s/tadashi-shoji-one-shoulder-lace-sheath-dress/3205422?"/>
 <mz:image_link>http://aws.amazon.com/image/120000</mz:image_link>
 <mz:thumbnail_link>http://aws.amazon.com/thumbnail/120000<thumbnail_link>
 <mz:id>100303001</mz:id>
 <content type="xhtml">
 <p> Tadashi Shoji One Shoulder Lace Sheath Dress. </p>
 </content>
 <mz:content_language>en</mz:content_language>
 <mz:target_country>US</mz:target_country>
 <mz:product_type classId="10010" subClassId="3">Women's Dresses &amp; Dresses</mz:product_type>
 <mz:price unit="usd">298.00</mz:price>
 <mz:brand>Tadashi Shoji</mz:brand>
 <mz:condition>new</mz:condition>
 <mz:availability>In Stock</mz:availability>
 </entry>

 */

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
