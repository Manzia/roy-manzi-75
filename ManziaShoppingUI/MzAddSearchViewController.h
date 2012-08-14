//
//  MzAddSearchViewController.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 8/13/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

// Tags for the Search Option UIButton views
enum SearchOptionButton {
    
    SearchOptionButtonLeft, 
    SearchOptionButtonMiddle, 
    SearchOptionButtonRight
};
typedef enum SearchOptionButton SearchOptionButton;

@interface MzAddSearchViewController : UITableViewController


// Property that can be used to access the ManagedObject context
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;

// Method called when the left searchOption button is tapped
-(IBAction)leftSearchOptionTapped:(id)sender;

//Method called when the middle searchOption button is tapped
-(IBAction)middleSearchOptionTapped:(id)sender;

//Method called when the right searchOption button is tapped
-(IBAction)rightSearchOptionTapped:(id)sender;

@end
