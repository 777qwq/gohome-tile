#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIToggleModule.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdio.h>
#include <time.h>

static void GHLog(NSString *msg) {
    @try {
        FILE *f = fopen("/var/mobile/gohome.log", "a");
        if (!f) return;
        time_t t = time(NULL); struct tm tmv; localtime_r(&t, &tmv);
        fprintf(f, "[GH %02d:%02d:%02d] %s\n", tmv.tm_hour, tmv.tm_min, tmv.tm_sec, msg.UTF8String);
        fclose(f);
    } @catch (NSException *e) { }
}

static id SafeMsg(id obj, SEL sel) {
    if (!obj || !sel) return nil;
    @try {
        if (![obj respondsToSelector:sel]) return nil;
        return ((id(*)(id, SEL))objc_msgSend)(obj, sel);
    } @catch (NSException *e) { return nil; }
}

// 一键回主屏：模拟 home 键单击抬起（SBUIController.handleHomeButtonSinglePressUpForWindowScene:withSourceType:）
static void GoHomeNow(void) {
    @try {
        Class c = objc_getClass("SBUIController");
        if (!c) { GHLog(@"SBUIController nil"); return; }
        id ctrl = SafeMsg(c, sel_registerName("sharedInstance"));
        if (!ctrl) { GHLog(@"controller instance nil"); return; }
        // 找前台活跃的 UIWindowScene
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
        }
        if (!scene && [scenes isKindOfClass:[NSSet class]]) scene = [scenes anyObject];
        if (!scene) { GHLog(@"no scene"); return; }
        SEL homeSel = NSSelectorFromString(@"handleHomeButtonSinglePressUpForWindowScene:withSourceType:");
        if (![ctrl respondsToSelector:homeSel]) { GHLog(@"home selector missing"); return; }
        ((void(*)(id, SEL, id, id))objc_msgSend)(ctrl, homeSel, scene, nil); // withSourceType 传nil=数值0，整型/对象参数皆安全
        GHLog(@"home press dispatched");
    } @catch (NSException *e) {
        GHLog(@"go home exception caught (no crash)");
    }
}

@interface GoHomeTileModule : CCUIToggleModule
{
    BOOL _selected;
}
@end

@implementation GoHomeTileModule

+ (void)load {
    NSLog(@"[GoHomeCC] v1.0 loaded");
}

- (BOOL)isSelected {
    return _selected;
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    GHLog([NSString stringWithFormat:@"tile tapped selected=%d", selected]);
    if (selected) {
        // 延迟到磁贴动画结束后再回主屏
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            GoHomeNow();
        });
    }
    [super refreshState];
}

- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.95 green:0.55 blue:0.10 alpha:1.0];
}

- (UIImage *)iconGlyph {
    return [UIImage systemImageNamed:@"house.fill"];
}

@end
