//
//  MzProductRankViewController.m
//  ManziaShoppingUI
//
//  Created by Roy Manzi Tumubweinee on 2/26/13.
//  Copyright (c) 2013 Manzia Corporation. All rights reserved.
//

#import "MzProductRankViewController.h"
#import "NetworkManager.h"
#import "RetryingHTTPOperation.h"
#import "MzRanksParserOperation.h"
#import "Logging.h"

@interface MzProductRankViewController ()

// Graph-related Properties
@property (nonatomic, strong) CPTBarPlot *aaplPlot;
@property (nonatomic, strong) CPTBarPlot *googPlot;
@property (nonatomic, strong) CPTBarPlot *msftPlot;
@property (nonatomic, strong) CPTPlotSpaceAnnotation *priceAnnotation;

// Network-related Properties
//@property (nonatomic, copy, readwrite) NSString *rankingURLString;
@property (nonatomic, strong, readwrite) RetryingHTTPOperation *getRankingOperation;
@property (nonatomic, strong, readwrite) MzRanksParserOperation *parserOperation;
@property (nonatomic, strong) NSArray *rankResults;     //stores the parsed RankResults as an NSArray of NSDictionary

// Properties that enable the control of the syncing process
@property (nonatomic, assign, readwrite, getter=isSynchronizing) BOOL synchronizing;
@property (nonatomic, assign, readwrite) RankingSyncState  stateOfSync;
@property (nonatomic, copy, readwrite) NSString *statusOfSync;
@property (nonatomic, copy, readwrite) NSDate *dateLastSynced;
@property (nonatomic, copy, readwrite) NSError *errorFromLastSync;
@property (nonatomic, copy, readwrite) NSDateFormatter *dateFormatter;

// Forward Declarations
-(void)initPlot;
-(void)configureGraph;
-(void)configurePlots;
-(void)configureAxes;
//-(void)hideAnnotation:(CPTGraph *)graph;

// Parser Forward Declaration
- (void)startParserOperationWithData:(NSData *)data;

@end

@implementation MzProductRankViewController

// Graph-related
@synthesize hostView;
@synthesize aaplPlot;
@synthesize googPlot;
@synthesize msftPlot;
@synthesize priceAnnotation;

// Network-related
@synthesize rankingURLString;
@synthesize getRankingOperation;
@synthesize parserOperation;
@synthesize rankResults;

// Synchronization
@synthesize synchronizing;
@synthesize stateOfSync;
@synthesize statusOfSync;
@synthesize dateLastSynced;
@synthesize errorFromLastSync;
@synthesize dateFormatter;

// Graph Constants
CGFloat const CPDBarWidth = 0.25f;
CGFloat const CPDBarInitialX = 0.25f;

// Initializer
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - ViewController Lifecycle methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Networking - Synchronization
    // rankingURLString is passed by the ViewController that pushes us on screen
    assert(self.rankingURLString != nil);
    if ([self.rankingURLString length] > 0) {
        
        // Use KVO to observe the Synchronization process
        [self addObserver:self forKeyPath:@"statusOfSync" options:NSKeyValueObservingOptionNew context:nil];
        
        // Start synchronization (this is an asynchronous NSOperation)
        [self startSynchronization:nil];
    }
    
	
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // The plot is initialized here, since the view bounds have not transformed for landscape until now
    [self initPlot];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Stop synchronizing if we are off screen.
    if (self.synchronizing) {
        [self stopSynchronization];
    }
}

-(void)viewDidUnload
{
    [super viewDidUnload];
    
    // Release properties
    self.rankingURLString = nil;
    self.rankResults = nil;
    self.getRankingOperation = nil;
    self.parserOperation = nil;
    self.statusOfSync = nil;
    self.dateLastSynced = nil;
    self.dateFormatter = nil;
    self.errorFromLastSync = nil;    
    
    // Remove observer
    [self removeObserver:self forKeyPath:@"statusOfSync"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Key Value Observing

// We get the data when synchronization completes successfully
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // if the sync succeeded we store the RankResults.
    if ([keyPath isEqualToString:@"statusOfSync"]) {
        assert([object isKindOfClass:[MzProductRankViewController class]]);
        
        if ((change != nil) && ([[change objectForKey:NSKeyValueChangeKindKey] intValue] == NSKeyValueChangeSetting)) {
            
            NSString *statusValue = [change objectForKey:NSKeyValueChangeNewKey];
            
            if ([statusValue isEqualToString:@"Update Failed"] || [statusValue isEqualToString:@"Update cancelled"] ) {
                
                // Log
                [[QLog log] logWithFormat:@"Synchronization for Product Ranking Failed/Cancelled for URL: %@", self.rankingURLString];
                                
            } else if ([statusValue hasPrefix:@"Updated:"]) {
                
                // Synchronization succeeded so we re-load our graph ##########################???????????
                
            }
        }
    }

}

#pragma mark - CPTPlotDataSource methods

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    return [[[CPDStockPriceStore sharedInstance] datesInWeek] count];
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    if ((fieldEnum == CPTBarPlotFieldBarTip) && (index < [[[CPDStockPriceStore sharedInstance] datesInWeek] count])) {
        if ([plot.identifier isEqual:CPDTickerSymbolAAPL]) {
            return [[[CPDStockPriceStore sharedInstance] weeklyPrices:CPDTickerSymbolAAPL] objectAtIndex:index];
        } else if ([plot.identifier isEqual:CPDTickerSymbolGOOG]) {
            return [[[CPDStockPriceStore sharedInstance] weeklyPrices:CPDTickerSymbolGOOG] objectAtIndex:index];
        } else if ([plot.identifier isEqual:CPDTickerSymbolMSFT]) {
            return [[[CPDStockPriceStore sharedInstance] weeklyPrices:CPDTickerSymbolMSFT] objectAtIndex:index];
        }
    }
    return [NSDecimalNumber numberWithUnsignedInteger:index];
}

/*-(CPTLayer *)dataLabelForPlot:(CPTPlot *)plot recordIndex:(NSUInteger)index
{
    return nil;
}

-(NSString *)legendTitleForPieChart:(CPTPieChart *)pieChart recordIndex:(NSUInteger)index
{
    return @"";
}*/

#pragma mark - CPTBarPlotDelegate methods

-(void)barPlot:(CPTBarPlot *)plot barWasSelectedAtRecordIndex:(NSUInteger)index
{
    // 1 - Is the plot hidden?
    if (plot.isHidden == YES) {
        return;
    }
    
    // 2 - Create style, if necessary
    static CPTMutableTextStyle *style = nil;
    if (!style) {
        style = [CPTMutableTextStyle textStyle];
        style.color= [CPTColor yellowColor];
        style.fontSize = 16.0f;
        style.fontName = @"Helvetica-Bold";
    }
    
    // 3 - Create annotation, if necessary
    NSNumber *price = [self numberForPlot:plot field:CPTBarPlotFieldBarTip recordIndex:index];
    if (!self.priceAnnotation) {
        NSNumber *x = [NSNumber numberWithInt:0];
        NSNumber *y = [NSNumber numberWithInt:0];
        NSArray *anchorPoint = [NSArray arrayWithObjects:x, y, nil];
        self.priceAnnotation = [[CPTPlotSpaceAnnotation alloc] initWithPlotSpace:plot.plotSpace anchorPlotPoint:anchorPoint];
    }
    
    // 4 - Create number formatter, if needed
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        [formatter setMaximumFractionDigits:2];
    }
    
    // 5 - Create text layer for annotation
    NSString *priceValue = [formatter stringFromNumber:price];
    CPTTextLayer *textLayer = [[CPTTextLayer alloc] initWithText:priceValue style:style];
    self.priceAnnotation.contentLayer = textLayer;
    
    // 6 - Get plot index based on identifier
    NSInteger plotIndex = 0;
    if ([plot.identifier isEqual:CPDTickerSymbolAAPL] == YES) {
        plotIndex = 0;
    } else if ([plot.identifier isEqual:CPDTickerSymbolGOOG] == YES) {
        plotIndex = 1;
    } else if ([plot.identifier isEqual:CPDTickerSymbolMSFT] == YES) {
        plotIndex = 2;
    }
    
    // 7 - Get the anchor point for annotation
    CGFloat x = index + CPDBarInitialX + (plotIndex * CPDBarWidth);
    NSNumber *anchorX = [NSNumber numberWithFloat:x];
    CGFloat y = [price floatValue] + 40.0f;
    NSNumber *anchorY = [NSNumber numberWithFloat:y];
    self.priceAnnotation.anchorPlotPoint = [NSArray arrayWithObjects:anchorX, anchorY, nil];
    
    // 8 - Add the annotation 
    [plot.graph.plotAreaFrame.plotArea addAnnotation:self.priceAnnotation];
}

#pragma mark - CPT Chart Behavior methods

-(void)initPlot
{
    self.hostView.allowPinchScaling = NO;
    [self configureGraph];
    [self configurePlots];
    [self configureAxes];
}

-(void)configureGraph
{
    // 1 - Create the graph
    CPTGraph *graph = [[CPTXYGraph alloc] initWithFrame:self.hostView.bounds];
    graph.plotAreaFrame.masksToBorder = NO;
    self.hostView.hostedGraph = graph;
    
    // 2 - Configure the graph
    [graph applyTheme:[CPTTheme themeNamed:kCPTPlainBlackTheme]];
    graph.paddingBottom = 0.0f;
    graph.paddingLeft  = 0.0f;
    graph.paddingTop    = 0.0f;
    graph.paddingRight  = 0.0f;
    
    // 3 - Set up styles
    CPTMutableTextStyle *titleStyle = [CPTMutableTextStyle textStyle];
    titleStyle.color = [CPTColor whiteColor];
    titleStyle.fontName = @"Helvetica-Bold";
    titleStyle.fontSize = 16.0f;
    
    // 4 - Set up title
    NSString *title = @"Portfolio Prices: April 23 - 27, 2012";
    graph.title = title;
    graph.titleTextStyle = titleStyle;
    graph.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    graph.titleDisplacement = CGPointMake(0.0f, -16.0f);
    
    // 5 - Set up plot space
    CGFloat xMin = 0.0f;
    CGFloat xMax = [[[CPDStockPriceStore sharedInstance] datesInWeek] count];
    CGFloat yMin = 0.0f;
    CGFloat yMax = 800.0f;  // should determine dynamically based on max price
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *) graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(xMin) length:CPTDecimalFromFloat(xMax)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromFloat(yMin) length:CPTDecimalFromFloat(yMax)];

}

-(void)configurePlots
{
    // 1 - Set up the three plots
    self.aaplPlot = [CPTBarPlot tubularBarPlotWithColor:[CPTColor redColor] horizontalBars:NO];
    self.aaplPlot.identifier = CPDTickerSymbolAAPL;
    self.googPlot = [CPTBarPlot tubularBarPlotWithColor:[CPTColor greenColor] horizontalBars:NO];
    self.googPlot.identifier = CPDTickerSymbolGOOG;
    self.msftPlot = [CPTBarPlot tubularBarPlotWithColor:[CPTColor blueColor] horizontalBars:NO];
    self.msftPlot.identifier = CPDTickerSymbolMSFT;
    
    // 2 - Set up line style
    CPTMutableLineStyle *barLineStyle = [[CPTMutableLineStyle alloc] init];
    barLineStyle.lineColor = [CPTColor lightGrayColor];
    barLineStyle.lineWidth = 0.5;
    
    // 3 - Add plots to graph
    CPTGraph *graph = self.hostView.hostedGraph;
    CGFloat barX = CPDBarInitialX;
    NSArray *plots = [NSArray arrayWithObjects:self.aaplPlot, self.googPlot, self.msftPlot, nil];
    for (CPTBarPlot *plot in plots) {
        plot.dataSource = self;
        plot.delegate = self;
        plot.barWidth = CPTDecimalFromDouble(CPDBarWidth);
        plot.barOffset = CPTDecimalFromDouble(barX);
        plot.lineStyle = barLineStyle;
        [graph addPlot:plot toPlotSpace:graph.defaultPlotSpace];
        barX += CPDBarWidth;
    }
}
-(void)configureAxes
{
    // 1 - Configure styles
    CPTMutableTextStyle *axisTitleStyle = [CPTMutableTextStyle textStyle];
    axisTitleStyle.color = [CPTColor blackColor];
    axisTitleStyle.fontName = @"Helvetica-Bold";
    axisTitleStyle.fontSize = 12.0f;
    CPTMutableLineStyle *axisLineStyle = [CPTMutableLineStyle lineStyle];
    axisLineStyle.lineWidth = 2.0f;
    axisLineStyle.lineColor = [[CPTColor whiteColor] colorWithAlphaComponent:1];
    
    // 2 - Get the graph's axis set
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *) self.hostView.hostedGraph.axisSet;
    // 3 - Configure the x-axis
    axisSet.xAxis.labelingPolicy = CPTAxisLabelingPolicyNone;
    axisSet.xAxis.title = @"Days of Week (Mon - Fri)";
    axisSet.xAxis.titleTextStyle = axisTitleStyle;
    axisSet.xAxis.titleOffset = 10.0f;
    axisSet.xAxis.axisLineStyle = axisLineStyle;
    
    // 4 - Configure the y-axis
    axisSet.yAxis.labelingPolicy = CPTAxisLabelingPolicyNone;
    axisSet.yAxis.title = @"Price";
    axisSet.yAxis.titleTextStyle = axisTitleStyle;
    axisSet.yAxis.titleOffset = 5.0f;
    axisSet.yAxis.axisLineStyle = axisLineStyle;
}

#pragma mark - Network Synchronization

/* Method to create the URLRequest, */
- (NSMutableURLRequest *)requestToGetCollectionRelativeString:(NSString *)path
{
    NSMutableURLRequest *urlRequest;
    NSURL *url;
    assert([NSThread isMainThread]);
    assert(self.rankingURLString != nil);
    urlRequest = nil;
    
    // Construct the URL.
    url = [NSURL URLWithString:self.rankingURLString];
    assert(url != nil);
    if (path != nil) {
        url = [NSURL URLWithString:path relativeToURL:url];
    }
    
    // Call down to the network manager so that it can set up its stuff
    // (notably the user agent string).
    if (url != nil) {
        urlRequest = [[NetworkManager sharedManager] requestToGetURL:url];
        assert(urlRequest != nil);
    }    
    return urlRequest;
}

/* Method that starts an HTTP GET operation to retrieve the RankResults XML file. The method has a relativePath argument whose value will be appended to the product collection's collectionURLString for the HTTP GET. 
 */
- (void)startGetOperation:(NSString *)relativePath
{
    NSMutableURLRequest *requestURL;
    
    assert(self.stateOfSync == RankingSyncStateStopped);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Start HTTP GET for Product Rankings with URL %@", self.rankingURLString];
    
    requestURL = [self requestToGetCollectionRelativeString:relativePath];
    assert(requestURL != nil);
    
    assert(self.getRankingOperation == nil);
    self.getRankingOperation = [[RetryingHTTPOperation alloc] initWithRequest:requestURL];
    assert(self.getRankingOperation != nil);
    
    [self.getRankingOperation setQueuePriority:NSOperationQueuePriorityNormal];
    self.getRankingOperation.acceptableContentTypes = [NSSet setWithObjects:@"application/xml", @"text/xml", nil];
    
    [[NetworkManager sharedManager] addNetworkManagementOperation:self.getRankingOperation finishedTarget:self action:@selector(getRankingOperationComplete:)];
    
    self.stateOfSync = RankingSyncStateGetting;
    
    // Notify observers of sync status
    //[self notifyCacheSyncStatus];
}

// Starts an operation to parse the product collection's XML when the HTTP GET
// operation completes succesfully
- (void)getRankingOperationComplete:(RetryingHTTPOperation *)operation
{
    NSError *error;
    
    assert([operation isKindOfClass:[RetryingHTTPOperation class]]);
    assert(operation == self.getRankingOperation);
    assert(self.stateOfSync == RankingSyncStateGetting);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Completed HTTP GET operation for Product Rankings with URL: %@", self.rankingURLString];
    
    error = operation.error;
    if (error != nil) {
        self.errorFromLastSync = error;
        self.stateOfSync = RankingSyncStateStopped;
    } else {
        if ([QLog log].isEnabled) {
            [[QLog log] logOption:kLogOptionNetworkData withFormat:@"Received valid XML for RankResults"];
        }
        [self startParserOperationWithData:self.getRankingOperation.responseContent];
    }
    
    self.getRankingOperation = nil;
    
    //[self notifyCacheSyncStatus];
}

- (void)startParserOperationWithData:(NSData *)data
// Starts the operation to parse the gallery's XML.
{
    assert(self.stateOfSync == RankingSyncStateGetting);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Start parse for RankResults"];
    
    assert(self.parserOperation == nil);
    self.parserOperation = [[MzRanksParserOperation alloc] initWithXMLData:data];
    assert(self.parserOperation != nil);
    
    [self.parserOperation setQueuePriority:NSOperationQueuePriorityNormal];
    
    [[NetworkManager sharedManager] addCPUOperation:self.parserOperation finishedTarget:self action:@selector(parserOperationDone:)];
    
    self.stateOfSync = RankingSyncStateParsing;
    
    //[self notifyCacheSyncStatus];
}

// Method is called when the ParserOperation completes and if successful
// stores the results in our rankResults array
- (void)parserOperationDone:(MzRanksParserOperation *)operation
{
    assert([NSThread isMainThread]);
    assert([operation isKindOfClass:[MzRanksParserOperation class]]);
    assert(operation == self.parserOperation);
    assert(self.stateOfSync == RankingSyncStateParsing);
    
    [[QLog log] logOption:kLogOptionSyncDetails withFormat:@"Parsing complete for Product Ranking"];
    
    if (operation.parseError != nil) {
        self.errorFromLastSync = operation.parseError;
        self.stateOfSync = RankingSyncStateStopped;
    } else {
        // Store the Results
        self.rankResults = [[NSArray alloc] initWithArray:operation.parseResults];
        assert(self.rankResults != nil);
        assert(self.errorFromLastSync == nil);
        self.dateLastSynced = [NSDate date];
        self.stateOfSync = RankingSyncStateStopped;
        [[QLog log] logWithFormat:@"Successfully synced Product Ranking with URL: %@", self.rankingURLString];
        
    }
    self.parserOperation = nil;    
    //[self notifyCacheSyncStatus];
}

// Register the isSyncing as a dependent key for KVO notifications
+ (NSSet *)keyPathsForValuesAffectingSynchronizing
{
    return [NSSet setWithObject:@"stateOfSync"];
}

// Getter for isSyncing property
- (BOOL)isSynchronizing
{
    return (self->stateOfSync > RankingSyncStateStopped);
}

+ (BOOL)automaticallyNotifiesObserversOfStateOfSync
{
    return NO;
}

// Setter for the stateOfSync property, this property is KVO-observable
- (void)setStateOfSync:(RankingSyncState)newValue
{
    if (newValue != self->stateOfSync) {
        BOOL    isSyncingChanged;
        
        isSyncingChanged = (self->stateOfSync > RankingSyncStateStopped) != (newValue > RankingSyncStateStopped);
        [self willChangeValueForKey:@"stateOfSync"];
        if (isSyncingChanged) {
            [self willChangeValueForKey:@"synchronizing"];
        }
        self->stateOfSync = newValue;
        if (isSyncingChanged) {
            [self didChangeValueForKey:@"synchronizing"];
        }
        [self didChangeValueForKey:@"stateOfSync"];
    }
}

// Key method that starts the synchronization process
- (void)startSynchronization:(NSString *)relativePath
{
   if ( !self.isSynchronizing ) {
        if (self.stateOfSync == RankingSyncStateStopped) {
            [[QLog log] logWithFormat:@"Start synchronization for Product Ranking with URL: %@",
             self.rankingURLString];
            assert(self.getRankingOperation == nil);
            self.errorFromLastSync = nil;
            [self startGetOperation:relativePath];
        }
    }
}

// Method that stops the synchronization process
- (void)stopSynchronization
{
    if (self.isSynchronizing) {
        if (self.getRankingOperation != nil) {
            [[NetworkManager sharedManager] cancelOperation:self.getRankingOperation];
            self.getRankingOperation = nil;
        }
        if (self.parserOperation) {
            [[NetworkManager sharedManager] cancelOperation:self.parserOperation];
            self.parserOperation = nil;
        }
        self.errorFromLastSync = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
        self.stateOfSync = RankingSyncStateStopped;
        [[QLog log] logWithFormat:@"Stopped synchronization for Product Ranking with URL: %@", self.rankingURLString];
    }
}

// Register all the dependent properties/keys (on StateOfSync property) to enable
// KVO notifications for changes in any of these dependent properties
+ (NSSet *)keyPathsForValuesAffectingStatusOfSync
{
    return [NSSet setWithObjects:@"stateOfSync", @"errorFromLastSync", @"dateFormatter", @"dateLastSynced", @"getRankingOperation.retryStateClient", nil];
}

// Override getter for the KVO-observable and User-Visible StatusOfSync property
- (NSString *)statusOfSync
{
    NSString *  syncResult;
    
    if (self.errorFromLastSync == nil) {
        switch (self.stateOfSync) {
            case RankingSyncStateStopped: {
                if (self.dateLastSynced == nil) {
                    syncResult = @"Not updated";
                } else {
                    syncResult = [NSString stringWithFormat:@"Updated: %@", [self.dateFormatter stringFromDate:self.dateLastSynced]];
                }
            } break;
            default: {
                if ( (self.getRankingOperation != nil) && (self.getRankingOperation.retryStateClient == kRetryingHTTPOperationStateWaitingToRetry) ) {
                    syncResult = @"Waiting for network";
                } else {
                    syncResult = @"Updating…";
                }
            } break;
        }
    } else {
        if ([[self.errorFromLastSync domain] isEqual:NSCocoaErrorDomain] && [self.errorFromLastSync code] == NSUserCancelledError) {
            syncResult = @"Update cancelled";
        } else {
            // At this point self.lastSyncError contains the actual error.
            // However, we ignore that and return a very generic error status.
            // Users don't understand "Connection reset by peer" anyway (-:
            syncResult = @"Update failed";
        }
    }
    return syncResult;
}

// Getter for the dateFormatter property that will change/update based on changes
// in the locale and timezone of the user - standard NSDateFormatter operations
- (NSDateFormatter *)dateFormatter
{
    if (self->dateFormatter == nil) {
        self->dateFormatter = [[NSDateFormatter alloc] init];
        assert(self->dateFormatter != nil);
        
        [self->dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [self->dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDateFormatter:) name:NSCurrentLocaleDidChangeNotification  object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDateFormatter:) name:NSSystemTimeZoneDidChangeNotification object:nil];
    }
    return self->dateFormatter;
}

// Called when either the current locale or the current time zone changes.
- (void)updateDateFormatter:(NSNotification *)note
{
#pragma unused(note)
    NSDateFormatter *localDateFormatter;
    
    localDateFormatter = self.dateFormatter;
    [self willChangeValueForKey:@"dateFormatter"];
    [localDateFormatter setLocale:[NSLocale currentLocale]];
    [localDateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    [self didChangeValueForKey:@"dateFormatter"];
}

// Turn off auto-KVO notifications for the errorFromLastSync property
+ (BOOL)automaticallyNotifiesObserversOfErrorFromLastSync
{
    return NO;
}

// Override setter in order to log error
- (void)setErrorFromLastSync:(NSError *)newError
{
    //assert([NSThread isMainThread]);
    
    if (newError != nil) {
        [[QLog log] logWithFormat:@"Error while synchronizing with URL: %@ got sync error: %@", self.rankingURLString, newError];
    }
    
    if (newError != self->errorFromLastSync) {
        [self willChangeValueForKey:@"errorFromLastSync"];
        self->errorFromLastSync = [newError copy];
        [self didChangeValueForKey:@"errorFromLastSync"];
    }
}


@end
