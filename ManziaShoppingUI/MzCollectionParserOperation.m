//
//  MzCollectionParserOperation.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 6/3/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//


#import "MzCollectionParserOperation.h"
#import "Logging.h"
#import "MzProductCollection.h"


@interface MzCollectionParserOperation () <NSXMLParserDelegate>

// read/write variants of public properties

@property (copy, readwrite) NSError *parseError;

// private properties

#if ! defined(NDEBUG)
@property (assign, readwrite) NSTimeInterval debugDelaySoFar;
#endif

@property (retain, readonly ) NSMutableArray *mutableResults;
@property (retain, readwrite) NSXMLParser *collectionParser;
@property (retain, readonly ) NSMutableDictionary *productItemProperties;
@property(nonatomic, retain) NSMutableString *currentStringValue;


@end


@implementation MzCollectionParserOperation

@synthesize parseError;
@synthesize productItemProperties;
@synthesize debugDelay;
@synthesize debugDelaySoFar;
@synthesize mutableResults;
@synthesize collectionParser;
@synthesize currentStringValue;
@synthesize xmldata;

// Default value for MzProductItems attributes missing values
static NSString *KDefaultAttributeValue = @"unknown";

// Initialization
- (id)initWithXMLData:(NSData *)data
{
    assert(data != nil);
    self = [super init];
    if (self != nil) {
        self->xmldata = [data copy];
        self->mutableResults  = [[NSMutableArray alloc] init];
        assert(self->mutableResults != nil);
        self->productItemProperties = [[NSMutableDictionary alloc] init];
        assert(self->productItemProperties != nil);
    }
    return self;
}

// Returns a copy of the current parseResults
- (NSArray *)parseResults
{
    return [self->mutableResults copy];
}

- (void)main
{
    BOOL success;
    
    // Set up the parser.
    
    assert(self.xmldata != nil);
    self.collectionParser = [[NSXMLParser alloc] initWithData:self.xmldata];
    assert(self.collectionParser != nil);
    
    self.collectionParser.delegate = self;
    
    // Start the parsing.
    
    [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"Start XML parsing"];
    
    /* Write to file to test input
    NSFileManager *fileManager;
    fileManager = [NSFileManager defaultManager];
    NSLog(@"Current Directory Path: %@", [fileManager currentDirectoryPath]);
    [fileManager createFileAtPath:@"/Users/admin/Manzia/testXMLfile" contents:self.xmldata attributes:nil]; */
    //[self.xmldata writeToFile:@"testXMLfile" atomically:YES];
    
    success = [self.collectionParser parse];
    if (!success) {
        
        // If our parser delegate callbacks already set an error, we ignore the error 
        // coming back from NSXMLParser.  Our delegate callbacks have the most accurate 
        // error info.
        
        if (self.parseError == nil) {
            self.parseError = [self.collectionParser parserError];
            assert(self.parseError != nil);
        }
    }
    
    // Debug version - delay so we have time to test the cancellation path.
    
#if ! defined(NDEBUG)
    {
        while (self.debugDelaySoFar < self.debugDelay) {
            
            // We always sleep in one second intervals.              
            [NSThread sleepForTimeInterval:1.0];
            self.debugDelaySoFar += 1.0;
            
            if ( [self isCancelled] ) {
                
                // If we notice the cancel, we override any error we got from the XML.
                self.parseError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
                break;
            }
        }
    }
#endif
    
    if (self.parseError == nil) {
        [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parsing success"];
    } else {
        [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parsing failed %@", [self.parseError localizedDescription]];
    }
    
    self.collectionParser = nil;
}

/*
 Below is sample XML product Item entry:
 <mz:rankedProducts>
    <mz:rankedProduct>
        <mz:title type="text">Tadashi Shoji One Shoulder Lace Sheath Dress</mz:title>
        <mz:link rel="alternate" type="text/html" href="http://shop.nordstrom.com/s/tadashi-shoji-one-shoulder-lace-sheath-dress/3205422?"/>
        <mz:image_link>http://aws.amazon.com/image/120000</mz:image_link>
        <mz:thumbnail_link>http://aws.amazon.com/thumbnail/120000<thumbnail_link>
        <mz:id>100303001</mz:id>
        <mz:description>Tadashi Shoji One Shoulder Lace Sheath Dress.</mz:description>
        <mz:content_language>en</mz:content_language>
        <mz:target_country>US</mz:target_country>
        <mz:product_type classId="10010" subClassId="3">Women's Dresses &amp; Dresses</mz:product_type>
        <mz:price unit="usd">298.00</mz:price>
        <mz:brand>Tadashi Shoji</mz:brand>
        <mz:condition>new</mz:condition>
        <mz:availability>In Stock</mz:availability>
    </mz:rankedProduct>
 </mz:rankedProducts>
 
 */

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    assert(parser == self.collectionParser);
#pragma unused(parser)
#pragma unused(namespaceURI)
#pragma unused(qName)
    
    // In the debug build, if we've been told to delay, and we haven't already delayed 
    // enough, just sleep for 0.1 seconds.
    
#if ! defined(NDEBUG)
    if (self.debugDelaySoFar < self.debugDelay) {
        [NSThread sleepForTimeInterval:0.1];
        self.debugDelaySoFar += 0.1;
    }
#endif

       
    // root element - ensure we have an array to insert product Items
    if ([elementName isEqualToString:@"rankedProducts"]) {
        assert(self.mutableResults != nil);
    }
    
    // Check for cancellation at the start of each element.
    if ( [self isCancelled] ) {
        self.parseError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
        [self.collectionParser abortParsing];
    } else
    // entry element - ensure we have a dictionary to store product Item attributes
    if ([elementName isEqualToString:@"rankedProduct"]) {
        assert(self.productItemProperties != nil);
                        
        // Starting a new entry so remove all elements
        [self.productItemProperties removeAllObjects];               
    }
    
    // title element 
    if ([elementName isEqualToString:@"title"]) {
        storeCharacters = YES;        
    }
    
    // link element
    if ([elementName isEqualToString:@"link"]) {
        storeCharacters = NO;
        
        // Declare attribute properties
        NSString *detailPath;
                
        detailPath = [attributeDict objectForKey:@"href"];
        if ( (detailPath == nil) || ([detailPath length] == 0) ) {
            //[self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultDetailsPath];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped - was missing 'detailPath'"];
        } else {
            [self.productItemProperties setObject:detailPath forKey:kCollectionParserResultDetailsPath];
        }
        detailPath = nil;             
    }
    
    // image_link element
    if ([elementName isEqualToString:@"image_link"]) {
        storeCharacters = YES;        
    }
    
    // thumbnail_link element
    if ([elementName isEqualToString:@"thumbnail_link"]) {
        storeCharacters = YES;        
    }
    
    // id element - productID
    if ([elementName isEqualToString:@"id"]) {
        storeCharacters = YES;        
    }
    
    // content description element
    if ([elementName isEqualToString:@"description"]) {
        storeCharacters = YES;        
    }
    
    // content_language element
    if ([elementName isEqualToString:@"content_language"]) {
        storeCharacters = YES;        
    }
    
    // target_country element
    if ([elementName isEqualToString:@"target_country"]) {
        storeCharacters = YES;        
    }
    
    // product_type element
    if ([elementName isEqualToString:@"product_type"]) {
        storeCharacters = NO;
        
        // Declare attribute properties
        NSString *classId;
        NSString * subClassId;
        
        // add the ClassID to the dictionary
        classId = [attributeDict objectForKey:@"classId"];
        if ( (classId == nil) || ([classId length] == 0) ) {
            [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultClassID];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'classId'"];
        } else {
            [self.productItemProperties setObject:classId forKey:kCollectionParserResultClassID];
        }
        
        // add the subClassID to the dictionary
        subClassId = [attributeDict objectForKey:@"subClassId"];
        if ( (subClassId == nil) || ([subClassId length] == 0) ) {
            [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultSubClassID];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'subClassId'"];
        } else {
            [self.productItemProperties setObject:subClassId forKey:kCollectionParserResultSubClassID];
        }

        classId = nil;     
        subClassId = nil;
    }
    
    // price element
    if ([elementName isEqualToString:@"price"]) {
        storeCharacters = YES;
        
        // Declare attribute properties
        NSString *priceUnit;
                
        // add the price Unit to the dictionary
        priceUnit = [attributeDict objectForKey:@"unit"];
        if ( (priceUnit == nil) || ([priceUnit length] == 0) ) {
            [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultPriceUnit];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'price unit'"];
        } else {
            [self.productItemProperties setObject:priceUnit forKey:kCollectionParserResultPriceUnit];
        }
        priceUnit = nil;

    }
    
    // condition element
    if ([elementName isEqualToString:@"condition"]) {
        storeCharacters = YES;        
    }
    
    // availability element
    if ([elementName isEqualToString:@"availability"]) {
        storeCharacters = YES;        
    }    
    return;    
}

// Delegate methods for when parser encounters end of tag elements
-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    // ignore root, empty and unused elements
    if ([elementName isEqualToString:@"rankedProducts"]) {
        return;
    }
    
    // copy entry's title
    if ([elementName isEqualToString:@"title"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'productTitle'"];
        } else {
            [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultTitle];                     
        }
        currentStringValue = nil;
    }
    
    // copy image_link string
    if ([elementName isEqualToString:@"image_link"]) {
        
        if ( (self.currentStringValue != nil) && ([self.currentStringValue length] > 0) ) {
            [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultImagePath];     
        } else {
            [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultImagePath];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'remoteImagePath'"];
                                
        }
        currentStringValue = nil;
    }
    
    // copy thumbnail_link string
    if ([elementName isEqualToString:@"thumbnail_link"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'remoteThumbnailPath'"];
        } else {
            [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultThumbNailPath];                     
        }
        currentStringValue = nil;
    }
    
    // copy id string
    if ([elementName isEqualToString:@"id"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'productId'"];
        } else {
            [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultProductID];                     
        }
        currentStringValue = nil;
    }

    // copy the p string - product description
    if ([elementName isEqualToString:@"description"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultDescription];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'productDescription'"];
        } else {
            [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultDescription];                     
        }
        currentStringValue = nil;
    }

    // copy entry's content_language
    if ([elementName isEqualToString:@"content_language"]) {
            
            if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
                [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultLanguage];
                [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'productLanguage'"];
            } else {
                [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultLanguage];                     
            }
            currentStringValue = nil;
     }

    // copy target_country string
    if ([elementName isEqualToString:@"target_country"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultCountry];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'productCountry'"];
        } else {
            [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultCountry];                     
        }
        currentStringValue = nil;
    }

    
    // copy entry's price
    if ([elementName isEqualToString:@"price"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'productPriceAmount'"];
        } else {
            [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultPriceAmount];                     
        }
        currentStringValue = nil;
    }

    // copy the brand string
    if ([elementName isEqualToString:@"brand"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultBrand];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'productBrand'"];
        } else {
            [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultBrand];                     
        }
        currentStringValue = nil;
    }
    
    // copy entry's condition
    if ([elementName isEqualToString:@"condition"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultCondition];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'productCondition'"];
        } else {
            [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultCondition];                     
        }
        currentStringValue = nil;
    }
    
    // copy entry's availability
    if ([elementName isEqualToString:@"availability"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultAvailability];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'productAvailability'"];
        } else {
            [self.productItemProperties setObject:self.currentStringValue forKey:kCollectionParserResultAvailability];                     
        }
        currentStringValue = nil;
    }
        
    
    // Add properties dictionary to array, stop storing characters and reset currentStringValue
    if ([elementName isEqualToString:@"rankedProduct"]) {
        storeCharacters = NO;
        self.currentStringValue = nil;
                
            if ([self.productItemProperties count] == 0) {
                [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse Product Item skipped "];
            } else {
                /*if ([self.productItemProperties objectForKey:kCollectionParserResultImagePath] == nil) {
                    [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse Product Item skipped, missing Product Image"];
                } else*/ if ([self.productItemProperties objectForKey:kCollectionParserResultThumbNailPath] == nil) {
                    [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse Product Item skipped, missing Product Thumbnail"];
                } else {
                    assert([[self.productItemProperties objectForKey:kCollectionParserResultProductID] isKindOfClass:[NSString class]]);
                    assert([[self.productItemProperties objectForKey:kCollectionParserResultTitle] isKindOfClass:[NSString class]]);
                    assert([[self.productItemProperties objectForKey:kCollectionParserResultDetailsPath] isKindOfClass:[NSString class]]);
                    
                    // In case "image_link" element is missing
                    if(![[self.productItemProperties objectForKey:kCollectionParserResultImagePath] isKindOfClass:[NSString class]]) {
                        [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultImagePath];
                    }
                    assert([[self.productItemProperties objectForKey:kCollectionParserResultThumbNailPath] isKindOfClass:[NSString class]]);
                    
                    if(![[self.productItemProperties objectForKey:kCollectionParserResultDescription] isKindOfClass:[NSString class]]) {
                        [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultDescription];
                    }
                    
                    if(![[self.productItemProperties objectForKey:kCollectionParserResultLanguage] isKindOfClass:[NSString class]]) {
                        [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultLanguage];
                    }
                    
                    if(![[self.productItemProperties objectForKey:kCollectionParserResultCountry] isKindOfClass:[NSString class]]) {
                        [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultCountry];
                    }
                    
                    if(![[self.productItemProperties objectForKey:kCollectionParserResultClassID] isKindOfClass:[NSString class]]) {
                        [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultClassID];
                    }
                    
                    if(![[self.productItemProperties objectForKey:kCollectionParserResultSubClassID] isKindOfClass:[NSString class]]) {
                        [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultSubClassID];
                    }
                    
                    if(![[self.productItemProperties objectForKey:kCollectionParserResultPriceUnit] isKindOfClass:[NSString class]]) {
                        [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultPriceUnit];
                    }
                    
                    assert([[self.productItemProperties objectForKey:kCollectionParserResultPriceAmount] isKindOfClass:[NSString class]]);
                    
                    if(![[self.productItemProperties objectForKey:kCollectionParserResultBrand] isKindOfClass:[NSString class]]) {
                        [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultBrand];
                    }
                    
                    if(![[self.productItemProperties objectForKey:kCollectionParserResultCondition] isKindOfClass:[NSString class]]) {
                        [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultCondition];
                    }
                    
                    if(![[self.productItemProperties objectForKey:kCollectionParserResultAvailability] isKindOfClass:[NSString class]]) {
                        [self.productItemProperties setObject:KDefaultAttributeValue forKey:kCollectionParserResultAvailability];
                    }
                    
                    // Log Success!
                    [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"Product XML parse success %@", [self.productItemProperties objectForKey:kCollectionParserResultProductID]];
                    [self.mutableResults addObject:[self.productItemProperties copy]];
                    [self.productItemProperties removeAllObjects];
                }
            }
        }
}


// append characters to the currentStringValue
-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (storeCharacters) {
        if(!currentStringValue) {
            currentStringValue =[[NSMutableString alloc] init];
        }
        [currentStringValue appendString:string];
    }
    
}


// Keys for ProductItem properties
NSString * kCollectionParserResultTitle = @"productTitle";      
NSString * kCollectionParserResultDetailsPath = @"productDetailPath"; 
NSString * kCollectionParserResultImagePath = @"remoteImagePath"; 
NSString * kCollectionParserResultThumbNailPath = @"remoteThumbnailPath";
NSString * kCollectionParserResultProductID = @"productID";
NSString * kCollectionParserResultDescription = @"productDescription";
NSString * kCollectionParserResultLanguage = @"productLanguage"; 
NSString * kCollectionParserResultCountry = @"productCountry";  
NSString * kCollectionParserResultClassID = @"productClassID";  
NSString * kCollectionParserResultSubClassID = @"productSubClassID";
NSString * kCollectionParserResultPriceUnit = @"productPriceUnit"; 
NSString * kCollectionParserResultPriceAmount = @"productPriceAmount";
NSString * kCollectionParserResultBrand = @"productBrand";      
NSString * kCollectionParserResultCondition = @"productCondition";  
NSString * kCollectionParserResultAvailability = @"productAvailability";


@end
