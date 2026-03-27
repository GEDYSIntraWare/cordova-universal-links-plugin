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

/**
 *  Tracks whether scene:continueUserActivity: was swizzled (exchange) vs. added.
 *  When added (not swizzled), the fallback call must be skipped to avoid infinite recursion.
 */
static BOOL sContinueUserActivityWasSwizzled = NO;

/**
 *  Tracks whether scene:willConnectToSession:options: was swizzled (exchange) vs. added.
 *  When added (not swizzled), the fallback call must be skipped to avoid infinite recursion.
 */
static BOOL sWillConnectWasSwizzled = NO;

@implementation CDVSceneDelegate (CULPlugin)

/*
 In cordova-ios@8, the app uses Scene API, so user activities come through SceneDelegate
 instead of AppDelegate. We need to swizzle the SceneDelegate methods to handle Universal Links.

 Two methods are swizzled:
 1. scene:willConnectToSession:options: — called on COLD LAUNCH; the Universal Link URL
    is available in connectionOptions.userActivities. We save it to NSUserDefaults here
    because the Cordova WebView is not ready yet.
 2. scene:continueUserActivity: — called when the app is already running (foreground/background).
    We dispatch the URL directly to the plugin instance.
 */
+ (void)load {
    NSLog(@"[UniversalLinks] ===== LOADING UniversalLinks Category =====");
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class targetClass = [CDVSceneDelegate class];
        NSLog(@"[UniversalLinks] Using CDVSceneDelegate class: %@", targetClass);

        // ── Swizzle 1: scene:continueUserActivity: (app already running) ──────────────────────
        {
            SEL originalSEL = @selector(scene:continueUserActivity:);
            SEL swizzledSEL = @selector(culPlugin_scene:continueUserActivity:);

            Method originalMethod = class_getInstanceMethod(targetClass, originalSEL);
            Method swizzledMethod = class_getInstanceMethod(targetClass, swizzledSEL);

            NSLog(@"[UniversalLinks] continueUserActivity — Original: %@, Swizzled: %@",
                  originalMethod ? @"FOUND" : @"NOT FOUND",
                  swizzledMethod ? @"FOUND" : @"NOT FOUND");

            if (swizzledMethod) {
                if (originalMethod) {
                    method_exchangeImplementations(originalMethod, swizzledMethod);
                    sContinueUserActivityWasSwizzled = YES;
                    NSLog(@"[UniversalLinks] Swizzled scene:continueUserActivity: in CDVSceneDelegate");
                } else {
                    IMP swizzledIMP = method_getImplementation(swizzledMethod);
                    const char *swizzledTypes = method_getTypeEncoding(swizzledMethod);
                    BOOL didAdd = class_addMethod(targetClass, originalSEL, swizzledIMP, swizzledTypes);
                    // sContinueUserActivityWasSwizzled stays NO — fallback call must be skipped
                    NSLog(@"[UniversalLinks] Added scene:continueUserActivity: to CDVSceneDelegate: %@",
                          didAdd ? @"SUCCESS" : @"FAILED");
                }
            } else {
                NSLog(@"[UniversalLinks] ERROR: culPlugin_scene:continueUserActivity: not found");
            }
        }

        // ── Swizzle 2: scene:willConnectToSession:options: (cold launch) ─────────────────────
        {
            SEL originalSEL = @selector(scene:willConnectToSession:options:);
            SEL swizzledSEL = @selector(culPlugin_scene:willConnectToSession:options:);

            Method originalMethod = class_getInstanceMethod(targetClass, originalSEL);
            Method swizzledMethod = class_getInstanceMethod(targetClass, swizzledSEL);

            NSLog(@"[UniversalLinks] willConnectToSession — Original: %@, Swizzled: %@",
                  originalMethod ? @"FOUND" : @"NOT FOUND",
                  swizzledMethod ? @"FOUND" : @"NOT FOUND");

            if (swizzledMethod) {
                if (originalMethod) {
                    method_exchangeImplementations(originalMethod, swizzledMethod);
                    sWillConnectWasSwizzled = YES;
                    NSLog(@"[UniversalLinks] Swizzled scene:willConnectToSession:options: in CDVSceneDelegate");
                } else {
                    IMP swizzledIMP = method_getImplementation(swizzledMethod);
                    const char *swizzledTypes = method_getTypeEncoding(swizzledMethod);
                    BOOL didAdd = class_addMethod(targetClass, originalSEL, swizzledIMP, swizzledTypes);
                    // sWillConnectWasSwizzled stays NO — fallback call must be skipped
                    NSLog(@"[UniversalLinks] Added scene:willConnectToSession:options: to CDVSceneDelegate: %@",
                          didAdd ? @"SUCCESS" : @"FAILED");
                }
            } else {
                NSLog(@"[UniversalLinks] ERROR: culPlugin_scene:willConnectToSession:options: not found");
            }
        }

        NSLog(@"[UniversalLinks] ===== UniversalLinks Setup COMPLETE =====");
    });
}

// ── Handler: cold launch via scene:willConnectToSession:options: ──────────────────────────────
//
// On cold launch, iOS delivers the Universal Link URL through connectionOptions.userActivities.
// The Cordova WebView is NOT ready at this point, so we cannot access the plugin instance.
// Instead, we save the URL to NSUserDefaults. CULPlugin.pluginInitialize will read it later
// once the WebView has finished loading.
//
- (void)culPlugin_scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {

    NSLog(@"[UniversalLinks] ===== scene:willConnectToSession:options: called (cold launch check) =====");

    // Check connectionOptions.userActivities for a Universal Link
    for (NSUserActivity *activity in connectionOptions.userActivities) {
        NSLog(@"[UniversalLinks] Cold launch activity type: %@", activity.activityType);
        if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]
            && activity.webpageURL != nil) {
            NSLog(@"[UniversalLinks] Cold launch Universal Link found: %@", activity.webpageURL);
            // Save URL to NSUserDefaults so pluginInitialize can pick it up once WebView is ready
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setURL:activity.webpageURL forKey:@"CULTmpURL"];
            [defaults synchronize];
            NSLog(@"[UniversalLinks] Cold launch URL saved to NSUserDefaults");
            break;
        }
    }

    // Always call through to the original implementation so Cordova can set up the WebView.
    // Guard against infinite recursion: only call through if the method was swizzled (exchanged),
    // not merely added. When added, this selector IS our implementation — calling it recurses.
    if (sWillConnectWasSwizzled) {
        NSLog(@"[UniversalLinks] Calling original scene:willConnectToSession:options:");
        [self culPlugin_scene:scene willConnectToSession:session options:connectionOptions];
    } else {
        NSLog(@"[UniversalLinks] scene:willConnectToSession:options: was added (not swizzled) — skipping fallback to avoid recursion");
    }

    NSLog(@"[UniversalLinks] ===== END scene:willConnectToSession:options: =====");
}

// ── Handler: app already running via scene:continueUserActivity: ──────────────────────────────
//
// Called when the app is in the foreground or background and the user taps a Universal Link.
// The Cordova WebView is ready, so we can access the plugin instance directly.
//
- (void)culPlugin_scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity {
    NSLog(@"[UniversalLinks] ===== UNIVERSAL LINK DETECTED (scene:continueUserActivity:) =====");
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
                        NSLog(@"[UniversalLinks] Plugin instance not found — saving to NSUserDefaults as fallback");
                        // Fallback: save to NSUserDefaults so pluginInitialize can pick it up
                        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                        [defaults setURL:userActivity.webpageURL forKey:@"CULTmpURL"];
                        [defaults synchronize];
                        handled = YES; // Prevent passing to other handlers
                    }
                } else {
                    NSLog(@"[UniversalLinks] Root VC is not CDVViewController");
                }
            } else {
                NSLog(@"[UniversalLinks] No window or rootViewController found");
            }
        } else {
            NSLog(@"[UniversalLinks] Scene is not UIWindowScene, it's: %@", NSStringFromClass([scene class]));
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

    // Not our activity type or we didn't handle it — call through to any other handlers.
    // Guard against infinite recursion: only call through if the method was swizzled (exchanged),
    // not merely added. When added, this selector IS our implementation — calling it recurses.
    if (sContinueUserActivityWasSwizzled) {
        NSLog(@"[UniversalLinks] Passing to other handlers (calling original via swizzle)...");
        [self culPlugin_scene:scene continueUserActivity:userActivity];
    } else {
        NSLog(@"[UniversalLinks] scene:continueUserActivity: was added (not swizzled) — skipping fallback to avoid recursion");
    }

    NSLog(@"[UniversalLinks] ===== END UNIVERSAL LINK HANDLING (passed to other handler) =====");
}

@end
