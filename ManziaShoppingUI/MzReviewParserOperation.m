//
//  MzReviewParserOperation.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 1/30/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzReviewParserOperation.h"
#import "Logging.h"

@interface MzReviewParserOperation () <NSXMLParserDelegate>

// read/write variants of public properties

@property (copy, readwrite) NSError *parseError;

// private properties

#if ! defined(NDEBUG)
@property (assign, readwrite) NSTimeInterval debugDelaySoFar;
#endif

@property (retain, readonly ) NSMutableArray *mutableResults;
@property (retain, readwrite) NSXMLParser *reviewParser;
@property (retain, readonly ) NSMutableDictionary *reviewItemProperties;
@property(nonatomic, retain) NSMutableString *currentStringValue;


@end


@implementation MzReviewParserOperation

@synthesize parseError;
@synthesize reviewItemProperties;
@synthesize debugDelay;
@synthesize debugDelaySoFar;
@synthesize mutableResults;
@synthesize reviewParser;
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
        self->reviewItemProperties = [[NSMutableDictionary alloc] init];
        assert(self->reviewItemProperties != nil);
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
    self.reviewParser = [[NSXMLParser alloc] initWithData:self.xmldata];
    assert(self.reviewParser != nil);
    
    self.reviewParser.delegate = self;
    
    // Start the parsing.
    
    [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"Start XML parsing"];
    
    /* Write to file to test input
     NSFileManager *fileManager;
     fileManager = [NSFileManager defaultManager];
     NSLog(@"Current Directory Path: %@", [fileManager currentDirectoryPath]);
     [fileManager createFileAtPath:@"/Users/admin/Manzia/testXMLfile" contents:self.xmldata attributes:nil]; */
    //[self.xmldata writeToFile:@"testXMLfile" atomically:YES];
    
    success = [self.reviewParser parse];
    if (!success) {
        
        // If our parser delegate callbacks already set an error, we ignore the error
        // coming back from NSXMLParser.  Our delegate callbacks have the most accurate
        // error info.
        
        if (self.parseError == nil) {
            self.parseError = [self.reviewParser parserError];
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
    
    self.reviewParser = nil;
}

/*
 Below is sample XML ReviewItem entry:
 <?xml version="1.0" encoding="UTF-8"?>
    <mz:reviewMatches>
        <mz:reviewMatch>
            <mz:reviewId>12345</mz:reviewId>
            <mz:reviewSku>4153097418</mz:reviewSku>
            <mz:reviewCategory>Apps</mz:reviewCategory>
            <mz:reviewTitle>greatest App</mz:reviewTitle>
            <mz:reviewContent> absolutely marvelous</mz:reviewContent>
            <mz:reviewRating>5.0</mz:reviewRating>
            <mz:reviewSubmitTime>2007-08-10T08:10:52</mz:reviewSubmitTime>
            <mz:reviewAuthor>royt75</mz:reviewAuthor>
        </mz:reviewMatch>
 </mz:reviewMatches>
 
 */

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    assert(parser == self.reviewParser);
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
    
    
    // root element - ensure we have an array to insert review Items
    if ([elementName isEqualToString:@"reviewMatches"]) {
        assert(self.mutableResults != nil);
    }
    
    // Check for cancellation at the start of each element.
    if ( [self isCancelled] ) {
        self.parseError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
        [self.reviewParser abortParsing];
        
    } else
        // entry element - ensure we have a dictionary to store product Item attributes
        if ([elementName isEqualToString:@"reviewMatch"]) {
            assert(self.reviewItemProperties != nil);
            
            // Starting a new entry so remove all elements
            [self.reviewItemProperties removeAllObjects];
        }
    
    // reviewId element - Key
    if ([elementName isEqualToString:@"reviewId"]) {
        storeCharacters = YES;
    }
    
    // reviewSku element
    if ([elementName isEqualToString:@"reviewSku"]) {
        storeCharacters = YES;
    }
    
    // reviewCategory element
    if ([elementName isEqualToString:@"reviewCategory"]) {
        storeCharacters = YES;
    }
    
    // reviewTitle element
    if ([elementName isEqualToString:@"reviewTitle"]) {
        storeCharacters = YES;
    }
    
    // reviewContent element
    if ([elementName isEqualToString:@"reviewContent"]) {
        storeCharacters = YES;
    }
    
    // reviewRating element
    if ([elementName isEqualToString:@"reviewRating"]) {
        storeCharacters = YES;
    }
    
    // reviewSubmitTime element
    if ([elementName isEqualToString:@"reviewSubmitTime"]) {
        storeCharacters = YES;
    }
    
    // reviewAuthor element
    if ([elementName isEqualToString:@"reviewAuthor"]) {
        storeCharacters = YES;
    }
    
    return;
}

// Delegate methods for when parser encounters end of tag elements
-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    // ignore root, empty and unused elements
    if ([elementName isEqualToString:@"reviewMatches"]) {
        return;
    }
    
    // copy reviewId
    if ([elementName isEqualToString:@"reviewId"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'reviewId'"];
        } else {
            [self.reviewItemProperties setObject:self.currentStringValue forKey:kReviewParserReviewId];
        }
        currentStringValue = nil;
    }
    
    // copy reviewSku string
    if ([elementName isEqualToString:@"reviewSku"]) {
        
        if ( (self.currentStringValue != nil) && ([self.currentStringValue length] > 0) ) {
            [self.reviewItemProperties setObject:self.currentStringValue forKey:kReviewParserReviewSku];
        } else {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'reviewSku'"];
            
        }
        currentStringValue = nil;
    }
    
    // copy reviewCategory string
    if ([elementName isEqualToString:@"reviewCategory"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'reviewCategory'"];
        } else {
            [self.reviewItemProperties setObject:self.currentStringValue forKey:kReviewParserReviewCategory];
        }
        currentStringValue = nil;
    }
    
    // copy reviewTitle string
    if ([elementName isEqualToString:@"reviewTitle"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'reviewTitle'"];
        } else {
            [self.reviewItemProperties setObject:self.currentStringValue forKey:kReviewParserReviewTitle];
        }
        currentStringValue = nil;
    }
    
    // copy reviewContent string
    if ([elementName isEqualToString:@"reviewContent"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [self.reviewItemProperties setObject:KDefaultAttributeValue forKey:kReviewParserReviewContent];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'reviewContent'"];
        } else {
            [self.reviewItemProperties setObject:self.currentStringValue forKey:kReviewParserReviewContent];
        }
        currentStringValue = nil;
    }
    
    // copy entry's reviewRating
    if ([elementName isEqualToString:@"reviewRating"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [self.reviewItemProperties setObject:KDefaultAttributeValue forKey:kReviewParserReviewRating];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'reviewRating'"];
        } else {
            [self.reviewItemProperties setObject:self.currentStringValue forKey:kReviewParserReviewRating];
        }
        currentStringValue = nil;
    }
    
    // copy reviewSubmitTime string
    if ([elementName isEqualToString:@"reviewSubmitTime"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [self.reviewItemProperties setObject:KDefaultAttributeValue forKey:kReviewParserReviewSubmitTime];
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'reviewSubmitTime'"];
        } else {
            [self.reviewItemProperties setObject:self.currentStringValue forKey:kReviewParserReviewSubmitTime];
        }
        currentStringValue = nil;
    }
    
    
    // copy reviewAuthor
    if ([elementName isEqualToString:@"reviewAuthor"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'reviewAuthor'"];
        } else {
            [self.reviewItemProperties setObject:self.currentStringValue forKey:kReviewParserReviewAuthor];
        }
        currentStringValue = nil;
    }
    
    // Add properties dictionary to array, stop storing characters and reset currentStringValue
    if ([elementName isEqualToString:@"reviewMatch"]) {
        storeCharacters = NO;
        self.currentStringValue = nil;
        
        if ([self.reviewItemProperties count] == 0) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse Review Item skipped "];
        } else {
                 assert([[self.reviewItemProperties objectForKey:kReviewParserReviewId] isKindOfClass:[NSString class]]);
                 assert([[self.reviewItemProperties objectForKey:kReviewParserReviewSku] isKindOfClass:[NSString class]]);
                 assert([[self.reviewItemProperties objectForKey:kReviewParserReviewCategory] isKindOfClass:[NSString class]]);
                assert([[self.reviewItemProperties objectForKey:kReviewParserReviewRating] isKindOfClass:[NSString class]]);
                assert([[self.reviewItemProperties objectForKey:kReviewParserReviewSubmitTime] isKindOfClass:[NSString class]]);
                 
                 // Verify the Results from Parsing
                 if(![[self.reviewItemProperties objectForKey:kReviewParserReviewTitle] isKindOfClass:[NSString class]]) {
                     [self.reviewItemProperties setObject:KDefaultAttributeValue forKey:kReviewParserReviewTitle];
                 }
                                
                 if(![[self.reviewItemProperties objectForKey:kReviewParserReviewAuthor] isKindOfClass:[NSString class]]) {
                     [self.reviewItemProperties setObject:KDefaultAttributeValue forKey:kReviewParserReviewAuthor];
                 }
                 
                 if(![[self.reviewItemProperties objectForKey:kReviewParserReviewContent] isKindOfClass:[NSString class]]) {
                     [self.reviewItemProperties setObject:KDefaultAttributeValue forKey:kReviewParserReviewContent];
                 }
                 
                 // Log Success!
                 [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"Review XML parse success for SKU: %@", [self.reviewItemProperties objectForKey:kReviewParserReviewSku]];
                 [self.mutableResults addObject:[self.reviewItemProperties copy]];
                 [self.reviewItemProperties removeAllObjects];             
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
NSString * kReviewParserReviewId = @"reviewId";
NSString * kReviewParserReviewSku = @"reviewSku";
NSString * kReviewParserReviewTitle = @"reviewTitle";
NSString * kReviewParserReviewCategory = @"reviewCategory";
NSString * kReviewParserReviewContent = @"reviewContent";
NSString * kReviewParserReviewRating = @"reviewRating";
NSString * kReviewParserReviewSubmitTime = @"reviewSubmitTime";
NSString * kReviewParserReviewAuthor = @"reviewAuthor";

@end
