export THEOS_PACKAGE_SCHEME = rootless

TARGET := iphone:clang:26.5:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = GoHomeTileModule

GoHomeTileModule_FILES = GoHomeTileModule.x
GoHomeTileModule_FRAMEWORKS = UIKit
GoHomeTileModule_INSTALL_PATH = /Library/ControlCenter/Bundles
GoHomeTileModule_LDFLAGS = -undefined dynamic_lookup

TWEAK_NAME = GoHomeProbe
GoHomeProbe_FILES = GoHomeProbe.x
GoHomeProbe_FRAMEWORKS = UIKit
GoHomeProbe_LDFLAGS = -undefined dynamic_lookup
GoHomeProbe_CFLAGS = -fobjc-arc
GoHomeTileModule_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
