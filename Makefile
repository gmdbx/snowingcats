TARGET := iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SnowingCats

SnowingCats_FILES = Tweak.xm
SnowingCats_CFLAGS = -fobjc-arc
SnowingCats_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += snowingcatsprefs

include $(THEOS_MAKE_PATH)/aggregate.mk
