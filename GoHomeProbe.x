#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static void GPLog(NSString *msg) {
    @try {
        FILE *f = fopen("/var/mobile/gohome_probe.log", "a");
        if (!f) return;
        time_t t = time(NULL); struct tm tmv; localtime_r(&t, &tmv);
        fprintf(f, "[GP %02d:%02d:%02d] %s\n", tmv.tm_hour, tmv.tm_min, tmv.tm_sec, msg.UTF8String);
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

static id SafeMsg1(id obj, SEL sel, id arg) {
    if (!obj || !sel) return nil;
    @try {
        if (![obj respondsToSelector:sel]) return nil;
        return ((id(*)(id, SEL, id))objc_msgSend)(obj, sel, arg);
    } @catch (NSException *e) { return nil; }
}

static void VerifyModule(void) {
    @try {
        // 1) 配置文件里的模块清单
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ControlCenter/ModuleConfiguration.plist"];
        NSArray *mi = d[@"module-identifiers"];
        if ([mi isKindOfClass:[NSArray class]]) {
            GPLog([NSString stringWithFormat:@"config module-identifiers count=%lu", (unsigned long)[mi count]]);
            BOOL found = NO;
            for (NSString *s in mi) {
                if ([s containsString:@"GoHome"]) { GPLog([NSString stringWithFormat:@"  FOUND in config: %@", s]); found = YES; }
            }
            if (!found) GPLog(@"  GoHome NOT in config module-identifiers");
        }
        // 2) 自建仓库实例验证（+defaultModuleDirectories 被 CCSupport hook 含第三方目录）
        Class repoClass = objc_getClass("CCSModuleRepository");
        if (!repoClass) { GPLog(@"CCSModuleRepository nil"); return; }
        id dirs = SafeMsg(repoClass, sel_registerName("defaultModuleDirectories"))
            ?: SafeMsg(repoClass, NSSelectorFromString(@"_defaultModuleDirectories"));
        GPLog([NSString stringWithFormat:@"module dirs = %@", dirs]);
        if (![dirs isKindOfClass:[NSArray class]] || [dirs count] == 0) { GPLog(@"no dirs"); return; }
        id repo = SafeMsg1([repoClass alloc], NSSelectorFromString(@"_initWithDirectoryURLs:allowedModuleIdentifiers:"), dirs);
        if (!repo) { GPLog(@"repo alloc/init failed"); return; }
        // 触发元数据更新
        SafeMsg(repo, NSSelectorFromString(@"_queue_updateAllModuleMetadata"));
        id loadable = SafeMsg(repo, sel_registerName("loadableModuleIdentifiers"));
        GPLog([NSString stringWithFormat:@"loadable count=%lu", (unsigned long)[loadable count]]);
        BOOL found = NO;
        for (NSString *s in loadable) {
            if ([s containsString:@"GoHome"]) { GPLog([NSString stringWithFormat:@"  LOADABLE: %@", s]); found = YES; }
            if ([s containsString:@"RCSpeaker"]) GPLog([NSString stringWithFormat:@"  speaker ref: %@", s]);
        }
        if (!found) GPLog(@"  GoHome NOT loadable");
        id meta = SafeMsg1(repo, NSSelectorFromString(@"moduleMetadataForModuleIdentifier:"), @"com.user.controlcenter.GoHomeTileModule");
        GPLog([NSString stringWithFormat:@"our metadata = %@", meta ? @"EXISTS" : @"nil"]);
        if (meta) {
            id fams = SafeMsg(meta, sel_registerName("supportedDeviceFamilies"));
            GPLog([NSString stringWithFormat:@"  supportedDeviceFamilies = %@", fams]);
        }
        GPLog(@"verify done");
    } @catch (NSException *e) {
        GPLog(@"verify exception caught (no crash)");
    }
}

%ctor {
    %init;
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
    GPLog(@"probe 0.3.6 loaded");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        VerifyModule();
    });
}
