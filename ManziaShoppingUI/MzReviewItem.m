//
//  MzReviewItem.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 1/30/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzReviewItem.h"
#import "MzProductItem.h"


@interface MzReviewItem ()

@property (nonatomic, strong, readwrite) NSString * reviewAuthor;
@property (nonatomic, strong, readwrite) NSString * reviewCategory;
@property (nonatomic, strong, readwrite) NSString * reviewContent;
@property (nonatomic, strong, readwrite) NSString * reviewId;
@property (nonatomic, strong, readwrite) NSNumber * reviewRating;
@property (nonatomic, strong, readwrite) NSString * reviewSku;
@property (nonatomic, strong, readwrite) NSDate * reviewSubmitTime;
@property (nonatomic, strong, readwrite) NSString * reviewTitle;
@property (nonatomic, strong, readwrite) NSString *reviewSource;

@end

@implementation MzReviewItem

@dynamic reviewAuthor;
@dynamic reviewCategory;
@dynamic reviewContent;
@dynamic reviewId;
@dynamic reviewRating;
@dynamic reviewSku;
@dynamic reviewSubmitTime;
@dynamic reviewTitle;
@dynamic reviewProduct;
@dynamic reviewSource;

#pragma mark * Insert Review Items

// Creates a MzReviewItem object with the specified properties in the specified context.
// The properties dictionary is keyed by property names, in a KVC fashion.

+ (MzReviewItem *)insertNewMzReviewItemWithProperties:(NSDictionary *)properties inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    MzReviewItem *insertResult;
    
    assert(properties != nil);
    assert( [[properties objectForKey:@"reviewId"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"reviewSku"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"reviewCategory"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"reviewTitle"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"reviewContent"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"reviewRating"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"reviewSubmitTime"] isKindOfClass:[NSString class]] );
    assert( [[properties objectForKey:@"reviewAuthor"] isKindOfClass:[NSString class]] );
    assert([[properties objectForKey:@"reviewSource"] isKindOfClass:[NSString class]] );
        
    assert(managedObjectContext != nil);
    
    insertResult = (MzReviewItem *) [NSEntityDescription insertNewObjectForEntityForName:@"MzReviewItem" inManagedObjectContext:managedObjectContext];
    
    // check we have a valid MzReviewItem and assign the new properties
    if (insertResult != nil) {
        assert([insertResult isKindOfClass:[MzReviewItem class]]);
        
        insertResult.reviewId = [[properties objectForKey:@"reviewId"] copy];
        assert(insertResult.reviewId != nil);
        
        insertResult.reviewSku = [[properties objectForKey:@"reviewSku"] copy];
        insertResult.reviewTitle = [[properties objectForKey:@"reviewTitle"] copy];
        insertResult.reviewCategory = [[properties objectForKey:@"reviewCategory"] copy];
        insertResult.reviewContent = [[properties objectForKey:@"reviewContent"] copy];
        insertResult.reviewAuthor = [[properties objectForKey:@"reviewAuthor"] copy];
        insertResult.reviewSource = [[properties objectForKey:@"reviewSource"] copy];
        
        // Convert the Rating
        double rating = [[properties objectForKey:@"reviewRating"] doubleValue];
        insertResult.reviewRating = [NSNumber numberWithDouble:rating];
        
        //Convert the SubmitTime
        NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        
        [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
        [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        
        // Convert the RFC 3339 date time string to an NSDate.
        NSDate *date = [rfc3339DateFormatter dateFromString:[properties objectForKey:@"reviewSubmitTime"]];
        assert(date != nil);
        insertResult.reviewSubmitTime = date;
        
    }
    
    // Start out Thumbnail GET
    //[insertResult startGetThumbnail];
    
    return insertResult;
}


@end
