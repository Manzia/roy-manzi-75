//
//  MzQualityCollection.h
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 2/23/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MzQualityCollection : NSObject

// Qualities Directory
@property (nonatomic, copy, readonly) NSString *qualitiesDirectory;

// Add a Product Quality to the Quality Collection
-(void)addProductQuality:(NSString *)productQuality;

// assigns an existing Qualities Directory or creates a new one if none
// is found - this method was not turned into an initializer becoz it
// requires a bit of setup and its generally not good design to have too
// much going on in the initializer.
-(BOOL)addQualityCollection;

// Get all the "deserialized" Qualities from the Qualities Directory
-(NSArray *)allProductQualities;

// Removes old Files ( > 1 week) from the Qualities Directory
-(void)cleanQualitiesDirectory;

// Saves all Product Qualities to an existing Qualities Directory
-(BOOL)saveQualityCollection;

@end
