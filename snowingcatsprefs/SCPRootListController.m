#import "SCPRootListController.h"

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.you.snowingcats.plist"
#define PREFS_CHANGED "com.you.snowingcats.prefschanged"

@implementation SCPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.you.snowingcats.prefschanged"),
        NULL, NULL, YES
    );
}

@end
