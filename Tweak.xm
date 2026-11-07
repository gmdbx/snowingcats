#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>

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
static BOOL scAppOpen = NO;

static UIWindow *snowWindow = nil;
static CAEmitterLayer *snowEmitter = nil;

static BOOL SCIsSpringBoard() {
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

static void SCLoadPrefs() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREFS_PATH];
    if (!prefs) {
        prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.you.snowingcats.plist"];
    }
    if (!prefs) return;

    scEnabled      = prefs[@"enabled"]     ? [prefs[@"enabled"] boolValue]      : YES;
    scOnLockscreen = prefs[@"lockscreen"]  ? [prefs[@"lockscreen"] boolValue]  : YES;
    scOnSpringboard= prefs[@"springboard"] ? [prefs[@"springboard"] boolValue] : YES;
    scOnApps       = prefs[@"apps"]        ? [prefs[@"apps"] boolValue]        : NO;
    scCount        = prefs[@"count"]       ? [prefs[@"count"] floatValue]      : 20.0;
    scSize         = prefs[@"size"]        ? [prefs[@"size"] floatValue]       : 24.0;
    scSpeed        = prefs[@"speed"]       ? [prefs[@"speed"] floatValue]      : 1.0;
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
        if (scLocked) return scOnLockscreen;
        if (scAppOpen) return NO;
        return scOnSpringboard;
    }
    return scOnApps;
}

static void SCUpdateEmitter() {
    if (!snowWindow) return;

    BOOL shouldShow = SCShouldShow();
    NSLog(@"[SnowingCats] %@ locked=%d appOpen=%d (en=%d sb=%d ls=%d apps=%d) show=%d",
        [[NSBundle mainBundle] bundleIdentifier], scLocked, scAppOpen,
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
    snowWindow.windowLevel = UIWindowLevelStatusBar + 1.0;
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

// Lock state via Darwin notification (posted by system on lock/unlock)
static void SCLockStateChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    // Notification itself doesn't carry state, check via notify_get_state
    int state = 0;
    uint64_t lockState = 0;
    int token;
    if (notify_register_check("com.apple.springboard.lockstate", &token) == NOTIFY_STATUS_OK) {
        uint64_t val = 0;
        if (notify_get_state(token, &val) == NOTIFY_STATUS_OK) {
            state = (int)val;
        }
        notify_cancel(token);
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        // lockstate: 1 = locked
        scLocked = (state != 0);
        NSLog(@"[SnowingCats] lockstate changed: %d", scLocked);
        SCUpdateEmitter();
    });
}

static void SCPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        SCLoadPrefs();
        SCUpdateEmitter();
    });
}

// App open/close: Darwin notification from system (workspace changes)
static void SCAppChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        SCUpdateEmitter();
    });
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;

    SCLoadPrefs();
    SCLoadPrefs();

    // Check initial lock state
    uint64_t val = 0;
    int token;
    if (notify_register_check("com.apple.springboard.lockstate", &token) == NOTIFY_STATUS_OK) {
        if (notify_get_state(token, &val) == NOTIFY_STATUS_OK) {
            scLocked = (val != 0);
        }
        notify_cancel(token);
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SCSetupSnow();
    });
}

// Track app open/close via bulletin/notification of frontmost app
- (void)applicationActivated:(id)app {
    %orig;
    scAppOpen = YES;
    NSLog(@"[SnowingCats] app activated (SB)");
    dispatch_async(dispatch_get_main_queue(), ^{
        SCUpdateEmitter();
    });
}

- (void)applicationDeactivated:(id)app {
    %orig;
    scAppOpen = NO;
    NSLog(@"[SnowingCats] app deactivated (SB)");
    dispatch_async(dispatch_get_main_queue(), ^{
        SCUpdateEmitter();
    });
}

%end

// Other apps: create our own window
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
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID || ![bundleID length]) return;
    if ([bundleID hasPrefix:@"com.apple."] && !SCIsSpringBoard()) return;

    // Preferences reload
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        SCPrefsChanged,
        CFSTR(PREFS_CHANGED),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );

    // Lock state changes (system notification, works on all processes)
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        SCLockStateChanged,
        CFSTR("com.apple.springboard.lockstate"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
}
