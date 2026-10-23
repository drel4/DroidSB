export THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk
TWEAK_NAME = DroidSB
DroidSB_FILES = Tweak.xm $(wildcard Sources/*.m)
DroidSB_CFLAGS = -fobjc-arc -ISources
DroidSB_FRAMEWORKS = UIKit CoreGraphics CoreText QuartzCore
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-stage::
	python3 scripts/fix-abi.py "$(THEOS_STAGING_DIR)"
