TARGET := iphone:clang:15.6:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SnowingCatsPrefs

SnowingCatsPrefs_FILES = SCPRootListController.m
SnowingCatsPrefs_FRAMEWORKS = UIKit
SnowingCatsPrefs_PRIVATE_FRAMEWORKS = Preferences
SnowingCatsPrefs_INSTALL_PATH = /var/jb/Library/PreferenceBundles
SnowingCatsPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
