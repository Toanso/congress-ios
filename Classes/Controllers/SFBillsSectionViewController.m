//
//  SFBillsSectionViewController.m
//  Congress
//
//  Created by Daniel Cloud on 11/30/12.
//  Copyright (c) 2012 Sunlight Foundation. All rights reserved.
//

#import "SFBillsSectionViewController.h"
#import "UIScrollView+SVInfiniteScrolling.h"
#import "SVPullToRefreshView+Congress.h"
#import "IIViewDeckController.h"
#import "SFSegmentedViewController.h"
#import "SFBillService.h"
#import "SFBill.h"
#import "SFBillsSectionView.h"
#import "SFBillsTableViewController.h"
#import "SFSearchBillsTableViewController.h"
#import "SFDateFormatterUtil.h"

@interface SFBillsSectionViewController() <IIViewDeckControllerDelegate, UIGestureRecognizerDelegate>
{
    BOOL _keyboardVisible;
    BOOL _updating;
    BOOL _shouldRestoreSearch;
    NSTimer *_searchTimer;
    SFBillsSectionView *_billsSectionView;
    SFSearchBillsTableViewController *__searchTableVC;
    SFSegmentedViewController *__segmentedVC;
    SFBillsTableViewController *__newBillsTableVC;
    SFBillsTableViewController *__activeBillsTableVC;
    UIBarButtonItem *_barbecueButton;
}

@end

@implementation SFBillsSectionViewController

static NSString * const NewBillsTableVC = @"NewBillsTableVC";
static NSString * const ActiveBillsTableVC = @"ActiveBillsTableVC";
static NSString * const SearchBillsTableVC = @"SearchBillsTableVC";

static NSString * const BillsFetchErrorMessage = @"Unable to fetch bills";

@synthesize searchBar;
@synthesize currentVC = _currentVC;

@synthesize restorationKeyboardVisible = _restorationKeyboardVisible;
@synthesize restorationSelectedSegment = _restorationSelectedSegment;
@synthesize restorationSearchQuery = _restorationSearchQuery;

- (id)init
{
    self = [super init];

    if (self) {
        [self _initialize];
        self.trackedViewName = @"Bill Section Screen";
        self.restorationIdentifier = NSStringFromClass(self.class);
        
        _shouldRestoreSearch = YES;
        
        _restorationKeyboardVisible = NO;
        _restorationSelectedSegment = nil;
        _restorationSearchQuery = nil;
   }
    return self;
}

-(void)loadView
{
    _billsSectionView.frame = [[UIScreen mainScreen] bounds];
	self.view = _billsSectionView;
    self.view.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleOverlayTouch:)];
    tapRecognizer.numberOfTapsRequired = 1;
    tapRecognizer.numberOfTouchesRequired = 1;
    tapRecognizer.delegate = self;
    [_billsSectionView.overlayView addGestureRecognizer:tapRecognizer];
    UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleOverlayTouch:)];
    panRecognizer.maximumNumberOfTouches = 1;
    panRecognizer.minimumNumberOfTouches = 1;
    panRecognizer.delegate = self;
    [_billsSectionView.overlayView addGestureRecognizer:panRecognizer];

    self.searchBar = _billsSectionView.searchBar;
    self.searchBar.delegate = self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // This needs the same buttons as SFMainDeckTableViewController
    UIBarButtonItem *leftButton = [UIBarButtonItem menuButtonWithTarget:self.viewDeckController action:@selector(toggleLeftView)];
    [leftButton setAccessibilityLabel:@"Back"];
    self.navigationItem.leftBarButtonItem = leftButton;

    self.viewDeckController.delegate = self;

    // infinite scroll with rate limit.
    __weak SFSearchBillsTableViewController *weakSearchTableVC = __searchTableVC;
    __weak SFBillsSectionViewController *weakSelf = self;

    // set up __searchTableVC infinitescroll
    [__searchTableVC.tableView addInfiniteScrollingWithActionHandler:^{
        __strong SFBillsSectionViewController *strongSelf = weakSelf;
        NSUInteger pageNum = 1 + [weakSelf.billsSearched count]/20;
        NSNumber *perPage = @20;
        if (pageNum <= 1) {
            [weakSearchTableVC.tableView.infiniteScrollingView stopAnimating];
        }
        [SSRateLimit executeBlock:^{
            if (pageNum > 1) {
                [SFBillService searchBillText:weakSelf.searchBar.text count:perPage page:[NSNumber numberWithInt:pageNum] completionBlock:^(NSArray *resultsArray)
                 {
                     if (!resultsArray) {
                         [SFMessage showErrorMessageInViewController:strongSelf withMessage:BillsFetchErrorMessage];
                     }
                     else {
                         [weakSelf.billsSearched addObjectsFromArray:resultsArray];
                         weakSearchTableVC.items = weakSelf.billsSearched;
                         [weakSearchTableVC.tableView reloadData];
                         if (([resultsArray count] == 0) || ([resultsArray count] < [perPage unsignedIntegerValue])) {
                             weakSearchTableVC.tableView.infiniteScrollingView.enabled = NO;
                         }
                         [weakSearchTableVC.tableView.pullToRefreshView setLastUpdatedNow];
                     }
                     [weakSearchTableVC.tableView.infiniteScrollingView stopAnimating];
                 }];
            }
        } name:@"__searchTableVC-InfiniteScroll" limit:2.0f];
    }];

    // set up __activeBillsTableVC pulltorefresh and infininite scroll
    __weak SFBillsTableViewController *weakActiveBillsTableVC = __activeBillsTableVC;
    [__activeBillsTableVC.tableView addPullToRefreshWithActionHandler:^{
        __strong SFBillsSectionViewController *strongSelf = weakSelf;
        BOOL didRun = [SSRateLimit executeBlock:^{
            [weakActiveBillsTableVC.tableView.infiniteScrollingView stopAnimating];
            [SFBillService recentlyActedOnBillsWithCompletionBlock:^(NSArray *resultsArray)
             {
                 if (!resultsArray) {
                     // Network or other error returns nil
                     [SFMessage showErrorMessageInViewController:strongSelf withMessage:BillsFetchErrorMessage];
                     CLS_LOG(@"Unable to load bills");
                     [weakActiveBillsTableVC.tableView.pullToRefreshView stopAnimating];
                 }
                 else if ([resultsArray count] > 0) {
                     weakSelf.activeBills = [NSMutableArray arrayWithArray:resultsArray];
                     weakActiveBillsTableVC.items = weakSelf.activeBills;                     
                     [weakActiveBillsTableVC sortItemsIntoSectionsAndReload];
                     [weakActiveBillsTableVC.tableView.pullToRefreshView stopAnimatingAndSetLastUpdatedNow];
                 }

                 [weakActiveBillsTableVC.tableView setContentOffset:CGPointMake(weakActiveBillsTableVC.tableView.contentOffset.x, 0) animated:YES];

             } excludeNewBills:YES];
        } name:@"__activeBillsTableVC-PullToRefresh" limit:5.0f];
        if (!didRun) {
            [weakActiveBillsTableVC.tableView.pullToRefreshView stopAnimating];
        }
    }];
    [__activeBillsTableVC.tableView addInfiniteScrollingWithActionHandler:^{
        __strong SFBillsSectionViewController *strongSelf = weakSelf;
        BOOL didRun = [SSRateLimit executeBlock:^{
            NSUInteger pageNum = 1 + [weakSelf.activeBills count]/20;
            [SFBillService recentlyActedOnBillsWithPage:[NSNumber numberWithInt:pageNum] completionBlock:^(NSArray *resultsArray) {
                if (!resultsArray) {
                    // Network or other error returns nil
                    [SFMessage showErrorMessageInViewController:strongSelf withMessage:BillsFetchErrorMessage];
                    CLS_LOG(@"Unable to load bills");
                }
                else if ([resultsArray count] > 0) {
                    [weakSelf.activeBills addObjectsFromArray:resultsArray];
                    weakActiveBillsTableVC.items = weakSelf.activeBills;
                    [weakActiveBillsTableVC sortItemsIntoSectionsAndReload];
                    [weakActiveBillsTableVC.tableView.pullToRefreshView setLastUpdatedNow];
                }
                [weakActiveBillsTableVC.tableView.infiniteScrollingView stopAnimating];
            } excludeNewBills:YES];
        } name:@"__activeBillsTableVC-InfiniteScroll" limit:2.0f];
        if (!didRun) {
            [weakActiveBillsTableVC.tableView.infiniteScrollingView stopAnimating];
        }
    }];

    // set up __newBillsTableVC pulltorefresh and infininite scroll
    __weak SFBillsTableViewController *weakNewBillsTableVC = __newBillsTableVC;
    [__newBillsTableVC.tableView addPullToRefreshWithActionHandler:^{
        __strong SFBillsSectionViewController *strongSelf = weakSelf;
        [weakNewBillsTableVC.tableView.infiniteScrollingView stopAnimating];
        BOOL didRun = [SSRateLimit executeBlock:^{
            [SFBillService recentlyIntroducedBillsWithCompletionBlock:^(NSArray *resultsArray)
             {
                 if (!resultsArray) {
                     // Network or other error returns nil
                     [SFMessage showErrorMessageInViewController:strongSelf withMessage:BillsFetchErrorMessage];
                     CLS_LOG(@"Unable to load bills");
                     [weakNewBillsTableVC.tableView.pullToRefreshView stopAnimating];
                 }
                 else if ([resultsArray count] > 0) {
                     weakSelf.introducedBills = [NSMutableArray arrayWithArray:resultsArray];
                     weakNewBillsTableVC.items = weakSelf.introducedBills;
                     [weakNewBillsTableVC sortItemsIntoSectionsAndReload];
                     [weakNewBillsTableVC.tableView.pullToRefreshView stopAnimatingAndSetLastUpdatedNow];
                 }

             }];
        } name:@"__newBillsTableVC-PullToRefresh" limit:5.0f];
        if (!didRun) {
            [weakNewBillsTableVC.tableView.pullToRefreshView stopAnimating];
        }
    }];
    [__newBillsTableVC.tableView addInfiniteScrollingWithActionHandler:^{
        __strong SFBillsSectionViewController *strongSelf = weakSelf;
        BOOL didRun = [SSRateLimit executeBlock:^{
            NSUInteger pageNum = 1 + [weakSelf.introducedBills count]/20;
            [SFBillService recentlyIntroducedBillsWithPage:[NSNumber numberWithInt:pageNum] completionBlock:^(NSArray *resultsArray)
             {
                 if (!resultsArray) {
                     // Network or other error returns nil
                     [SFMessage showErrorMessageInViewController:strongSelf withMessage:BillsFetchErrorMessage];
                     CLS_LOG(@"Unable to load bills");
                 }
                 else if ([resultsArray count] > 0) {
                     [weakSelf.introducedBills addObjectsFromArray:resultsArray];
                     weakNewBillsTableVC.items = weakSelf.introducedBills;
                     [weakNewBillsTableVC sortItemsIntoSectionsAndReload];
                     [weakNewBillsTableVC.tableView.pullToRefreshView setLastUpdatedNow];
                 }
                 [weakNewBillsTableVC.tableView.infiniteScrollingView stopAnimating];
             }];
        } name:@"__newBillsTableVC-InfiniteScroll" limit:2.0f];
        if (!didRun) {
            [weakNewBillsTableVC.tableView.infiniteScrollingView stopAnimating];
        }
    }];


    // Default initial table should be __newBillsTableVC
    [self displayViewController:__segmentedVC];
    [__segmentedVC displayViewForSegment:0];
    [__newBillsTableVC.tableView.pullToRefreshView setSubtitle:@"New Bills" forState:SVPullToRefreshStateAll];
    [__activeBillsTableVC.tableView.pullToRefreshView setSubtitle:@"Active Bills" forState:SVPullToRefreshStateAll];

    [__newBillsTableVC.tableView triggerPullToRefresh];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (_restorationSelectedSegment != nil) {
        [__segmentedVC displayViewForSegment:_restorationSelectedSegment];
    }
    
    if (_shouldRestoreSearch) {
        if (_restorationSearchQuery != nil && ![_restorationSearchQuery isEqualToString:@""]) {
            _billsSectionView.searchBar.text = _restorationSearchQuery;
            [self searchAndDisplayResults:_restorationSearchQuery];
            
            if (_restorationKeyboardVisible) {
                [_billsSectionView.searchBar becomeFirstResponder];
            }
            _keyboardVisible = _restorationKeyboardVisible;
        }
    }
    
    _restorationSelectedSegment = nil;
    _restorationKeyboardVisible = nil;
    _restorationSearchQuery= nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.searchBar resignFirstResponder];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)displayViewController:(id)viewController
{
    if (_currentVC) {
        [_currentVC willMoveToParentViewController:nil];
        [_currentVC removeFromParentViewController];
    }
    _currentVC = viewController;
    [self addChildViewController:_currentVC];
    if ([_currentVC isKindOfClass:[SFBillsTableViewController class]]) {
        _billsSectionView.contentView = ((SFBillsTableViewController *)_currentVC).tableView;
    }
    else
    {
        _billsSectionView.contentView = _currentVC.view;
    }
    [_currentVC didMoveToParentViewController:self];
}


#pragma mark - IIViewDeckController delegate

- (void)viewDeckController:(IIViewDeckController *)viewDeckController willOpenViewSide:(IIViewDeckSide)viewDeckSide animated:(BOOL)animated {
    [self.searchBar resignFirstResponder];
    if ([self.searchBar.text isEqualToString:@""]) {
        [self resetSearchResults];
        [self setOverlayVisible:NO animated:YES];
        [self displayViewController:__segmentedVC];
    }
}

#pragma mark - Search

- (void)searchFor:(NSString *)query withKeyboard:(BOOL)showKeyboard
{
    _shouldRestoreSearch = NO;
    
    if (query == nil) {
        [searchBar setText:@""];
        [self resetSearchResults];
    } else {
        [searchBar setText:query];
        [self searchAndDisplayResults:query];
        if (showKeyboard) {
            [self showSearchKeyboard];
        } else {
            [self dismissSearchKeyboard];
        }
    }
}

- (void)searchAfterDelay
{
    if (![_currentVC isEqual:__searchTableVC]) [self displayViewController:__searchTableVC];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.75 target:self selector:@selector(handleSearchDelayExpiry:) userInfo:nil repeats:YES];
    _searchTimer = timer;
}

-(void)handleSearchDelayExpiry:(NSTimer*)timer
{
    if (![__searchTableVC isBeingDismissed] && [__searchTableVC.parentViewController isEqual:self]) {
        [self searchAndDisplayResults:searchBar.text];
    }
    [timer invalidate];
    _searchTimer = nil;
}

-(void)searchAndDisplayResults:(NSString *)searchText
{
    [self resetSearchResults];
    if (![_currentVC isEqual:__searchTableVC]) [self displayViewController:__searchTableVC];

    NSString *normalizedText = [SFBill normalizeToCode:searchText];
    NSTextCheckingResult *result = [SFBill billCodeCheckingResult:normalizedText];
    NSLog(@"'%@' isBillCode: %@", searchText, (result ? @"YES" : @"NO"));

    if (result) {
        NSString *billType = [normalizedText substringWithRange:[result rangeAtIndex:1]];
        NSString *billNumber = [normalizedText substringWithRange:[result rangeAtIndex:2]];
        NSLog(@"billType: %@ \nbillNumber: %@", billType, billNumber);
        NSDictionary *params = @{@"bill_type":billType, @"number": billNumber, @"order": @"congress"};
        [SFBillService lookupWithParameters:params completionBlock:^(NSArray *resultsArray) {
            [self.billsSearched addObjectsFromArray:resultsArray];
            __searchTableVC.items = self.billsSearched;
            //        [__searchTableVC reloadTableView];
            [self.view layoutSubviews];
            [self setOverlayVisible:!([__searchTableVC.items count] > 0) animated:YES];
            _shouldRestoreSearch = NO;
        }];
    }
    else
    {
        [SFBillService searchBillText:searchText completionBlock:^(NSArray *resultsArray) {
            [self.billsSearched addObjectsFromArray:resultsArray];
            __searchTableVC.items = self.billsSearched;
            //        [__searchTableVC reloadTableView];
            [self.view layoutSubviews];
            [self setOverlayVisible:!([__searchTableVC.items count] > 0) animated:YES];
            _shouldRestoreSearch = NO;
        }];
    }

}

- (void)dismissSearchKeyboard
{
    _keyboardVisible = NO;
    [self.searchBar resignFirstResponder];
}

- (void)showSearchKeyboard
{
    _keyboardVisible = NO;
    [self.searchBar becomeFirstResponder];
}

- (void)resetSearchResults
{
    if ([_currentVC isEqual:__searchTableVC]) [self displayViewController:__segmentedVC];
    __searchTableVC.items = nil;
    [__searchTableVC.tableView.infiniteScrollingView stopAnimating];
    self.billsSearched = [NSMutableArray arrayWithCapacity:20];
    __searchTableVC.tableView.infiniteScrollingView.enabled = YES;
}

#pragma mark - SearchBar delegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)pSearchBar
{
    [self searchAndDisplayResults:pSearchBar.text];
    [self dismissSearchKeyboard];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if ([[searchText lowercaseString] isEqualToString:@"barbecue"] && self.navigationItem.rightBarButtonItem == nil) {
        self.navigationItem.rightBarButtonItem = _barbecueButton;
    }
    if ([searchText length] > 2) {
        if (!_searchTimer || ![_searchTimer isValid]) {
            [self searchAfterDelay];
        }
    }
    else if ([searchText length] == 0)
    {
        [self resetSearchResults];
        [self setOverlayVisible:YES animated:YES];
//        [__searchTableVC reloadTableView];
    }
    else
    {
        [self resetSearchResults];
        [self setOverlayVisible:YES animated:YES];
    }
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)pSearchBar
{
    _keyboardVisible = YES;
    if ([pSearchBar.text isEqualToString:@""]) {
        [self resetSearchResults];
        [self setOverlayVisible:YES animated:YES];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)pSearchBar
{
    [self dismissSearchKeyboard];
    pSearchBar.text = @"";
    [self resetSearchResults];
    if (![_currentVC isEqual:__segmentedVC]) [self displayViewController:__segmentedVC];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)pSearchBar
{
    if ([pSearchBar.text isEqualToString:@""]) {
        [self dismissSearchKeyboard];
        [self resetSearchResults];
    }
}

#pragma mark - Gesture handlers

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)handleOverlayTouch:(UIPanGestureRecognizer *)recognizer
{
    if ([self.searchBar isFirstResponder]) {
        [self dismissSearchKeyboard];
        if ([self.searchBar.text isEqualToString:@""])
        {
            [self resetSearchResults];
        }
        else{
            self.searchBar.text = @"";
        }
        [self displayViewController:__segmentedVC];
        [self setOverlayVisible:NO animated:YES];
    }
}

#pragma mark - SegmentedViewController notification handler

-(void)handleSegmentedViewChange:(NSNotification *)notification
{
    if ([notification.name isEqualToString:@"SegmentedViewDidChange"]) {
        // Ensure __activeBillsTableVC gets loaded.
        if ([self.activeBills count] == 0 &&[__segmentedVC.currentViewController isEqual:__activeBillsTableVC]) {
            [__activeBillsTableVC.tableView triggerPullToRefresh];
        }
    }
}

#pragma mark - SFBillSectionViewController


- (void)setOverlayVisible:(BOOL)visible animated:(BOOL)animated
{
    CGFloat visibleAlpha = 0.7f;
    if (visible)
    {
        if (animated && (_billsSectionView.overlayView.alpha != visibleAlpha) ) {
            _billsSectionView.overlayView.alpha = 0.0f;
            _billsSectionView.overlayView.hidden = NO;
            [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                _billsSectionView.overlayView.alpha = visibleAlpha;
            } completion:^(BOOL finished) {}];
        }
        else
        {
            _billsSectionView.overlayView.hidden = NO;
        }
    }
    else
    {
        if (animated) {
            [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                _billsSectionView.overlayView.alpha = 0.0f;
            } completion:^(BOOL finished) {
                _billsSectionView.overlayView.hidden = YES;
            }];
        }
        else
        {
            _billsSectionView.overlayView.hidden = YES;
        }
    }
}

#pragma mark - Private

-(void)_initialize
{
    self.title = @"Bills";
    self->_updating = NO;
    _keyboardVisible = NO;
    _searchTimer = nil;
    if (!_billsSectionView) {
        _billsSectionView = [[SFBillsSectionView alloc] initWithFrame:CGRectZero];
        _billsSectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    __searchTableVC = [[self class] newSearchBillsTableViewController];

    __newBillsTableVC = [[self class] newNewBillsTableViewController];
    // Set up blocks to generate section titles and sort items into sections
    [__newBillsTableVC setSectionTitleGenerator:lastActionAtTitleBlock sortIntoSections:lastActionAtSorterBlock
                           orderItemsInSections:nil cellForIndexPathHandler:nil];
    __activeBillsTableVC = [[self class] newActiveBillsTableViewController];
    // Set up blocks to generate section titles and sort items into sections
    [__activeBillsTableVC setSectionTitleGenerator:lastActionAtTitleBlock sortIntoSections:lastActionAtSorterBlock
                              orderItemsInSections:nil cellForIndexPathHandler:nil];
    __segmentedVC = [SFSegmentedViewController segmentedViewControllerWithChildViewControllers:@[__newBillsTableVC,__activeBillsTableVC]
                                                                                        titles:@[@"New", @"Active"]];
    
    self.introducedBills = [NSMutableArray arrayWithCapacity:20];
    self.activeBills = [NSMutableArray arrayWithCapacity:20];
    self.billsSearched = [NSMutableArray arrayWithCapacity:20];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSegmentedViewChange:) name:@"SegmentedViewDidChange" object:__segmentedVC];
    
    _barbecueButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"109-chicken"]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(barbecueIt)];
    [_barbecueButton setAccessibilityLabel:@"Barbecue"];
    [_barbecueButton setAccessibilityHint:@"Congratulations! You have unlocked directions to some of the best barbecue in the country."];

    [self displayViewController:__segmentedVC];
}

- (void)barbecueIt
{
    NSDictionary *addressDict = @{
        (NSString *) kABPersonAddressStreetKey : @"4618 South Lee Street",
        (NSString *) kABPersonAddressCityKey : @"Ayden",
        (NSString *) kABPersonAddressStateKey : @"NC",
        (NSString *) kABPersonAddressZIPKey : @"28513",
        (NSString *) kABPersonAddressCountryKey : @"US"
    };
    
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(35.461153, -77.423323);
    MKPlacemark *place = [[MKPlacemark alloc] initWithCoordinate:coord addressDictionary:addressDict];
    MKMapItem *destination = [[MKMapItem alloc] initWithPlacemark:place];
    destination.name = @"Skylight Inn BBQ";
    NSArray *items = [[NSArray alloc] initWithObjects:destination, nil];
    NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:
                             MKLaunchOptionsDirectionsModeDriving,
                             MKLaunchOptionsDirectionsModeKey, nil];
    [MKMapItem openMapsWithItems:items launchOptions:options];
}

+ (SFBillsTableViewController *)_newBillsTableVC
{
    SFBillsTableViewController *vc = [[SFBillsTableViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.restorationClass = [self class];
    return vc;
}

+ (SFBillsTableViewController *)newNewBillsTableViewController
{
    SFBillsTableViewController *vc = [[self class] _newBillsTableVC];
    vc.restorationIdentifier = NewBillsTableVC;
    return vc;
}

+ (SFBillsTableViewController *)newActiveBillsTableViewController
{
    SFBillsTableViewController *vc = [[self class] _newBillsTableVC];
    vc.restorationIdentifier = ActiveBillsTableVC;
    return vc;
}

+ (SFSearchBillsTableViewController *)newSearchBillsTableViewController
{
    SFSearchBillsTableViewController *vc = [[SFSearchBillsTableViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.restorationIdentifier = SearchBillsTableVC;
    return vc;
}


#pragma mark - UIViewControllerRestoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeInteger:[__segmentedVC currentSegmentIndex] forKey:@"selectedSegment"];
    [coder encodeObject:_billsSectionView.searchBar.text forKey:@"searchQuery"];
    [coder encodeBool:_keyboardVisible forKey:@"keyboardVisible"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    _restorationSelectedSegment = [coder decodeIntegerForKey:@"selectedSegment"];
    _restorationKeyboardVisible = [coder decodeBoolForKey:@"keyboardVisible"];
    _restorationSearchQuery = [coder decodeObjectForKey:@"searchQuery"];
}

@end
