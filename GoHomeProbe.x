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

static void DumpRepository(void) {
    @try {
        Class mgrClass = objc_getClass("CCUIModuleInstanceManager");
        if (!mgrClass) { GPLog(@"CCUIModuleInstanceManager nil"); return; }
        id mgr = SafeMsg(mgrClass, sel_registerName("sharedInstance"));
        if (!mgr) { GPLog(@"sharedInstance nil"); return; }
        id repo = SafeMsg(mgr, sel_registerName("repository"));
        if (!repo) repo = SafeMsg(mgr, NSSelectorFromString(@"_repository"));
        if (!repo) { GPLog(@"repository nil"); return; }
        id metas = SafeMsg(repo, sel_registerName("allModuleMetadata"));
        if (!metas) metas = SafeMsg(repo, NSSelectorFromString(@"_allModuleMetadata"));
        if (![metas isKindOfClass:[NSArray class]]) { GPLog(@"metas not array"); return; }
        GPLog([NSString stringWithFormat:@"metadata count=%lu", (unsigned long)[metas count]]);
        for (id m in metas) {
            @try {
                id ident = SafeMsg(m, sel_registerName("moduleIdentifier"));
                id url = SafeMsg(m, sel_registerName("moduleBundleURL"));
                GPLog([NSString stringWithFormat:@"  module: %@ @ %@", ident, url]);
            } @catch (NSException *e) { }
        }
    } @catch (NSException *e) {
        GPLog(@"DumpRepository exception caught (no crash)");
    }
}

%ctor {
    %init;
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
    GPLog(@"probe 0.3.4 loaded (bulletproof)");
    // 后台队列执行，绝不占用主线程
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        GPLog(@"--- pass1 (10s) ---");
        DumpRepository();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(35.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        GPLog(@"--- pass2 (35s) ---");
        DumpRepository();
    });
}
