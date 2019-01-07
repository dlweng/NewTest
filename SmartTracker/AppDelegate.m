//
//  AppDelegate.m
//  SmartTracker
//
//  Created by danlypro on 2018/11/25.
//  Copyright © 2018 danlypro. All rights reserved.
//

#import "AppDelegate.h"
#import "InCommon.h"
#import "DLCentralManager.h"
#import "InSelectionViewController.h"
#import "InControlDeviceViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // 启动图片延时: 1秒
    [NSThread sleepForTimeInterval:0.1];
    // 设置状态栏
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    
    
    // 启动蓝牙功能
    __block NSNumber *isShowAlterView = @NO;
    __block InAlertView *alertView;
    [DLCentralManager startSDKCompletion:^(DLCentralManager *manager, CBCentralManagerState state) {
        if (state != CBCentralManagerStatePoweredOn) {
            if (!isShowAlterView.boolValue) {
                isShowAlterView = @YES;
                alertView = [InAlertView showAlertWithTitle:@"Information" message:@"Enable Bluetooth to pair with the device." confirmHanler:^{
                    isShowAlterView = @NO;
                }];
            }
        }
        else {
            if (alertView) {
                // 移除并重置状态
                [alertView removeFromSuperview];
                alertView = nil;
                isShowAlterView = @NO;
            }
        }
    }];
    
    // 设置通知
    UIUserNotificationType type = UIUserNotificationTypeAlert | UIUserNotificationTypeSound;
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:type categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    InControlDeviceViewController *controlDeviceVC = [[InControlDeviceViewController alloc] init];
    UINavigationController *narVC = [[UINavigationController alloc] initWithRootViewController:controlDeviceVC];
    self.window.rootViewController = narVC;
    [self.window makeKeyAndVisible];
    // 设置导航栏格式
    [InCommon setupNavBarAppearance];
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[NSNotificationCenter defaultCenter] postNotificationName:ApplicationDidEnterBackground object:nil];
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[NSNotificationCenter defaultCenter] postNotificationName:ApplicationWillEnterForeground object:nil];
    // 清楚所有的通知
    [UIApplication sharedApplication].applicationIconBadgeNumber = 1;
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
}


- (void)applicationWillTerminate:(UIApplication *)application {
    NSLog(@"APP被杀死");
    // 杀死APP要报设备离线。 杀死设备等同于关闭蓝牙来处理
    [[NSNotificationCenter defaultCenter] postNotificationName:BluetoothPoweredOffNotification object:nil];
}

@end
