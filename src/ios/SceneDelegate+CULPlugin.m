//
//  SceneDelegate+CULPlugin.m
//
//  Created for cordova-ios@8 Scene API support
//  Handles Universal Links via SceneDelegate instead of AppDelegate
//

#import "SceneDelegate+CULPlugin.h"
#import "CULPlugin.h"
#import <objc/runtime.h>
#import <Cordova/CDV.h>

/**
 *  Plugin name in config.xml
 */
static NSString *const PLUGIN_NAME = @"UniversalLinks";

@implementation CDVSceneDelegate (CULPlugin)

/*
 In cordova-ios@8, the app uses Scene API, so user activities come through SceneDelegate
 instead of AppDelegate. We need to swizzle the SceneDelegate method to handle Universal Links.
 */
+ (void)load {
    NSLog(@"[UniversalLinks] ===== LOADING UniversalLinks Category =====");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Swizzle CDVSceneDelegate directly since SceneDelegate inherits from it
        Class targetClass = [CDVSceneDelegate class];
        
        NSLog(@"[UniversalLinks] Using CDVSceneDelegate class: %@", targetClass);

        SEL originalSEL = @selector(scene:continueUserActivity:);
        SEL swizzledSEL = @selector(culPlugin_scene:continueUserActivity:);
        
        Method originalMethod = class_getInstanceMethod(targetClass, originalSEL);
        Method swizzledMethod = class_getInstanceMethod(targetClass, swizzledSEL);
        
        NSLog(@"[UniversalLinks] Original method: %@, Swizzled method: %@",
              originalMethod ? @"FOUND" : @"NOT FOUND",
              swizzledMethod ? @"FOUND" : @"NOT FOUND");
        
        if (swizzledMethod) {
            if (originalMethod) {
                // Method exists - swizzle it
                method_exchangeImplementations(originalMethod, swizzledMethod);
                NSLog(@"[UniversalLinks] Swizzled scene:continueUserActivity: in CDVSceneDelegate");
            } else {
                // Method doesn't exist - add it
                IMP swizzledIMP = method_getImplementation(swizzledMethod);
                const char *swizzledTypes = method_getTypeEncoding(swizzledMethod);
                
                BOOL didAdd = class_addMethod(targetClass, originalSEL, swizzledIMP, swizzledTypes);
                if (didAdd) {
                    NSLog(@"[UniversalLinks] Added scene:continueUserActivity: to CDVSceneDelegate");
                } else {
                    NSLog(@"[UniversalLinks]  Failed to add method");
                }
            }
            NSLog(@"[UniversalLinks] ===== UniversalLinks Setup COMPLETE =====");
        } else {
            NSLog(@"[UniversalLinks]  ERROR: Swizzled method not found");
        }
    });
}

- (void)culPlugin_scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity {
    NSLog(@"[UniversalLinks] ===== UNIVERSAL LINK DETECTED =====");
    NSLog(@"[UniversalLinks] 📱 scene:continueUserActivity: called");
    NSLog(@"[UniversalLinks] Activity Type: %@", userActivity.activityType);
    NSLog(@"[UniversalLinks] Webpage URL: %@", userActivity.webpageURL);
    
    BOOL handled = NO;
    
    // Handle Universal Links (NSUserActivityTypeBrowsingWeb) FIRST
    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] && userActivity.webpageURL != nil) {
        NSLog(@"[UniversalLinks] This IS a Universal Link!");
        NSLog(@"[UniversalLinks] URL: %@", userActivity.webpageURL);
        
        // Get the view controller from the scene
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            NSLog(@"[UniversalLinks] Scene is UIWindowScene");
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            UIWindow *window = windowScene.windows.firstObject;
            NSLog(@"[UniversalLinks] Windows count: %lu", (unsigned long)windowScene.windows.count);
            
            if (window && window.rootViewController) {
                NSLog(@"[UniversalLinks] Window and rootViewController found");
                UIViewController *rootVC = window.rootViewController;
                NSLog(@"[UniversalLinks] Root VC class: %@", NSStringFromClass([rootVC class]));
                
                // Get the Cordova view controller
                if ([rootVC isKindOfClass:[CDVViewController class]]) {
                    NSLog(@"[UniversalLinks] CDVViewController found");
                    CDVViewController *cordovaVC = (CDVViewController *)rootVC;
                    
                    // Get instance of the plugin and let it handle the userActivity object
                    CULPlugin *plugin = [cordovaVC getCommandInstance:PLUGIN_NAME];
                    if (plugin != nil) {
                        NSLog(@"[UniversalLinks] Plugin instance found, handling...");
                        handled = [plugin handleUserActivity:userActivity];
                        NSLog(@"[UniversalLinks] Plugin handled: %@", handled ? @"YES" : @"NO");
                    } else {
                        NSLog(@"[UniversalLinks] Plugin instance not found");
                    }
                } else {
                    NSLog(@"[UniversalLinks] Root VC is not CDVViewController");
                }
            } else {
                NSLog(@"[UniversalLinks] No window or rootViewController found");
            }
        } else {
            NSLog(@"[UniversalLinks]  Scene is not UIWindowScene, it's: %@", NSStringFromClass([scene class]));
        }
        
        if (handled) {
            // We handled it, don't pass to other plugins
            NSLog(@"[UniversalLinks] ===== END UNIVERSAL LINK HANDLING (handled by UniversalLinks) =====");
            return;
        }
    } else {
        NSLog(@"[UniversalLinks] Not a Universal Link");
        NSLog(@"[UniversalLinks] Expected: %@ with webpageURL", NSUserActivityTypeBrowsingWeb);
    }
    
    // Not our activity type or we didn't handle it - call through to any other swizzled implementations
    // Due to method swizzling, this actually calls what was the "original" implementation
    NSLog(@"[UniversalLinks] Passing to other handlers (calling swizzled method)...");
    [self culPlugin_scene:scene continueUserActivity:userActivity];
    
    NSLog(@"[UniversalLinks] ===== END UNIVERSAL LINK HANDLING (passed to other handler) =====");
}

@end

