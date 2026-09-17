#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIToggleModule.h>
#import <objc/runtime.h>
#import <objc/message.h>

static id SafeMsg(id obj, SEL sel) {
    if (!obj || !sel) return nil;
    @try {
        if (![obj respondsToSelector:sel]) return nil;
        return ((id(*)(id, SEL))objc_msgSend)(obj, sel);
    } @catch (NSException *e) { return nil; }
}

// 一键回主屏：模拟 home 键单击抬起
static void GoHomeNow(void) {
    @try {
        Class c = objc_getClass("SBUIController");
        if (!c) return;
        id ctrl = SafeMsg(c, sel_registerName("sharedInstance"));
        if (!ctrl) return;
        id app = SafeMsg(objc_getClass("UIApplication"), sel_registerName("sharedApplication"));
        id scenes = SafeMsg(app, sel_registerName("connectedScenes"));
        id scene = nil;
        if ([scenes isKindOfClass:[NSSet class]]) {
            for (id s in scenes) {
                @try {
                    SEL st = sel_registerName("activationState");
                    if ([s respondsToSelector:st] && (((NSInteger(*)(id, SEL))objc_msgSend)(s, st)) == 0 /*foregroundActive*/) {
                        scene = s; break;
                    }
                } @catch (NSException *e) { }
            }
            if (!scene) scene = [scenes anyObject];
        }
        if (!scene) return;
        SEL homeSel = NSSelectorFromString(@"handleHomeButtonSinglePressUpForWindowScene:withSourceType:");
        if (![ctrl respondsToSelector:homeSel]) return;
        ((void(*)(id, SEL, id, id))objc_msgSend)(ctrl, homeSel, scene, nil);
    } @catch (NSException *e) { }
}

@interface GoHomeTileModule : CCUIToggleModule
{
    BOOL _selected;
}
@end

@implementation GoHomeTileModule

- (BOOL)isSelected {
    return _selected;
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    if (selected) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            GoHomeNow();
        });
    }
    [super refreshState];
}

- (UIColor *)selectedColor {
    return [UIColor clearColor];
}

- (UIImage *)iconGlyph {
    return [UIImage systemImageNamed:@"house.fill"];
}

@end
