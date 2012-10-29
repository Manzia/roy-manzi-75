//
//  MzAppDelegate.h
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 5/30/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MzSearchCollection;

@interface MzAppDelegate : UIResponder <UIApplicationDelegate, UITabBarControllerDelegate> {
    
    // Instance variables
    UIWindow *_window;
}

@property (strong, nonatomic) IBOutlet UIWindow *window;

// App Delegate keeps a reference to a unique Device Id generated from the deviceToken
// obtained through the remote notification registration process.
@property (nonatomic, copy, readonly) NSString *uniqueDeviceId;

// Return a global instance of the MzSearchCollection that the MzSearchListViewController and
// the MzResultListViewController can share in a thread-safe way since all file access is via
// the thread-safe [NSFileManager defaultManager]
@property (nonatomic, strong, readonly) MzSearchCollection *searchCollection;

// Returns the base URL for all Product search requests
@property (nonatomic, strong, readonly) NSString *baseURL;

@end
