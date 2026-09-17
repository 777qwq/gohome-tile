#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static void GPLog(NSString *msg) {
    FILE *f = fopen("/var/mobile/gohome_probe.log", "a");
    if (!f) return;
    time_t t = time(NULL); struct tm tmv; localtime_r(&t, &tmv);
    fprintf(f, "[GP %02d:%02d:%02d] %s\n", tmv.tm_hour, tmv.tm_min, tmv.tm_sec, msg.UTF8String);
    fclose(f);
}

static void DumpClassMethods(FILE *f, Class c) {
    fprintf(f, "=== %s\n", class_getName(c));
    unsigned int mcount = 0;
    Method *methods = class_copyMethodList(c, &mcount);
    for (unsigned int j = 0; j < mcount && j < 80; j++)
        fprintf(f, "    - %s\n", sel_getName(method_getName(methods[j])));
    if (methods) free(methods);
}

%ctor {
    %init;
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
    GPLog(@"probe 0.3.1 loaded");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 1) 加载器存在性检查
        const char *loaderClasses[] = {"CCSupport", "CCSupportModule", "CCUIModuleManager", "CCUIModuleController", "CCUIModuleData", "CCUIModuleInfo", "CCUIControlCenterViewController", NULL};
        GPLog(@"loader classes:");
        for (int i = 0; loaderClasses[i]; i++) {
            Class c = objc_getClass(loaderClasses[i]);
            GPLog([NSString stringWithFormat:@"  %s = %@", loaderClasses[i], c ? @"YES" : @"nil"]);
        }
        // 2) 已安装bundle目录检查
        NSFileManager *fm = NSFileManager.defaultManager;
        for (NSString *dir in @[@"/var/jb/Library/ControlCenter/Bundles", @"/Library/ControlCenter/Bundles"]) {
            NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil];
            GPLog([NSString stringWithFormat:@"dir %@: %@", dir, items ?: @"<missing>"]);
        }
        // 3) 直接dlopen我们的bundle二进制
        void *h = dlopen("/var/jb/Library/ControlCenter/Bundles/GoHomeTileModule.bundle/GoHomeTileModule", RTLD_LAZY);
        GPLog([NSString stringWithFormat:@"dlopen gohome bundle = %@ err=%s", h ? @"OK" : @"FAIL", h ? "" : dlerror()]);
        if (h) {
            Class tile = objc_getClass("GoHomeTileModule");
            GPLog([NSString stringWithFormat:@"GoHomeTileModule class = %@", tile ? @"found" : @"nil"]);
        }
        // 4) CC模块注册机制侦察
        FILE *f = fopen("/var/mobile/gohome_recon.log", "a");
        if (f) {
            fprintf(f, "\n===== probe 0.3.1 CC recon =====\n");
            for (int i = 0; loaderClasses[i]; i++) {
                Class c = objc_getClass(loaderClasses[i]);
                if (c) DumpClassMethods(f, c);
            }
            // 含 Module 的关键类
            unsigned int count = 0;
            Class *classes = objc_copyClassList(&count);
            for (unsigned int i = 0; i < count; i++) {
                const char *nm = class_getName(classes[i]);
                if (nm && strstr(nm, "ModuleManager")) DumpClassMethods(f, classes[i]);
            }
            free(classes);
            fclose(f);
            GPLog(@"recon appended");
        }
    });
}
