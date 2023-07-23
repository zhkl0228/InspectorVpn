//
//  AppDelegate.m
//  InspectorVpn
//
//  Created by Banny on 2023/4/5.
//

#import "AppDelegate.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

@interface AppDelegate ()
@end

static void print_lr(char *buf, uintptr_t lr) {
    lr -= 4;

    Dl_info info;
    int success = dladdr((const void *) lr, &info);
    if(success) {
        uintptr_t offset = lr - (uintptr_t) info.dli_fbase;
        const char *name = info.dli_fname;
        const char *find = name;
        while(find) {
            const char *next = strchr(find, '/');
            if(next) {
                find = &next[1];
            } else {
                break;
            }
        }
        if(find) {
            name = find;
        }

        for (uint32_t i = 0, count = _dyld_image_count(); i < count; i++) {
            const char *image_name = _dyld_get_image_name(i);
            if(strlen(image_name) > 0 && strcmp(image_name, info.dli_fname) == 0 && strstr(info.dli_fname, "/InspectorVpn.app/")) {
                intptr_t slide = _dyld_get_image_vmaddr_slide(i);
                offset = lr - slide;
                break;
            }
        }

        sprintf(buf, "[%s]%p", name, (void *) offset);
    } else {
        sprintf(buf, "%p", (void *) lr);
    }
}

@implementation NSData (Hex)
-(NSString *) toHexString {
  NSUInteger capacity = self.length * 2;
  NSMutableString *buffer = [NSMutableString stringWithCapacity:capacity];
  const char *buf = (const char*) self.bytes;
  NSUInteger i;
  for (i=0; i<self.length; i++) {
    [buffer appendFormat:@"%02x", (buf[i] & 0xff)];
  }
  return buffer;
}
@end

@implementation NSThread (Trace)
+(NSString *) WA_backtrace {
    NSArray<NSNumber *> *callStackReturnAddresses = [NSThread callStackReturnAddresses];
    NSMutableString *str = [NSMutableString string];
    char buf[1024];
    for(NSNumber *address in callStackReturnAddresses) {
        print_lr(buf, [address unsignedLongValue]);
        [str appendFormat: @"%s\n", buf];
    }
    return str;
}
@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [application registerForRemoteNotifications];
    NSLog(@"application didFinishLaunchingWithOptions=%@", launchOptions);
    return YES;
}

- (void) application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString *backtrace = [NSThread WA_backtrace];
    NSLog(@"application didRegisterForRemoteNotificationsWithDeviceToken=%@, backtrace=\n%@", [deviceToken toHexString], backtrace);
}

- (void) application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"application didFailToRegisterForRemoteNotificationsWithError=%@", error);
}

- (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    NSString *backtrace = [NSThread WA_backtrace];
    NSLog(@"application didReceiveRemoteNotification userInfo=%@, completionHandler=%p, backtrace=\n%@", userInfo, completionHandler, backtrace);
    completionHandler(UIBackgroundFetchResultNewData);
}


@end
