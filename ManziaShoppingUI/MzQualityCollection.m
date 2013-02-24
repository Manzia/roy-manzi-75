//
//  MzQualityCollection.m
//  ManziaShoppingUI
//
//  Created by Macbook Pro on 2/23/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzQualityCollection.h"

@interface MzQualityCollection()

@property (nonatomic, copy, readwrite) NSString *qualitiesDirectory;

@end

@implementation MzQualityCollection

@synthesize qualitiesDirectory;

// Format for the Qualities Directory
static NSString * kQualityNameTemplate = @"Quality%.9f.%@";

// Format for the MzSearchItem files
static NSString *kQualityFileTemplate = @"quality-file%.9f";

// Extension for the Search directory
static NSString * kQualityExtension    = @"quality";

// File Prefix
static NSString *kQualityFilePrefix = @"quality-file";


@end
