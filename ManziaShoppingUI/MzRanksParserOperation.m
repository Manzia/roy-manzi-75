//
//  MzRanksParserOperation.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 2/28/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzRanksParserOperation.h"
#import "Logging.h"

@interface MzRanksParserOperation () <NSXMLParserDelegate>

// read/write variants of public properties

@property (copy, readwrite) NSError *parseError;

// private properties

#if ! defined(NDEBUG)
@property (assign, readwrite) NSTimeInterval debugDelaySoFar;
#endif

@property (retain, readonly ) NSMutableArray *mutableResults;
@property (retain, readwrite) NSXMLParser *ranksParser;
@property (retain, readonly ) NSMutableDictionary *rankItemProperties;
@property(nonatomic, retain) NSMutableString *currentStringValue;

@end

@implementation MzRanksParserOperation

@synthesize parseError;
@synthesize rankItemProperties;
@synthesize debugDelay;
@synthesize debugDelaySoFar;
@synthesize mutableResults;
@synthesize ranksParser;
@synthesize currentStringValue;
@synthesize xmldata;

// Default value for attributes missing values
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
        self->rankItemProperties = [[NSMutableDictionary alloc] init];
        assert(self->rankItemProperties != nil);
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
    self.ranksParser = [[NSXMLParser alloc] initWithData:self.xmldata];
    assert(self.ranksParser != nil);
    
    self.ranksParser.delegate = self;
    
    // Start the parsing.
    
    [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"Start XML parsing"];
    
    /* Write to file to test input
     NSFileManager *fileManager;
     fileManager = [NSFileManager defaultManager];
     NSLog(@"Current Directory Path: %@", [fileManager currentDirectoryPath]);
     [fileManager createFileAtPath:@"/Users/admin/Manzia/testXMLfile" contents:self.xmldata attributes:nil];
     //[self.xmldata writeToFile:@"testXMLfile" atomically:YES]; */
    
    success = [self.ranksParser parse];
    if (!success) {
        
        // If our parser delegate callbacks already set an error, we ignore the error
        // coming back from NSXMLParser.  Our delegate callbacks have the most accurate
        // error info.
        
        if (self.parseError == nil) {
            self.parseError = [self.ranksParser parserError];
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
    
    self.ranksParser = nil;
}

/*
 Below is sample XML ReviewItem entry:
 <?xml version="1.0" encoding="UTF-8"?>
    <mz:rankResults>
        <mz:rankResult>
            <mz:rankQuality>attractive display</mz:rankQuality>
            <mz:rankRating>10</mz:rankRating>
        </mz:rankResult>
        <mz:rankResult>
            <mz:rankQuality>lightweight</mz:rankQuality>
            <mz:rankRating>5</mz:rankRating>
        </mz:rankResult>
    </mz:rankResults>  
 */

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    assert(parser == self.ranksParser);
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
    if ([elementName isEqualToString:@"rankResults"]) {
        assert(self.mutableResults != nil);
    }
    
    // Check for cancellation at the start of each element.
    if ( [self isCancelled] ) {
        self.parseError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
        [self.ranksParser abortParsing];
        
    } else
        // entry element - ensure we have a dictionary to store product Item attributes
        if ([elementName isEqualToString:@"rankResult"]) {
            assert(self.rankItemProperties != nil);
            
            // Starting a new entry so remove all elements
            [self.rankItemProperties removeAllObjects];
        }
    
    // rankQuality element - Key
    if ([elementName isEqualToString:@"rankQuality"]) {
        storeCharacters = YES;
    }
    
    // rankRating element
    if ([elementName isEqualToString:@"reviewRating"]) {
        storeCharacters = YES;
    }
        
    return;
}

// Delegate methods for when parser encounters end of tag elements
-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    // ignore root, empty and unused elements
    if ([elementName isEqualToString:@"rankResults"]) {
        return;
    }
    
    // copy rankQuality
    if ([elementName isEqualToString:@"rankQuality"]) {
        
        if ( (self.currentStringValue == nil) || ([self.currentStringValue length] == 0) ) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped, missing 'rankQuality'"];
        } else {
            [self.rankItemProperties setObject:self.currentStringValue forKey:kParserRankQuality];
        }
        currentStringValue = nil;
    }
    
    // copy rankRating string
    if ([elementName isEqualToString:@"rankRating"]) {
        
        if ( (self.currentStringValue != nil) && ([self.currentStringValue length] > 0) ) {
            [self.rankItemProperties setObject:self.currentStringValue forKey:kParserRankRating];
        } else {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse was missing 'rankRating'"];
            
        }
        currentStringValue = nil;
    }
    
    // Add properties dictionary to array, stop storing characters and reset currentStringValue
    if ([elementName isEqualToString:@"rankResult"]) {
        storeCharacters = NO;
        self.currentStringValue = nil;
        
        if ([self.rankItemProperties count] == 0) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse RankResults Item skipped "];
        } else {
            assert([[self.rankItemProperties objectForKey:kParserRankQuality] isKindOfClass:[NSString class]]);
            assert([[self.rankItemProperties objectForKey:kParserRankRating] isKindOfClass:[NSString class]]);
                        
            // Log Success!
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"RankResults XML parse success"];
            [self.mutableResults addObject:[self.rankItemProperties copy]];
            [self.rankItemProperties removeAllObjects];
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
NSString * kParserRankQuality = @"rankQuality";
NSString * kParserRankRating = @"rankRating";

@end
