//
//  MzAppDelegate.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 5/30/12.
//  Copyright (c) 2012 Manzia Corporation. All rights reserved.
//

#import "MzAppDelegate.h"
#import "Logging.h"
#import "NetworkManager.h"


@interface MzAppDelegate ()

// private properties

@property (nonatomic, copy,   readwrite) NSString *taskCollectionURLString;
@property (nonatomic, retain, readwrite) MzTaskCollection *taskCollection;

@end

@implementation MzAppDelegate

@synthesize taskCollection;
@synthesize taskCollectionURLString;
@synthesize window = _window;
@synthesize tabBarController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
#pragma unused(application)
#pragma unused(launchOptions)
    assert(self.window != nil);
    
    // add the tab bar controller's current view as a subview of the window
	[self.window addSubview:tabBarController.view];
    [self.window makeKeyAndVisible];
    
    // Our TaskCollectionURL is fixed
    self.taskCollectionURLString = @"http://localhost:8080/ManziaWebServices/service/interface";
    assert([NSURL URLWithString:self.taskCollectionURLString] != nil); //check its a valid URL
    
    NSUserDefaults *userDefaults;
    
    
        
    [[QLog log] logWithFormat:@"Starting application"];
    
    // Start our TaskCollection...this executes asynchrounously
    self.taskCollection = [[MzTaskCollection alloc] initWithTasksURLString:self.taskCollectionURLString];
    assert(self.taskCollection != nil);
    [self.taskCollection applicationHasLaunched];
    
    
    // Add an observer to the network manager's networkInUse property so that we can  
    // update the application's networkActivityIndicatorVisible property.  This has 
    // the side effect of starting up the NetworkManager singleton.
    
    [[NetworkManager sharedManager] addObserver:self forKeyPath:@"networkInUse" options:NSKeyValueObservingOptionInitial context:NULL];
    
    // If the "applicationClearSetup" user default is set, clear our preferences. 
    // This provides an easy way to get back to the initial state while debugging.
    
    userDefaults = [NSUserDefaults standardUserDefaults];
    if ( [userDefaults boolForKey:@"applicationClearSetup"] ) {
        [userDefaults removeObjectForKey:@"applicationClearSetup"];
       // [userDefaults removeObjectForKey:@"galleryURLString"];
    }
         
    return YES;
}

// When the network manager's networkInUse property changes, update the application's networkActivityIndicatorVisible property accordingly.
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqual:@"networkInUse"]) {
        assert(object == [NetworkManager sharedManager]);
#pragma unused(change)
        assert(context == NULL);
        assert( [NSThread isMainThread] );
        [UIApplication sharedApplication].networkActivityIndicatorVisible = [NetworkManager sharedManager].networkInUse;
    } else if (NO) {   
        
        // Disabled because the super class does nothing useful with it.
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

							
- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
    
    [[QLog log] logWithFormat:@"application entered background"];
    
    // In case, we have updates after a TaskCollection synchronization that are still unsaved
    // we save..this will also invalidate saveTimer on the TaskCollection
    if (self.taskCollection != nil 
        && self.taskCollection.stateOfSync == TaskCollectionSyncStateStopped) {
        
        [self.taskCollection saveCollection];
    }

    
    // Stop the Task Collection synchronization task if its still running in the background
    if (application.backgroundTimeRemaining < 0.5) {
        [self.taskCollection stopCollection];
        [application endBackgroundTask:self.taskCollection.taskCollectionSync];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    
    // NOTE: MzTaskCollection already observe UIApplicationDidBecomeActiveNotification notifications
    // and start synchronization.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

@end
