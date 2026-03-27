//
//  SceneDelegate+CULPlugin.h
//
//  Created for cordova-ios@8 Scene API support
//  Handles Universal Links via SceneDelegate instead of AppDelegate
//

#import <UIKit/UIKit.h>
#import <Cordova/CDVSceneDelegate.h>

NS_ASSUME_NONNULL_BEGIN

@interface CDVSceneDelegate (CULPlugin)

/**
 *  Swizzled handler for scene:willConnectToSession:options:.
 *  Called on COLD LAUNCH — saves the Universal Link URL to NSUserDefaults before the
 *  Cordova WebView is ready. CULPlugin.pluginInitialize reads it once the WebView loads.
 */
- (void)culPlugin_scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions;

/**
 *  Swizzled handler for scene:continueUserActivity:.
 *  Called when the app is already running (foreground/background) and the user taps a
 *  Universal Link. Dispatches the URL directly to the CULPlugin instance.
 */
- (void)culPlugin_scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity;

@end

NS_ASSUME_NONNULL_END
