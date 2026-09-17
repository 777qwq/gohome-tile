#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ControlCenterUIKit/CCUIToggleModule.h>
#import <objc/runtime.h>
#import <objc/message.h>
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

static void DumpClassMethods(FILE *f, Class c) {
    fprintf(f, "=== %s\n", class_getName(c));
    unsigned int mcount = 0;
    Method *methods = class_copyMethodList(c, &mcount);
    for (unsigned int j = 0; j < mcount && j < 100; j++)
        fprintf(f, "    - %s\n", sel_getName(method_getName(methods[j])));
    if (methods) free(methods);
}

// 侦察：定位"回主屏"真实API
static void StartRecon(void) {
    FILE *f = fopen("/var/mobile/gohome_recon.log", "w");
    if (!f) return;
    const char *keys[] = {"SBUIController", "SBMainWorkspace", "SBHomeScreenViewController", "SBIconController", NULL};
    for (int k = 0; keys[k]; k++) {
        Class c = objc_getClass(keys[k]);
        if (c) DumpClassMethods(f, c);
    }
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    for (unsigned int i = 0; i < count; i++) {
        const char *nm = class_getName(classes[i]);
        if (nm && strstr(nm, "Home") && !strstr(nm, "KeyHome")) {
            DumpClassMethods(f, classes[i]);
        }
    }
    free(classes);
    fclose(f);
    GHLog(@"recon dumped");
}

@interface GoHomeTileModule : CCUIToggleModule
{
    BOOL _selected;
}
@end

@implementation GoHomeTileModule

+ (void)load {
    // bundle加载即侦察（SpringBoard进程内）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        GHLog(@"GoHomeTileModule loaded (0.2.0 recon)");
        StartRecon();
    });
}

- (BOOL)isSelected {
    return _selected;
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    GHLog([NSString stringWithFormat:@"tile tapped selected=%d", selected]);
    // v0.2: 回主屏API待侦察接入，当前仅记录
    [super refreshState];
}

- (UIColor *)selectedColor {
    return [UIColor colorWithRed:0.95 green:0.55 blue:0.10 alpha:1.0];
}

- (UIImage *)iconGlyph {
    return [UIImage systemImageNamed:@"house.fill"];
}

@end
