//
//  MzSearchCollection.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/2/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

/*
 MzSearchCollection handles all the file operations related
 to the Search Directory. Each file in the Search Directory is
 a serialized MzSearchItem (property List). Operations include:
 - add a serialized MzSearchItem to the Search Directory
 - remove a serialized MzSearchItem from the Search Directory e.g
 if requested by user 
 - when the app moves to background, remove all completed serialized
 MzSearchItems
 - remove all serialized MzSearchItems if user indicates so in
 the preferences (NSUserDefaults option - "Clear Cache")
 - retrieve serialized MzSearchItems for use by UITableViewControllers etc.
 */

 

#import <Foundation/Foundation.h>
#import "MzSearchItem.h"

@interface MzSearchCollection : NSObject {
    NSString *searchDirectory;      // directory with serialized MzSearchItems
}

// Search Directory
@property (nonatomic, copy, readonly) NSString *searchDirectory;

// assigns an existing Search Directory or creates a new one if none
// is found - this method was not turned into an initializer becoz it
// requires a bit of setup and its generally not good design to have too
// much going on in the initializer.
-(BOOL)addSearchCollection;

// Add a MzSearchItem to the Search Directory
-(BOOL)addSearchItem:(MzSearchItem *)searchItem;

// Remove a MzSearchItem from the Search Directory
-(BOOL)removeSearchItem:(MzSearchItem *)searchItem;

// Remove a MzSearchItem using the searchTitle and Timestamp to eliminate the
// possibility of a removing MzSearchItems with the same searchTitles
-(BOOL)removeSearchItemWithTitle:(NSString *)searchTitle andTimestamp:(NSDate *)timestamp;

// Remove all completed MzSearchItems from the Search Directory
-(BOOL)removeSearchItemsWithStatus:(SearchItemState)searchStatus;

// Get all the "deserialized" MzSearchItems from the Search Directory
-(NSArray *)allSearchItems;

@end
