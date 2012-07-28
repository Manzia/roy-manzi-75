//
//  MzTaskParserOperation.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 7/24/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzTaskParserOperation.h"
#import "Logging.h"

@interface MzTaskParserOperation () <NSXMLParserDelegate>

// read/write variants of public properties

@property (copy, readwrite) NSError *parseError;

// private properties

#if ! defined(NDEBUG)
@property (assign, readwrite) NSTimeInterval debugDelaySoFar;
#endif

@property (retain, readonly ) NSMutableArray *mutableResults;
@property (retain, readwrite) NSXMLParser *collectionParser;
@property (retain, readonly ) NSMutableDictionary *tasksProperties;

@end

@implementation MzTaskParserOperation

//Accessors
@synthesize parseError;
@synthesize tasksProperties;
@synthesize debugDelay;
@synthesize debugDelaySoFar;
@synthesize mutableResults;
@synthesize collectionParser;
@synthesize xmldata;

// Initialization
- (id)initWithXMLData:(NSData *)data
{
    assert(data != nil);
    self = [super init];
    if (self != nil) {
        self->xmlData = [data copy];
        self->mutableResults  = [[NSMutableArray alloc] init];
        assert(self->mutableResults != nil);
        self->tasksProperties = [[NSMutableDictionary alloc] init];
        assert(self->tasksProperties != nil);
    }
    return self;
}

// Returns a copy of the current parseResults
- (NSArray *)parseResults
{
    return [self->mutableResults copy];
}

// NSOperation method
- (void)main
{
    BOOL success;
    
    // Set up the parser.
    assert(self.xmldata != nil);
    self.collectionParser = [[NSXMLParser alloc] initWithData:self.xmldata];
    assert(self.collectionParser != nil);
    
    self.collectionParser.delegate = self;  // we get all the NSXMLParser callbacks
    
    // Start the parsing.
    [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
     @"Start XML parsing for Task Collection"];
    
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
        [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
         @"XML parsing success for Task Collection"];
    } else {
        [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
         @"XML parsing failed for Task Collection with error: %@", self.parseError];
    }
    
    self.collectionParser = nil;
}

/* Basic Parse Algorithm
 Sample XML Data
 <?xml version="1.0"?>
 <feed xmlns="http://www.w3.org/2005/Atom" xmlns:mz="http://www.manzia.com/productContent">
 <mz:categories>
    <mz:category id="1000" name="Electronics" thumbnail_link="http://www.manzia.com/tasks/thumbnails/1000.jpg>
        <mz:taskTypes>
            <mz:taskType id="LN10001" name="Laptops & Netbooks" thumbnail_link="http://www.manzia.com/tasks/thumbnails/LN10001.jpg">
                <mz:taskAttributes>
                    <mz:taskAttributesCount>13</mz:taskAttributeCount>
                    <mz:taskAttribute id="LN100010" name="Memory">
                        <mz:taskAttributeValues value1="4GB or less" value2="8GB" value3="16GB" value4="32GB or more"/>
                    </mz:taskAttribute>
                    <mz:taskAttribute id="LN100011" name="Brand">
                        <mz:taskAttributeValues value1="Apple" value2="Dell" value3="HP" value4="Lenovo" value5="Samsung"
                            value6="Toshiba" value7="Acer" value8="Sony" value9="Asus" value10="Compaq"
                            value11="Gateway" value12="Fujitsu" value13="Alienware"/>
                    </mz:taskAttribute>
                    <mz:taskAttribute id="LN100012" name="Condition">
                        <mz:taskAttributeValues value1="New" value2="Used" value3="Refurbished"/>
                    </mz:taskAttribute>....
 
 
 Data Structure: uses an NSArray with NSMutableDictionary entries
 1- <category> tag - insert "id" and "name" into dictionary
 2- <taskType> tag - insert "id", "name", "thumbnailURL" into dictionary
 3- <taskAttribute> tag - insert "id" and "name" into dictionary
 4- <taskAttributeValues> tag - insert array of values into dictionary
 5- </taskAttribute> tag - insert the populated dictionary into array,
                        - remove the taskAttribute (id, name) and taskAttributeValues array
 6- </taskType> tag - remove the taskType(id, name, thumbnailURL) from dictionary
 7- </category> tag - remove all entries from the dictionary
 
*/

// Delegate methods for when parser encounters start tag elements
-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    assert(parser == self.collectionParser);
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
    
    
    // root element - ensure we have an array to insert task Category objects
    if ([elementName isEqualToString:@"feed"]) {
        assert(self.mutableResults != nil);
    }
    
    // Check for cancellation at the start of each element.
    
    if ( [self isCancelled] ) {
        self.parseError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
        [self.collectionParser abortParsing];
    } else
        
        // ignore the elements we don't need for now...these are kept in the XML schema
        // in case we need them in the future
        if ([elementName isEqualToString:@"categories"] || [elementName isEqualToString:@"taskTypes"]
            || [elementName isEqualToString:@"taskAttributes"] || [elementName isEqualToString:
                                                                   @"taskAttributesCount"]) {
            return;
        }
        
        // category element - ensure we have a dictionary to store task Types
        if ([elementName isEqualToString:@"category"]) {
            assert(self.tasksProperties != nil);
            
            // Starting a new category so remove all elements if not already empty
            if ([self.tasksProperties count] > 0) {
                [self.tasksProperties removeAllObjects];
            }
                        
            // Get the category attributes
            NSString *categoryId;
            NSString *categoryName;
            NSString *categoryImageUrl;
            
            categoryId = [attributeDict objectForKey:@"id"];
            categoryName = [attributeDict objectForKey:@"name"];
            categoryImageUrl = [attributeDict objectForKey:@"thumbnail_link"];
            
            if ((categoryId == nil) || ([categoryId length] == 0)) {
                [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
                 @"XML parse skipped, missing 'categoryId'"];
            } else {
                [self.tasksProperties setObject:categoryId forKey:kTaskParserResultCategoryId];
            }
            
            if ((categoryName == nil) || ([categoryName length] == 0)) {
                [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
                 @"XML parse skipped, missing 'categoryName'"];
            } else {
                [self.tasksProperties setObject:categoryName forKey:kTaskParserResultCategoryName];
            }
            
            if ((categoryImageUrl == nil) || ([categoryImageUrl length] == 0)) {
                [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
                 @"XML parse skipped, missing 'categoryImageURL'"];
            } else {
                [self.tasksProperties setObject:categoryImageUrl forKey:kTaskParserResultCategoryImageURL];
            }
        }
    
       
    // taskType element
    if ([elementName isEqualToString:@"taskType"]) {
        
        // Get the taskType attributes
        NSString *taskTypeId;
        NSString *taskTypeName;
        NSString *taskTypeImageUrl;
        
        taskTypeId = [attributeDict objectForKey:@"id"];
        taskTypeName = [attributeDict objectForKey:@"name"];
        taskTypeImageUrl = [attributeDict objectForKey:@"thumbnail_link"];
        
        if ((taskTypeId == nil) || ([taskTypeId length] == 0)) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
             @"XML parse skipped, missing 'taskTypeId'"];
        } else {
            [self.tasksProperties setObject:taskTypeId forKey:kTaskParserResultTaskTypeId];
        }
        
        if ((taskTypeName == nil) || ([taskTypeName length] == 0)) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
             @"XML parse skipped, missing 'taskTypeName'"];
        } else {
            [self.tasksProperties setObject:taskTypeName forKey:kTaskParserResultTaskTypeName];
        }
        
        if ((taskTypeImageUrl == nil) || ([taskTypeImageUrl length] == 0)) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
             @"XML parse skipped, missing 'taskTypeImageURL'"];
        } else {
            [self.tasksProperties setObject:taskTypeImageUrl forKey:kTaskParserResultTaskTypeImageURL];
        }
      
    }
    
    // taskAttribute element
    if ([elementName isEqualToString:@"taskAttribute"]) {
        
        // Get the taskAttributes
        NSString *taskAttributeId;
        NSString *taskAttributeName;
                
        taskAttributeId = [attributeDict objectForKey:@"id"];
        taskAttributeName = [attributeDict objectForKey:@"name"];
                
        if ((taskAttributeId == nil) || ([taskAttributeId length] == 0)) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
             @"XML parse skipped, missing 'taskAttributeId'"];
        } else {
            [self.tasksProperties setObject:taskAttributeId forKey:kTaskParserResultTaskAttributeId];
        }
        
        if ((taskAttributeName == nil) || ([taskAttributeName length] == 0)) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
             @"XML parse skipped, missing 'taskAttributeName'"];
        } else {
            [self.tasksProperties setObject:taskAttributeName forKey:kTaskParserResultTaskAttributeName];
        }      
                
    }

        
    // attributeOption element
    if ([elementName isEqualToString:@"taskAttributeValues"]) {
        
        // Get the attribute values
        NSArray *attributeValues = [attributeDict allValues];
        NSString *taskAttributeId = [self.tasksProperties objectForKey:kTaskParserResultTaskAttributeId];
        assert(taskAttributeId != nil);
        
        // Note that according to our XML schema it does not make sense to have a taskAttribute
        // which has no values...nonetheless an attribute can have one value and that value
        // could be the attribute
        // Note that the attributeOptionId == associated taskAttributeId
        if ((attributeValues == nil) || ([attributeValues count] == 0)) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:
             @"XML parse skipped, missing 'attributeValues'"];
        } else {
            [self.tasksProperties setObject:attributeValues forKey:kTaskParserResultAttributeOptionName];
            [self.tasksProperties setObject:taskAttributeId forKey:kTaskParserResultAttributeOptionId];
        }
    }
    
    return;    
}

// Delegate methods for when parser encounters end of tag elements
-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    // ignore root, empty and unused elements
    if ([elementName isEqualToString:@"categories"] || [elementName isEqualToString:@"taskTypes"]
        || [elementName isEqualToString:@"taskAttributes"] || [elementName isEqualToString:
                                                               @"taskAttributesCount"]) {
        return;
    }
    
    // taskAttribute end element
    if ([elementName isEqualToString:@"taskAttribute"]) {
        
        if ([self.tasksProperties count] == 0) {
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse skipped - missing all keys "];
        } else {
            
            // check the dictionary entries
            assert([[self.tasksProperties objectForKey:kTaskParserResultCategoryId] isKindOfClass:[NSString class]]);
            assert([[self.tasksProperties objectForKey:kTaskParserResultCategoryName] isKindOfClass:[NSString class]]);
            assert([[self.tasksProperties objectForKey:kTaskParserResultCategoryImageURL] isKindOfClass:[NSString class]]);
            assert([[self.tasksProperties objectForKey:kTaskParserResultTaskTypeId] isKindOfClass:[NSString class]]);
            assert([[self.tasksProperties objectForKey:kTaskParserResultTaskTypeName] isKindOfClass:[NSString class]]);
            assert([[self.tasksProperties objectForKey:kTaskParserResultTaskTypeImageURL] isKindOfClass:[NSString class]]);
            assert([[self.tasksProperties objectForKey:kTaskParserResultTaskAttributeId] isKindOfClass:[NSString class]]);
            assert([[self.tasksProperties objectForKey:kTaskParserResultTaskAttributeName] isKindOfClass:[NSString class]]);
            assert([[self.tasksProperties objectForKey:kTaskParserResultAttributeOptionId] isKindOfClass:[NSString class]]);
            assert([[self.tasksProperties objectForKey:kTaskParserResultAttributeOptionName] isKindOfClass:[NSArray class]]);
            
            // insert the dictionary into the array
            [[QLog log] logOption:kLogOptionXMLParseDetails withFormat:@"XML parse success for category: %@, tasktype: %@, taskAttribute: %@", [self.tasksProperties objectForKey:kTaskParserResultCategoryName], [self.tasksProperties objectForKey:kTaskParserResultTaskTypeName], [self.tasksProperties objectForKey:kTaskParserResultTaskAttributeName]];
            
            [self.mutableResults addObject:[self.tasksProperties copy]];
            
            // Remove the taskAttribute keys for the next pass...
            NSArray *keyArray = [NSArray arrayWithObjects:kTaskParserResultTaskAttributeId, kTaskParserResultTaskAttributeName, kTaskParserResultAttributeOptionId, kTaskParserResultAttributeOptionName, nil];
            [self.tasksProperties removeObjectsForKeys:keyArray];
        }               
    }
        
    // </taskType> tag - remove the taskType(id, name, thumbnailURL) from dictionary
    if ([elementName isEqualToString:@"taskType"]) {
        NSArray *keyArray = [NSArray arrayWithObjects:kTaskParserResultTaskTypeId, 
                             kTaskParserResultTaskTypeName, kTaskParserResultTaskTypeImageURL, nil];
        [self.tasksProperties removeObjectsForKeys:keyArray];
    }
    
    //</category> tag - remove all entries from the dictionary
    if ([elementName isEqualToString:@"category"]) {
        
        [self.tasksProperties removeAllObjects];        
    }
}

// Keys for task Category model objects
NSString *kTaskParserResultCategoryId = @"categoryId";      
NSString *kTaskParserResultCategoryName = @"categoryName";
NSString *kTaskParserResultCategoryImageURL = @"categoryImageURL";
NSString *kTaskParserResultTaskTypeId = @"taskTypeId";
NSString *kTaskParserResultTaskTypeImageURL = @"taskTypeImageURL";
NSString *kTaskParserResultTaskTypeName = @"taskTypeName";
NSString *kTaskParserResultTaskAttributeId = @"taskAttributeId";
NSString *kTaskParserResultTaskAttributeName = @"taskAttributeName";
NSString *kTaskParserResultAttributeOptionId = @"attributeOptionId";
NSString *kTaskParserResultAttributeOptionName = @"attributeOptionName";

@end
