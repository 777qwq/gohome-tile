export THEOS_PACKAGE_SCHEME = rootless

TARGET := iphone:clang:26.5:15.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GoHomeTile
GoHomeTile_FILES = GoHomeTile.x
GoHomeTile_CFLAGS = -fobjc-arc
GoHomeTile_FRAMEWORKS = UIKit
GoHomeTile_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
