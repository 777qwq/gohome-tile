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

static void DumpMethods(FILE *f, Class c) {
    if (!c) return;
    @try {
        fprintf(f, "=== %s\n", class_getName(c));
        unsigned int mcount = 0;
        Method *methods = class_copyMethodList(c, &mcount);
        for (unsigned int j = 0; j < mcount && j < 120; j++)
            fprintf(f, "    - %s\n", sel_getName(method_getName(methods[j])));
        if (methods) free(methods);
    } @catch (NSException *e) { }
}

static void DeepRecon(void) {
    @try {
        // 1) 关键类方法清单
        FILE *f = fopen("/var/mobile/gohome_probe.log", "a");
        if (!f) return;
        fprintf(f, "===== 0.3.5 deep recon =====\n");
        const char *keys[] = {"CCUIModuleInstanceManager", "CCSModuleRepository", "CCSModuleMetadata", "CCSModuleSettingsProvider", "CCUIModuleManager", NULL};
        for (int i = 0; keys[i]; i++) {
            Class c = objc_getClass(keys[i]);
            if (c) DumpMethods(f, c);
            else fprintf(f, "=== %s (nil)\n", keys[i]);
        }
        // 2) ModuleManager 后缀类
        unsigned int count = 0;
        Class *classes = objc_copyClassList(&count);
        for (unsigned int i = 0; i < count; i++) {
            const char *nm = class_getName(classes[i]);
            if (nm && (strstr(nm, "ModuleRepository") || strstr(nm, "ModuleInstanceManager"))) {
                DumpMethods(f, classes[i]);
            }
        }
        free(classes);
        fclose(f);
        // 3) 模块配置文件
        for (NSString *p in @[@"/var/mobile/Library/ControlCenter/ModuleConfiguration_CCSupport.plist",
                              @"/var/mobile/Library/ControlCenter/ModuleConfiguration.plist"]) {
            @try {
                NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
                if (d) {
                    NSArray *known = d[@"knownModuleIdentifiers"] ?: d[@"knownModuleIdentifiers3"];
                    GPLog([NSString stringWithFormat:@"%@ keys=%@", [p lastPathComponent], [d allKeys]]);
                    if ([known isKindOfClass:[NSArray class]]) {
                        GPLog([NSString stringWithFormat:@"  known count=%lu", (unsigned long)[known count]]);
                        BOOL found = NO;
                        for (NSString *s in known) {
                            if ([s containsString:@"GoHome"]) { GPLog([NSString stringWithFormat:@"  FOUND: %@", s]); found = YES; }
                        }
                        if (!found) GPLog(@"  GoHome not in known");
                    }
                } else {
                    GPLog([NSString stringWithFormat:@"%@ missing/empty", [p lastPathComponent]]);
                }
            } @catch (NSException *e) { }
        }
        GPLog(@"deep recon done");
    } @catch (NSException *e) {
        GPLog(@"deep recon exception caught");
    }
}

%ctor {
    %init;
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
    GPLog(@"probe 0.3.5 loaded");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        DeepRecon();
    });
}
