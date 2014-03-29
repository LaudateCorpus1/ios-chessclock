//
//  CHChessClockViewController.m
//  Chess.com
//
//  Created by Pedro Bolaños on 10/22/12.
//  Copyright (c) 2012 psbt. All rights reserved.
//

#import "CHChessClockViewController.h"
#import "CHChessClock.h"
#import "CHChessClockSettings.h"
#import "CHChessClockTimeControlStageManager.h"
#import "CHChessClockSettingsTableViewController.h"
#import "CHChessClockSettingsManager.h"
#import "CHTimePiece.h"
#import "CHTimePieceView.h"

#import "CHUtil.h"
#import "CHSoundPlayer.h"

//------------------------------------------------------------------------------
#pragma mark - Private methods declarations
//------------------------------------------------------------------------------
@interface CHChessClockViewController()
<CHChessClockDelegate,
UIActionSheetDelegate,
CHChessClockSettingsTableViewControllerDelegate>

@property (strong, nonatomic) IBOutlet CHTimePieceView *playerOneTimePieceView;
@property (strong, nonatomic) IBOutlet CHTimePieceView *playerTwoTimePieceView;

@property (weak, nonatomic) IBOutlet UIButton *resetButton;
@property (weak, nonatomic) IBOutlet UIButton *pauseButton;
@property (weak, nonatomic) IBOutlet UIButton *settingsButton;

@property (retain, nonatomic) CHChessClock* chessClock;
@property (retain, nonatomic) CHChessClockSettingsManager* settingsManager;


// Constraints
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *firstTimerTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *firstTimerHeightConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *secondTimerLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *secondTimerBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *secondTimerHeightConstraint;


@property (weak, nonatomic) IBOutlet NSLayoutConstraint *settingsButtonLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *settingsButtonTopConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *pauseButtonTopConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *resetButtonTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *resetButtonTopConstraint;

@end

//------------------------------------------------------------------------------
#pragma mark - CHChessClockViewController implementation
//------------------------------------------------------------------------------
@implementation CHChessClockViewController

static const float CHShowTenthsTime = 10.0f;

#pragma mark - Rotation Constraints

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration
{
    [self updateConstraintConstantsToInterfaceOrientation:toInterfaceOrientation];
}

- (void)updateConstraintConstantsToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    BOOL isiPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    
     BOOL isLandscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
    
    if (!isiPad) {
        self.firstTimerHeightConstraint.constant = isLandscape ? 150.0f : IS_SCREEN_4_INCHES ? 204.0f : 170.0f;
        self.firstTimerTrailingConstraint.constant = isLandscape ? IS_SCREEN_4_INCHES ? 292.0f : 258.0f : 20.0f;
        
        self.secondTimerLeadingConstraint.constant = isLandscape ? IS_SCREEN_4_INCHES ? 292.0f : 258.0f : 20.0f;
        self.secondTimerBottomConstraint.constant = isLandscape ? 20.0f : IS_SCREEN_4_INCHES ? 344.0f : 286.0f;
        self.secondTimerHeightConstraint.constant = isLandscape ? 150.0f : IS_SCREEN_4_INCHES ? 204.0f : 170.0f;
        
        self.settingsButtonTopConstraint.constant =
        self.pauseButtonTopConstraint.constant =
        self.resetButtonTopConstraint.constant = isLandscape ? 36.0f : IS_SCREEN_4_INCHES ? 246.0f : 204.0f;
        
        self.settingsButtonLeadingConstraint.constant =
        self.resetButtonTrailingConstraint.constant = isLandscape ? 63.0f :
        20.0f;
    } else {
        self.firstTimerHeightConstraint.constant = isLandscape ? 383.0f : 380.0f;
        self.firstTimerTrailingConstraint.constant = isLandscape ? 522.0f : 20.0f;
        
        self.secondTimerLeadingConstraint.constant = isLandscape ? 522.0f : 20.0f;
        self.secondTimerBottomConstraint.constant = isLandscape ? 20.0f : 624.0f;
        self.secondTimerHeightConstraint.constant = isLandscape ? 383.0f : 380.0f;
        
        self.settingsButtonTopConstraint.constant =
        self.pauseButtonTopConstraint.constant =
        self.resetButtonTopConstraint.constant = isLandscape ? 120.0f : 450.0f;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self disableIdleTimer:NO];
    [self.chessClock cleanup];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self registerToApplicationNotification:UIApplicationDidEnterBackgroundNotification];
    [self registerToApplicationNotification:UIApplicationWillResignActiveNotification];
    
    self.title = NSLocalizedString(@"Clock", nil);
    
    BOOL isiPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    CGFloat fontSize = isiPad ? 82.0f : 46.0f;
    UIFont *customFont = [UIFont fontWithName:@"ChessGlyph-Regular" size:fontSize];
    
    self.settingsButton.titleLabel.font = customFont;
    self.resetButton.titleLabel.font = customFont;
    self.pauseButton.titleLabel.font = customFont;
    
    // Set Clock
    self.chessClock = [[CHChessClock alloc] initWithSettings:self.settingsManager.currentTimeControl
                                                 andDelegate:self];
    
    [self resetClock];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateConstraintConstantsToInterfaceOrientation:self.interfaceOrientation];
    
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

//------------------------------------------------------------------------------
#pragma mark - Lazy loading
//------------------------------------------------------------------------------

- (CHChessClockSettingsManager *)settingsManager
{
    if (!_settingsManager) {
        _settingsManager = [[CHChessClockSettingsManager alloc] initWithUserName:@"settings"];
    }
    return _settingsManager;
}

//------------------------------------------------------------------------------
#pragma mark - Private methods definitions
//------------------------------------------------------------------------------
- (void)registerToApplicationNotification:(NSString*)notificationName
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationNotificationReceived)
                                                 name:notificationName
                                               object:nil];
}

- (void)applicationNotificationReceived
{
    // Just in case the notification is posted on a thread that's not the main one
    [self performSelectorOnMainThread:@selector(pauseClock) withObject:nil waitUntilDone:NO];
}

- (CHTimePieceView *)timePieceViewWithId:(NSUInteger)timePieceId
{
    return (CHTimePieceView *)[self.view viewWithTag:timePieceId];
}

- (void)resetTimeStageDots
{
    NSUInteger stageCount = [self.chessClock.settings.stageManager stageCount];
    [self.playerOneTimePieceView setTimeControlStageDotCount:stageCount];
    [self.playerTwoTimePieceView setTimeControlStageDotCount:stageCount];
}


- (void)pauseClock
{
    if (!self.chessClock.paused) {
        [self pauseTapped];
    }
}

- (void)resetClock
{
    [self.chessClock reset];
    [self.playerOneTimePieceView unhighlightAndActivate:YES];
    [self.playerTwoTimePieceView unhighlightAndActivate:YES];
}

- (void)disableIdleTimer:(BOOL)disable
{
    [[UIApplication sharedApplication] setIdleTimerDisabled:disable];
}

//------------------------------------------------------------------------------
#pragma mark - IBAction methods
//------------------------------------------------------------------------------
- (IBAction)timePieceTouched:(UIButton *)sender
{
    NSUInteger selectedTimePieceId = sender.superview.tag;
    
    if (!self.chessClock.paused) {
        if (![UIApplication sharedApplication].idleTimerDisabled) {
            [self disableIdleTimer:YES];
        }
        
        [self setPauseButtonEnabled:YES];
    
        CHTimePieceView *selectedTimePieceView = [self timePieceViewWithId:selectedTimePieceId];
        [selectedTimePieceView unhighlightAndActivate:NO];
    } else {
        [self.chessClock togglePause];
        [self disableIdleTimer:!self.chessClock.paused];
        [self setPauseButtonEnabled:YES];
    }
    
    [self.chessClock touchedTimePieceWithId:selectedTimePieceId];
    
    if (selectedTimePieceId == self.playerOneTimePieceView.tag) {
        [self.playerTwoTimePieceView highlight];
        [self.playerOneTimePieceView unhighlightAndActivate:NO];
        [CHSoundPlayer playSwitch1Sound];
    }
    else if (selectedTimePieceId == self.playerTwoTimePieceView.tag) {
        [self.playerOneTimePieceView highlight];
        [self.playerTwoTimePieceView unhighlightAndActivate:NO];
        [CHSoundPlayer playSwitch2Sound];
    }
}

- (IBAction)settingsTapped
{
    [self pauseClock];
 
    NSString *nibName = [CHUtil nibNameWithBaseName:@"CHChessClockSettingsView"];
    CHChessClockSettingsTableViewController *settingsViewController =
    [[CHChessClockSettingsTableViewController alloc] initWithNibName:nibName
                                                              bundle:nil];
    settingsViewController.settingsManager = self.settingsManager;
    settingsViewController.delegate = self;
    [self.navigationController pushViewController:settingsViewController
                                         animated:YES];
}

- (IBAction)resetTapped
{
    [self pauseClock];

    UIActionSheet* actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                               destructiveButtonTitle:NSLocalizedString(@"Reset", nil)
                                                    otherButtonTitles:nil, nil];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        CGRect bounds = self.resetButton.bounds;
    
        [actionSheet showFromRect:bounds
                           inView:self.resetButton
                         animated:YES];
    }
    else {
        [actionSheet showInView:self.view];
    }
}

- (IBAction)pauseTapped
{
    if ([self.chessClock isActive]) {
        [self.chessClock togglePause];
        [self disableIdleTimer:!self.chessClock.paused];
        [self setPauseButtonEnabled:NO];
        
        // Unhighlight piece
        [self.playerOneTimePieceView unhighlightAndActivate:YES];
        [self.playerTwoTimePieceView unhighlightAndActivate:YES];
    }
}

- (void)setPauseButtonEnabled:(BOOL)enabled
{
    NSString *title = enabled ? @"K" : @"";
    [self.pauseButton setTitle:title forState:UIControlStateNormal];
    [self.pauseButton setTitle:title forState:UIControlStateHighlighted];
    self.pauseButton.userInteractionEnabled = enabled;
    
}

//------------------------------------------------------------------------------
#pragma mark - CHChessClockSettingsTableViewControllerDelegate methods
//------------------------------------------------------------------------------
- (void)settingsTableViewController:(id)settingsTableViewController
                  didUpdateSettings:(CHChessClockSettings *)settings
{
    self.settingsManager.currentTimeControl = settings;
}

- (void)settingsTableViewControllerDidStartClock:(id)settingsTableViewController
{
    self.chessClock.settings = self.settingsManager.currentTimeControl;
    [self resetClock];
}

//------------------------------------------------------------------------------
#pragma mark - CHChessClockDelegate methods
//------------------------------------------------------------------------------
- (void)chessClock:(CHChessClock*)chessClock availableTimeUpdatedForTimePiece:(CHTimePiece*)timePiece
{
    CHTimePieceView *timePieceView = [self timePieceViewWithId:timePiece.timePieceId];
    NSTimeInterval timePieceAvailableTime = timePiece.availableTime;
    BOOL showTenths = timePieceAvailableTime < CHShowTenthsTime;
    timePieceView.availableTimeLabel.text = [CHUtil formatTime:timePieceAvailableTime showTenths:showTenths];
}

- (void)chessClock:(CHChessClock*)chessClock movesCountUpdatedForTimePiece:(CHTimePiece*)timePiece
{
    CHTimePieceView *timePieceView = [self timePieceViewWithId:timePiece.timePieceId];

    NSString* movesText = NSLocalizedString(@"Moves", nil);
    movesText = [movesText stringByAppendingFormat:@": %ld", (long)timePiece.movesCount];
    timePieceView.movesCountLabel.text = movesText;
}

- (void)chessClock:(CHChessClock*)chessClock stageUpdatedForTimePiece:(CHTimePiece*)timePiece
{
    if (timePiece.stageIndex == 1) {
        [self resetTimeStageDots];
    }
    else {
        CHTimePieceView *timePieceView = [self timePieceViewWithId:[timePiece timePieceId]];
            [timePieceView updateTimeControlStage:timePiece.stageIndex];
    }
}

- (void)chessClockTimeEnded:(CHChessClock*)chessClock withLastActiveTimePiece:(CHTimePiece *)timePiece
{
    
    if (self.playerOneTimePieceView.tag == timePiece.timePieceId) {
        [self.playerOneTimePieceView timeEnded];
    }
    else {
        [self.playerOneTimePieceView unhighlightAndActivate:NO];
    }
    
    
    
    if (self.playerTwoTimePieceView.tag == timePiece.timePieceId) {
        [self.playerTwoTimePieceView timeEnded];
    }
    else {
        [self.playerTwoTimePieceView unhighlightAndActivate:NO];
    }
    
    
    [CHSoundPlayer playEndSound];
    [self disableIdleTimer:NO];
}

//------------------------------------------------------------------------------
#pragma mark - UIActionSheetDelegate methods
//------------------------------------------------------------------------------
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        [self resetClock];
    }
}

@end
