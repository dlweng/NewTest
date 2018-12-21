//
//  DLPeripheral.h
//  Bluetooth
//
//  Created by danly on 2018/8/18.
//  Copyright © 2018年 date. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <MapKit/MapKit.h>
#import "InCommon.h"

// 设备硬件信息对应的key值
#define ElectricKey @"Electric"
#define ChargingStateKey @"ChargingState"
#define DisconnectAlertKey @"DisconnectAlert"
#define ReconnectAlertKey @"ReconnectAlert"
#define AlertMusicKey @"AlertMusic"
#define AlertStatusKey @"AlertStatusKey"
#define PhoneAlertMusicKey @"PhoneAlertMusic"

// 设备各种动作变化通知
#define DeviceOnlineChangeNotification @"DeviceOnlineChangeNotification"
#define DeviceSearchPhoneNotification @"DeviceSearchPhoneNotification"
#define DeviceSearchDeviceAlertNotification @"DeviceSearchDeviceAlertNotification"
#define DeviceRSSIChangeNotification  @"DeviceRSSIChangeNotification"
#define DeviceGetAckFailedNotification @"DeviceGetAckFailedNotification"

@class DLDevice;
@protocol DLDeviceDelegate
// 设备信息变化通知
- (void)device:(DLDevice *)device didUpdateData:(NSDictionary *)data;
@end

// 云端设备类
@interface DLDevice : NSObject<CBPeripheralDelegate>
@property (nonatomic, weak) id<DLDeviceDelegate> delegate;
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, assign) NSInteger cloudID;
@property (nonatomic, copy) NSString *mac;
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic, strong) NSNumber *rssi;
// 最新的设备数据
@property (nonatomic, strong, readonly) NSDictionary *lastData;
@property (nonatomic, assign) BOOL online; // 在线状态
@property (nonatomic, assign, readonly) BOOL connecting;
@property (nonatomic, assign, readonly) BOOL connected; 
// 标识设备是哪种类型的设备
@property (nonatomic, assign) int type;
// 保存离线时间信息：eg：离线30秒 offlineTimeInfo = Last seen 30 second ago
@property (nonatomic, strong) NSString *offlineTimeInfo;
// 保存设备离线的准确时间：eg: 1980-01-01 00:00:01
@property (nonatomic, strong) NSString *offlineTime;

// 标志设备是否正在查找手机
@property (nonatomic, assign) BOOL isSearchPhone;
// 标志手机是否正在查找设备
@property (nonatomic, assign) BOOL isSearchDevice;
@property (nonatomic, assign) BOOL isOfflineSounding; //标志是不是有断连警报
// 标记是否正处于重连设备的状态， 设备离线倒计时重连的时候使用， 用这个来标记是否关闭后台任务
// 由于设备处于后台，蓝牙报断连之后，如果10秒内没其他操作，进程会被挂起，重连超时的时间如果超过15秒，需要在重连开始时开启后台任务，保证定时器可以被执行。这个属性用于判断是否当前所有设备都已经重连完毕，重连完毕，就可以关闭后台任务
@property (nonatomic, assign) BOOL isReconnectTimer;
@property (nonatomic, assign) BOOL firstAdd; // 刚刚添加的设备，第一次连接要去发关闭断连通知
@property (nonatomic, copy) NSString *firmware; //固件版本号

+ (instancetype)device:(CBPeripheral *)peripheral;

// 保存设备离线时的经纬度值
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
// 设置设备的经纬度值
- (void)setupCoordinate:(NSString *)gps;
// 在线设备获取的是当前手机的经纬度； 离线设备获取的是保存的经纬度
- (NSString *)getGps;

// 连接方法
- (void)connectToDevice:(void (^)(DLDevice *device, NSError *error))completion;
// 断连方法
- (void)disConnectToDevice:(void (^)(DLDevice *device, NSError *error))completion;

#pragma mark - 控制方法
- (void)write:(NSData *)data;
//激活设备
- (void)activeDevice;
// 获取硬件信息
- (void)getDeviceInfo;
// 通过手机查找防丢设备
- (void)searchDevice;
// 设置断开连接通知和重连通知
- (void)setDisconnectAlert:(BOOL)disconnectAlert reconnectAlert:(BOOL)reconnectAlert;
//警报音编码，可选 01，02，03
- (void)selecteDiconnectAlertMusic:(NSInteger)alertMusic;

// 开始查找设备定时器: 查找设备定时没接收到回复的情况下，关闭查找设备状态
- (void)startSearchDeviceTimer;
- (void)readRSSI;
- (void)stopOfflineSound; //停止离线声音
@end
