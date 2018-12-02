//
//  DLCloudDeviceManager.h
//  Bluetooth
//
//  Created by danly on 2018/8/19.
//  Copyright © 2018年 date. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DLCentralManager.h"
#import "DLDevice.h"

@class DLCloudDeviceManager;

@interface DLCloudDeviceManager : NSObject
@property (nonatomic, strong) NSMutableDictionary<NSString*, DLDevice*> *cloudDeviceList;

+ (instancetype)sharedInstance;

// 添加设备
- (DLDevice *)addDevice:(NSString *)mac;
- (void)deleteDevice:(NSString *)mac;


//根据新发现的设备更新云端列表
- (void)updateCloudList;
// 自动连接设备
- (void)autoConnectCloudDevice;
// 注销账户时，需要断开所有连接的设备，以及删除本地保存的云端列表
- (void)deleteCloudList;

- (void)updateOfflineInfoWithDevice:(DLDevice *)device;
- (void)updateNameWithDevice:(DLDevice *)device;

@end
