#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#define PREFS_PATH @"/var/jb/var/mobile/Library/Preferences/com.you.snowingcats.plist"
#define BUNDLE_PATH @"/var/jb/Library/Application Support/SnowingCats"
#define PREFS_CHANGED "com.you.snowingcats.prefschanged"

@interface SCHelper : NSObject
+ (void)pollWindowState;
@end

static BOOL scEnabled = YES;
static BOOL scOnSpringboard = YES;
static BOOL scOnLockscreen = YES;
static BOOL scOnApps = NO;
static CGFloat scCount = 20.0;
static CGFloat scSize = 24.0;
static CGFloat scSpeed = 1.0;

static BOOL scLocked = NO;

static UIWindow *snowWindow = nil;
static CAEmitterLayer *snowEmitter = nil;

static BOOL SCIsSpringBoard() {
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

static void SCLoadPrefs() {
    // PreferenceLoader may write to either location depending on setup
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREFS_PATH];
    if (!prefs) {
        prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.you.snowingcats.plist"];
    }
    if (!prefs) return;

    // Only override defaults when key explicitly exists in plist
    // PSSwitchCell defaults are YES for enabled/springboard/lockscreen, NO for apps
    if (prefs[@"enabled"])     scEnabled      = [prefs[@"enabled"] boolValue];
    else                        scEnabled      = YES;

    if (prefs[@"lockscreen"])  scOnLockscreen = [prefs[@"lockscreen"] boolValue];
    else                        scOnLockscreen = YES;

    if (prefs[@"springboard"]) scOnSpringboard = [prefs[@"springboard"] boolValue];
    else                        scOnSpringboard = YES;

    if (prefs[@"apps"])        scOnApps       = [prefs[@"apps"] boolValue];
    else                        scOnApps       = NO;

    if (prefs[@"count"])       scCount        = [prefs[@"count"] floatValue];
    else                        scCount        = 20.0;

    if (prefs[@"size"])        scSize         = [prefs[@"size"] floatValue];
    else                        scSize         = 24.0;

    if (prefs[@"speed"])       scSpeed        = [prefs[@"speed"] floatValue];
    else                        scSpeed        = 1.0;
}

static UIImage *SCCatImage() {
    static UIImage *cat = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cat = [UIImage imageWithContentsOfFile:[BUNDLE_PATH stringByAppendingPathComponent:@"cat.png"]];
    });
    return cat;
}

static BOOL SCIsLocked() {
    return scLocked;
}

static NSString *scFrontmostApp = nil;
static BOOL scOnHomeScreen = NO;

static BOOL SCShouldShow() {
    if (!scEnabled) return NO;
    if (SCIsSpringBoard()) {
        // Lock screen showing? use lockscreen toggle
        if (SCIsLocked()) return scOnLockscreen;
        // App open? hide
        if (SCAppIsFrontmost()) return NO;
        // Otherwise only when Home Screen is visible
        return scOnSpringboard;
    }
    return scOnApps;
}

// Check if an app is frontmost via SBWorkspace's activeApplication
static BOOL SCAppIsFrontmost() {
    return scFrontmostApp != nil && [scFrontmostApp length] > 0;
}

static void SCSetupSnow();

@interface SCHelper : NSObject
@end

@implementation SCHelper

+ (void)pollWindowState {
    if (!snowWindow) return;

    // Check if any other window is above ours in SpringBoard
    // If app is open, app's window lives in app process, not here.
    // In SpringBoard: check if springboard's own icon window is key
    UIApplication *app = [UIApplication sharedApplication];
    NSArray *windows = app.windows;

    BOOL appWindowVisible = NO;
    for (UIWindow *w in windows) {
        if ([w isKindOfClass:[snowWindow class]] && w != snowWindow && !w.isHidden && w.windowLevel > snowWindow.windowLevel) {
            appWindowVisible = YES;
            break;
        }
    }

    // In SpringBoard: if a system window (like app switcher) is above, our snow hides behind it - fine.
    // The main check: our show/hide logic runs in SCShouldShow via hooks.
    // This timer just re-applies preference changes periodically (cheap)
    SCUpdateEmitter();
}

@end

static void SCUpdateEmitter() {
    if (!snowWindow) return;
    BOOL shouldShow = SCShouldShow();
    NSLog(@"[SnowingCats] bundle=%@ locked=%d homeScreen=%d prefs(en=%d, sb=%d, ls=%d, apps=%d) -> show=%d",
        [[NSBundle mainBundle] bundleIdentifier], scLocked, scOnHomeScreen,
        scEnabled, scOnSpringboard, scOnLockscreen, scOnApps, shouldShow);

    snowWindow.hidden = !shouldShow;

    CAEmitterCell *cell = [CAEmitterCell emitterCell];
    cell.contents = (id)SCCatImage().CGImage;
    cell.birthRate = scCount / 10.0;
    cell.lifetime = 20.0;
    cell.velocity = 40.0 * scSpeed;
    cell.velocityRange = 20.0 * scSpeed;
    cell.yAcceleration = 30.0 * scSpeed;
    cell.xAcceleration = 5.0;
    cell.emissionLongitude = M_PI;
    cell.emissionRange = M_PI_4;
    cell.scale = scSize / MAX(SCCatImage().size.width, 1.0);
    cell.scaleRange = cell.scale * 0.5;
    cell.spin = 0.5;
    cell.spinRange = 1.0;
    cell.alphaRange = 0.4;
    cell.alphaSpeed = 0.0;

    snowEmitter.emitterCells = @[cell];
}

static void SCSetupSnow() {
    if (snowWindow) return;

    snowWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    // Below status bar so it doesn't cover apps' status bars
    snowWindow.windowLevel = UIWindowLevelStatusBar - 1.0;
    snowWindow.userInteractionEnabled = NO;
    snowWindow.backgroundColor = [UIColor clearColor];
    snowWindow.hidden = YES;

    UIView *container = [[UIView alloc] initWithFrame:snowWindow.bounds];
    container.backgroundColor = [UIColor clearColor];
    snowWindow.rootViewController = [UIViewController new];
    snowWindow.rootViewController.view = container;

    snowEmitter = [CAEmitterLayer layer];
    snowEmitter.emitterPosition = CGPointMake(container.bounds.size.width / 2.0, -20.0);
    snowEmitter.emitterSize = CGSizeMake(container.bounds.size.width, 1.0);
    snowEmitter.emitterShape = kCAEmitterLayerLine;
    [container.layer addSublayer:snowEmitter];

    SCUpdateEmitter();

    // Fallback polling: re-apply state periodically
    [NSTimer scheduledTimerWithTimeInterval:0.5
        target:[SCHelper class]
        selector:@selector(pollWindowState)
        userInfo:nil
        repeats:YES];
}

static void SCPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        SCLoadPrefs();
        SCUpdateEmitter();
    });
}

// Track lock screen state (CSCoverSheetViewController on iOS 15)
%hook CSCoverSheetViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    scLocked = YES;
    NSLog(@"[SnowingCats] lock screen appeared, locked=YES");
    dispatch_async(dispatch_get_main_queue(), ^{
        SCUpdateEmitter();
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    scLocked = NO;
    NSLog(@"[SnowingCats] lock screen disappeared, locked=NO");
    dispatch_async(dispatch_get_main_queue(), ^{
        SCUpdateEmitter();
    });
}

%end

// Show SB window only while Home Screen is on screen
%hook SBHomeScreenViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    scOnHomeScreen = YES;
    NSLog(@"[SnowingCats] home screen appeared");
    dispatch_async(dispatch_get_main_queue(), ^{
        SCUpdateEmitter();
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    scOnHomeScreen = NO;
    NSLog(@"[SnowingCats] home screen disappeared");
    dispatch_async(dispatch_get_main_queue(), ^{
        SCUpdateEmitter();
    });
}

%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;

    SCLoadPrefs();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SCSetupSnow();
    });
}

- (void)frontmostApplicationWithIdentifierChanged:(id)notification {
    %orig;
    NSDictionary *info = [notification userInfo];
    id appId = info[@"applicationIdentifier"];
    scFrontmostApp = appId;
    NSLog(@"[SnowingCats] frontmost app changed: %@", appId);
    dispatch_async(dispatch_get_main_queue(), ^{
        SCUpdateEmitter();
    });
}

%end

// App launched / deactivated (direct workspace hook)
%hook SBWorkspace

- (void)noteFrontmostApplicationChanged:(id)arg1 {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        SCUpdateEmitter();
    });
}

%end

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL ret = %orig;

    if (!SCIsSpringBoard()) {
        SCLoadPrefs();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SCSetupSnow();
        });
    }
    return ret;
}

- (void)applicationDidBecomeActive {
    %orig;

    if (!SCIsSpringBoard()) {
        SCLoadPrefs();
        SCUpdateEmitter();
    }
}

- (void)applicationWillResignActive {
    %orig;

    if (!SCIsSpringBoard()) {
        SCUpdateEmitter();
    }
}

%end

%ctor {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID || ![bundleID length]) return;
    // Load into SpringBoard and all third-party apps, but skip Apple apps (except SpringBoard)
    if ([bundleID hasPrefix:@"com.apple."] && !SCIsSpringBoard()) return;

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        SCPrefsChanged,
        CFSTR(PREFS_CHANGED),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
}
