//
//  MzQueryItem.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/4/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.

/*
 MzQueryItem objects represent possible search queries that a user
 might start from before creating MzSearchItems as a combination
 of brand + taskTypeName for example, "HP" + "Printer". MzQueryItem
 queryStrings are presented to the user as query suggestions in a
 UISearchDisplayController's tableView. MzQueryItem objects are stored
 in Core Data database and retrieved using NSFetchResultsController.
 
 If a user selects one of the presented queryStrings, they are 
 taken to the Customize screen where they add search options to
 create a MzSearchItem
 
 */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class MzTaskType;
@class MzTaskAttribute;

@interface MzQueryItem : NSManagedObject

// Because the value of MzQueryItem queryString property depends on
// a taskTypeName property of a MzTaskType object, when a MzTaskType
// object is deleted, all dependent
@property (nonatomic, retain) NSString * queryString;
@property (nonatomic, retain) NSString * queryId;


// Insert, Update and Delete MzQueryItem objects
+(void)updateMzQueryItemsForTaskType:(MzTaskType *)taskType inManagedObjectContext:(NSManagedObjectContext *)context;

+(void)deleteAllQueryItemsForTaskType:(MzTaskType *)taskType inManagedObjectContext:(NSManagedObjectContext *)context;

@end
