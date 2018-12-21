//
//  STCommon.h
//  SmartTracker
//
//  Created by danlypro on 2018/11/25.
//  Copyright © 2018 danlypro. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>
#import "MBProgressHUD.h"
#import "DLDevice.h"

#define common [InCommon sharedInstance]
#define ApplicationWillEnterForeground @"ApplicationWillEnterForeground"
#define ApplicationDidEnterBackground @"ApplicationDidEnterBackground"


/**
 界面显示类型
 */
typedef NS_ENUM(NSInteger, InDeviceType) {
    
    /**
     未知设备类型
     */
    InDeviceNone = 0,
    
    /**
     钱包套
     */
    InDeviceSmartCardHolder = 1,
    
    /**
     卡片
     */
    InDeviceSmartCard = 2,
    
    /**
     所有设备类型
     */
    InDeviceAll = 3,
};

NS_ASSUME_NONNULL_BEGIN

@interface InCommon : NSObject

@property (nonatomic, assign) InDeviceType deviceType; //保存此次查找的设备类型
+ (instancetype)sharedInstance;
+ (void)setupNavBarAppearance;
+ (UIColor *)uiBackgroundColor;
+ (void)setUpWhiteStyleButton:(UIButton *)btn;
+ (void)setUpBlackStyleButton:(UIButton *)btn;

// 从16进制字符串获取到10进制数值
- (NSInteger)getIntValueByHex:(NSString *)getStr;

- (InDeviceType)getDeviceType:(CBPeripheral *)peripheral;

//标识是否支持定位功能
@property (nonatomic, assign) BOOL isLocation;
@property (nonatomic, assign) CLLocationCoordinate2D currentLocation;

- (NSString *)getCurrentGps;
- (BOOL)isOpensLocation;

#pragma mark - date
//获取当前的时间 1980-01-01 00:00:01
- (NSString *)getCurrentTime;
// 字符串转换为日期  字符串格式：1980-01-01 00:00:01
- (NSDate *)dateFromStr:(NSString *)str;
// 字符串转换为日期
- (NSString *)dateStrFromDate:(NSDate *)date;
//  入参是NSDate类型
- (int)compareOneDate:(NSDate *)oneDate withAnotherDate:(NSDate *)anotherDate;
//  入参是NSString类型  oneDateStr距离现在比anotherDateStr距离现在近，返回-1
- (int)compareOneDateStr:(NSString *)oneDateStr withAnotherDateStr:(NSString *)anotherDateStr;
- (NSDateComponents *)differentWithDate:(NSString *)expireDateStr;

// 发送本地通知
- (void)sendLocalNotification:(NSString *)message;
+ (BOOL)isOpenNotification;


- (NSString *)getImageName:(NSNumber *)rssi;
+ (BOOL)isIPhoneX; // 返回是否是刘海屏
- (void)goToAPPSetupView;

//后台任务
- (BOOL)beginBackgroundTask;
- (void)endBackgrondTask;

@property (nonatomic, assign) BOOL isSharkAnimationing;
- (void)startSharkAnimation;
- (void)stopSharkAnimation;

@end

NS_ASSUME_NONNULL_END

@interface NSDictionary (GetValue)

- (NSString *)stringValueForKey:(NSString *)key defaultValue:(NSString *)defaultValue;
- (NSNumber *)numberValueForKey:(NSString *)key defaultValue:(NSNumber *)defaultValue;
- (NSInteger)integerValueForKey:(NSString *)key defaultValue:(NSInteger)defaultValue;
- (BOOL)boolValueForKey:(NSString *)key defaultValue:(BOOL)defaultValue;
- (double)doubleValueForKey:(NSString *)key defaultValue:(double)defaultValue;
- (NSArray *)arrayValueForKey:(NSString *)key defaultValue:(NSArray *)defaultValue;
- (NSDictionary *)dictValueForKey:(NSString *)key defaultValue:(NSDictionary *)defaultValue;

@end

// 显示加载圈
@interface InAlertTool : NSObject
+ (void)showHUDAddedTo:(UIView *)view animated:(BOOL)animated;
+ (void)showHUDAddedTo:(UIView *)view tips:(NSString *)tips tag:(NSInteger)tag animated:(BOOL)animated;
+ (void)hideHUDForView:(UIView *)view tag:(NSInteger)tag;
@end

// 显示交互提示框
typedef void (^confirmHanler)(void);
@interface InAlertView : UIView
+ (InAlertView *)showAlertWithTitle:(NSString *)title message:(NSString *)message confirmHanler:(confirmHanler)confirmHanler;
+ (InAlertView *)showAlertWithMessage:(NSString *)message confirmHanler:(confirmHanler)confirmHanler cancleHanler:(confirmHanler)cancleHanler;
@end

