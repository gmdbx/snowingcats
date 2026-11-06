TARGET := iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SnowingCatsPrefs

SnowingCatsPrefs_FILES = SCPRootListController.m
SnowingCatsPrefs_FRAMEWORKS = UIKit
SnowingCatsPrefs_PRIVATE_FRAMEWORKS = Preferences
SnowingCatsPrefs_INSTALL_PATH = /Library/PreferenceBundles
SnowingCatsPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
