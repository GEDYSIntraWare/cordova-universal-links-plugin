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

- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity;

@end

NS_ASSUME_NONNULL_END

