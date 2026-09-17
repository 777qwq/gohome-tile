#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIToggleModule.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static void GHLog(NSString *msg) {
    FILE *f = fopen("/var/mobile/gohome.log", "a");
    if (!f) return;
    time_t t = time(NULL); struct tm tmv; localtime_r(&t, &tmv);
    fprintf(f, "[GH %02d:%02d:%02d] %s\n", tmv.tm_hour, tmv.tm_min, tmv.tm_sec, msg.UTF8String);
    fclose(f);
}

static void DumpClassMethods(FILE *f, Class c, const char *label) {
    const char *nm = class_getName(c);
    fprintf(f, "=== %s (%s)\n", nm, label);
    unsigned int mcount = 0;
    Method *methods = class_copyMethodList(c, &mcount);
    for (unsigned int j = 0; j < mcount && j < 100; j++)
        fprintf(f, "    - %s\n", sel_getName(method_getName(methods[j])));
    if (methods) free(methods);
}

// 侦察：定位"回主屏"真实API
static void StartRecon(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        FILE *f = fopen("/var/mobile/gohome_recon.log", "w");
        if (!f) return;
        // 1) 关键类的全部方法
        const char *keys[] = {"SBUIController", "SBMainWorkspace", "SBHomeScreenViewController", "SBHomeScreenIconLayout", NULL};
        for (int k = 0; keys[k]; k++) {
            Class c = objc_getClass(keys[k]);
            if (c) DumpClassMethods(f, c, "key class");
        }
        // 2) 类名含 Home 的全部类
        unsigned int count = 0;
        Class *classes = objc_copyClassList(&count);
        for (unsigned int i = 0; i < count; i++) {
            const char *nm = class_getName(classes[i]);
            if (nm && strstr(nm, "Home") && !strstr(nm, "KeyHome")) {
                DumpClassMethods(f, classes[i], "Home-matched");
            }
        }
        free(classes);
        fclose(f);
        GHLog(@"recon dumped");
    });
}

static void GoHomeNow(void) {
    // v0.1: 仅记录（API待侦察确认后接入）
    GHLog(@"tile tapped - go home requested");
}

@interface GoHomeTileModule : CCUIToggleModule
{
    BOOL _selected;
}
@end

@implementation GoHomeTileModule

+ (void)load {
    NSLog(@"[GoHomeCC] module loaded");
}

- (BOOL)isSelected {
    return _selected;
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    GHLog([NSString stringWithFormat:@"tile selected=%d", selected]);
    GoHomeNow();
    [super refreshState];
}

- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.95 green:0.55 blue:0.10 alpha:1.0];
}

- (UIImage *)iconGlyph {
    return [UIImage systemImageNamed:@"house.fill"];
}

@end

%ctor {
    %init;
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
    GHLog(@"gohome 0.1 loaded (recon)");
    StartRecon();
}
