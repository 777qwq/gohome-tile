export THEOS_PACKAGE_SCHEME = rootless

TARGET := iphone:clang:26.5:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = GoHomeTileModule

GoHomeTileModule_FILES = GoHomeTileModule.x
GoHomeTileModule_FRAMEWORKS = UIKit
GoHomeTileModule_INSTALL_PATH = /Library/ControlCenter/Bundles
GoHomeTileModule_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
