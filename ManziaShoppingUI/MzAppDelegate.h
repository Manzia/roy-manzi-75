//
//  MzAppDelegate.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 5/30/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MzTaskCollection.h"

@interface MzAppDelegate : UIResponder <UIApplicationDelegate, UITabBarControllerDelegate> {
    
    // Instance variables
    UIWindow *_window;
    NSString *taskCollectionURLString;
    MzTaskCollection *taskCollection;
    UITabBarController *tabBarController;
}

@property (strong, nonatomic) IBOutlet UIWindow *window;
@property (strong, nonatomic) IBOutlet UITabBarController *tabBarController;


@end
