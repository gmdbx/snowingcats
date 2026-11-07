#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#define PREFS_PATH @"/var/jb/var/mobile/Library/Preferences/com.you.snowingcats.plist"
#define BUNDLE_PATH @"/var/jb/Library/Application Support/SnowingCats"
#define PREFS_CHANGED "com.you.snowingcats.prefschanged"

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
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREFS_PATH];
    if (prefs[@"enabled"])        scEnabled      = [prefs[@"enabled"] boolValue];
    if (prefs[@"lockscreen"])     scOnLockscreen = [prefs[@"lockscreen"] boolValue];
    if (prefs[@"springboard"])    scOnSpringboard = [prefs[@"springboard"] boolValue];
    if (prefs[@"apps"])           scOnApps       = [prefs[@"apps"] boolValue];
    if (prefs[@"count"])          scCount        = [prefs[@"count"] floatValue];
    if (prefs[@"size"])           scSize         = [prefs[@"size"] floatValue];
    if (prefs[@"speed"])          scSpeed        = [prefs[@"speed"] floatValue];
}

static UIImage *SCCatImage() {
    static UIImage *cat = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cat = [UIImage imageWithContentsOfFile:[BUNDLE_PATH stringByAppendingPathComponent:@"cat.png"]];
    });
    return cat;
}

static BOOL SCShouldShow() {
    if (!scEnabled) return NO;
    if (SCIsSpringBoard()) {
        return scLocked ? scOnLockscreen : scOnSpringboard;
    }
    return scOnApps;
}

static void SCUpdateEmitter() {
    if (!snowEmitter) return;

    snowWindow.hidden = !SCShouldShow();

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
    snowWindow.windowLevel = UIWindowLevelStatusBar + 100.0;
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
}

static void SCPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        SCLoadPrefs();
        SCUpdateEmitter();
    });
}

// Track lock screen state (SpringBoard only)
%hook SBLockScreenViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    scLocked = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        SCUpdateEmitter();
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    scLocked = NO;
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

%end

// Other apps: create our own window inside each app
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

%end

%ctor {
    // Avoid loading into system daemons / preferences app itself
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID || ![bundleID length]) return;
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
