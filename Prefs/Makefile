export THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = DroidSBPrefs
DroidSBPrefs_FILES = DSBRootListController.m
DroidSBPrefs_FRAMEWORKS = UIKit
DroidSBPrefs_PRIVATE_FRAMEWORKS = Preferences
DroidSBPrefs_INSTALL_PATH = /Library/PreferenceBundles
DroidSBPrefs_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/bundle.mk
