//
//  DLBluetoothDeviceManager.h
//  Bluetooth
//
//  Created by danly on 2018/8/12.
//  Copyright © 2018年 date. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "DLDevice.h"
#import "InCommon.h"

// 断开连接通知，被动断开做重连的时候使用
#define DeviceDisconnectNotification @"DeviceDisconnectNotification"

// 蓝牙断开通知，做离线处理，和打开蓝牙通知处理
#define BluetoothPoweredOffNotification @"BluetoothPoweredOffNotification"

// 保存已发现设备的类
@interface DLKnowDevice:NSObject
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) NSNumber *rssi;
@end

@class DLCentralManager;
typedef void (^CentralManagerEvent)(DLCentralManager *manager, CBCentralManagerState state);
typedef void (^DidDiscoverDeviceEvent)(DLCentralManager *manager, CBPeripheral *peripheral, NSString *mac);
typedef void (^DidEndDiscoverDeviceEvent)(DLCentralManager *manager, NSMutableDictionary<NSString *, DLKnowDevice*>* knownPeripherals);
typedef void (^DidConnectToDeviceEvent)(DLCentralManager *manager, CBPeripheral *peripheral, NSError *error);
typedef void (^DidDisConnectToDeviceEvent)(DLCentralManager *manager, CBPeripheral *peripheral, NSError *error);

@interface DLCentralManager : NSObject

@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, DLKnowDevice*>* knownPeripherals;
@property (nonatomic, assign) CBCentralManagerState state;

+ (instancetype)sharedInstance;
+ (void)startSDKCompletion:(CentralManagerEvent)completion;
- (void)startScanDeviceWithTimeout:(int)timeout discoverEvent:(DidDiscoverDeviceEvent)discoverEvent didEndDiscoverDeviceEvent:(DidEndDiscoverDeviceEvent)endDiscoverEvent;
- (void)connectToDevice: (CBPeripheral *)peripheral completion:(DidConnectToDeviceEvent)completion;
- (void)disConnectToDevice: (CBPeripheral *)peripheral completion:(DidDisConnectToDeviceEvent)completion;

@end
