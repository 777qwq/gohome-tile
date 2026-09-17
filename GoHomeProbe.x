#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
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

// 读取活的CCSModuleRepository，列出全部已发现模块
static void DumpRepository(void) {
    Class mgrClass = objc_getClass("CCUIModuleInstanceManager");
    if (!mgrClass) { GPLog(@"CCUIModuleInstanceManager nil"); return; }
    id mgr = ((id(*)(id, SEL))objc_msgSend)(mgrClass, sel_registerName("sharedInstance"));
    if (!mgr) { GPLog(@"sharedInstance nil"); return; }
    id repo = ((id(*)(id, SEL))objc_msgSend)(mgr, sel_registerName("repository"))
        ?: ((id(*)(id, SEL, NSString *))objc_msgSend)(mgr, sel_registerName("valueForKey:"), @"_repository");
    if (!repo) { GPLog(@"repository nil"); return; }
    GPLog(@"repository class ok");
    // 全部metadata
    id metas = ((id(*)(id, SEL))objc_msgSend)(repo, sel_registerName("allModuleMetadata"));
    if (!metas) metas = ((id(*)(id, SEL, NSString *))objc_msgSend)(repo, sel_registerName("valueForKey:"), @"_allModuleMetadata");
    if (!metas) { GPLog(@"allModuleMetadata nil"); return; }
    GPLog([NSString stringWithFormat:@"metadata count=%lu", (unsigned long)[metas count]]);
    for (id m in metas) {
        id ident = ((id(*)(id, SEL))objc_msgSend)(m, sel_registerName("moduleIdentifier"));
        id url = ((id(*)(id, SEL))objc_msgSend)(m, sel_registerName("moduleBundleURL"));
        GPLog([NSString stringWithFormat:@"  module: %@ @ %@", ident, url]);
    }
}

%ctor {
    %init;
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
    GPLog(@"probe 0.3.2 loaded");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        GPLog(@"--- pass1 (8s) ---");
        DumpRepository();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        GPLog(@"--- pass2 (30s, 打开控制中心后) ---");
        DumpRepository();
    });
}
