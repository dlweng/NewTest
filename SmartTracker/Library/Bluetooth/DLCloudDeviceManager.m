//
//  DLCloudDeviceManager.m
//  Bluetooth
//
//  Created by danly on 2018/8/19.
//  Copyright © 2018年 date. All rights reserved.
//

#import "DLCloudDeviceManager.h"
#import "InCommon.h"


static DLCloudDeviceManager *instance = nil;
@interface DLCloudDeviceManager() {
    NSTimer *_getDeviceInfoTimer;
    NSTimer *_readRSSITimer; //所有设备要统一读RSSI值，所以，放到这里来做
}

@property (nonatomic, weak) DLCentralManager *centralManager;

@end

@implementation DLCloudDeviceManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.centralManager = [DLCentralManager sharedInstance];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self getCloudDeviceList];
        // 在初始化云端管理对象30秒之后，每10分钟获取一次设备的状态
        _getDeviceInfoTimer = [NSTimer timerWithTimeInterval:600 target:self selector:@selector(autoGetDeviceInfo) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_getDeviceInfoTimer forMode:NSRunLoopCommonModes];
        [_getDeviceInfoTimer setFireDate:[NSDate distantFuture]];
        
        __weak typeof(NSTimer *) weakTimer = _getDeviceInfoTimer;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakTimer setFireDate:[NSDate distantPast]];
        });
        
        // 初始化1秒扫描一次RSSI的定时器
        _readRSSITimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(getDevicesRSSI) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_readRSSITimer forMode:NSRunLoopCommonModes];
        [_readRSSITimer setFireDate:[NSDate distantPast]];
    }
    return self;
}

- (DLDevice *)addDevice:(NSString *)mac {
    if (self.cloudDeviceList.count >= 8) {
        return nil;
    }
    // 添加设备
    DLKnowDevice *knowDevice = [[DLCentralManager sharedInstance].knownPeripherals objectForKey:mac];
    CBPeripheral *peripheral = knowDevice.peripheral;
    NSString *peripheralName = peripheral.name;
    if (peripheralName.length == 0 || [peripheralName isEqualToString:@"Lily"] || [peripheralName isEqualToString:@"Innway Card"] || [peripheralName isEqualToString:@"Smart Card Holder"]) {
        peripheralName = @"Smart Card Holder";
    }
    // 添加设备时，将当前的时间和位置作为离线时间和位置上传
    NSString *gps = [common getCurrentGps];
    NSString *offlineTime = [common getCurrentTime];
    // 创建对象
    DLDevice *newDevice = [DLDevice device:peripheral];
    newDevice.type = [common getDeviceType:peripheral];
    newDevice.mac = mac;
    newDevice.deviceName = peripheralName;
    newDevice.offlineTime = offlineTime;
    [newDevice setupCoordinate:gps];
    [self addDeviceByCloudList:newDevice];
    [self.cloudDeviceList setValue:newDevice forKey:newDevice.mac];
    // 自动连接设备
    [newDevice connectToDevice:nil];
    return newDevice;
}

- (void)deleteDevice:(NSString *)mac {
    NSLog(@"删除设备mac：%@", mac);
    // 1.删除设备
    // 2.断开连接
    DLDevice *device = [self.cloudDeviceList objectForKey:mac];
    [self removeDeviceByCloudList:device];
    [self.cloudDeviceList removeObjectForKey:mac];
    [device disConnectToDevice:nil]; // 默认断开连接都会成功
    device.online = NO;
}

//根据新发现的设备更新云端列表
- (void)updateCloudList {
    for (NSString *mac in self.cloudDeviceList.allKeys) {
        DLDevice *device = self.cloudDeviceList[mac];
        DLKnowDevice *knowDevice = [self.centralManager.knownPeripherals objectForKey:mac];
        if (knowDevice) { //在更新列表的时候，只当存在发现列表才去更新
            CBPeripheral *peripheral = knowDevice.peripheral;
            device.peripheral = peripheral;
        }
    }
    [self autoConnectCloudDevice];
}

// 自动连接云端的设备
- (void)autoConnectCloudDevice {
    for (NSString *mac in self.cloudDeviceList.allKeys) {
        DLDevice *device = self.cloudDeviceList[mac];
        if (device.peripheral && !device.connected) {
            [device connectToDevice:nil];
        }
    }
}

- (void)deleteCloudList {
    for (NSString *mac in self.cloudDeviceList) {
        DLDevice *device = [self.cloudDeviceList objectForKey:mac];
        if (device.connected) {
            //断开所有已经连接的设备
            NSLog(@"断开设备的连接: %@", device.peripheral);
            [self.centralManager disConnectToDevice:device.peripheral completion:nil];
        }
    }
    [self.cloudDeviceList removeAllObjects];
}

- (void)autoGetDeviceInfo {
    for (NSString *mac in self.cloudDeviceList.allKeys) {
        DLDevice *device = self.cloudDeviceList[mac];
        [device getDeviceInfo];
    }
}

- (void)getDevicesRSSI {
    for (NSString *mac in self.cloudDeviceList.allKeys) {
        DLDevice *device = self.cloudDeviceList[mac];
        [device readRSSI];
    }
}

// 获取云端的设备列表
- (void)getCloudDeviceList {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *cloudDevices = [defaults objectForKey:@"cloudDeviceList"];
    if (cloudDevices.count > 0) {
        NSMutableDictionary *newList = [NSMutableDictionary dictionary];
        for (NSDictionary *cloudDevice in cloudDevices) {
            NSString *mac = [cloudDevice stringValueForKey:@"mac" defaultValue:@""];
            DLDevice *device = [self.cloudDeviceList objectForKey:mac];
            if (!device) {
                // 不存在，则需要创建
                DLKnowDevice *knowDevice = [self.centralManager.knownPeripherals objectForKey:mac];
                CBPeripheral *peripheral = knowDevice.peripheral;
                device = [DLDevice device:peripheral];
            }
            device.mac = mac;
            device.deviceName = [cloudDevice stringValueForKey:@"name" defaultValue:@""];
            [device setupCoordinate:[cloudDevice stringValueForKey:@"gps" defaultValue:@""]];
            device.type = (int)[cloudDevice integerValueForKey:@"type" defaultValue:1];
            
            // 获取云端保存的设备离线时间
            device.offlineTime = [cloudDevice stringValueForKey:@"offlineTime" defaultValue:@""];
            [newList setValue:device forKey:mac];
        }
        self.cloudDeviceList = newList;
    }
}

- (void)addDeviceByCloudList:(DLDevice *)device {
    if (device) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *cloudDeviceList = [defaults objectForKey:@"cloudDeviceList"];
        NSMutableArray *cloudList = [NSMutableArray arrayWithArray:cloudDeviceList];
        NSMutableDictionary *newDeviceDic = [NSMutableDictionary dictionary];
        [newDeviceDic setValue:device.mac forKey:@"mac"];
        [newDeviceDic setValue:device.deviceName forKey:@"name"];
        [newDeviceDic setValue:@(device.type) forKey:@"type"];
        [newDeviceDic setValue:device.getGps forKey:@"gps"];
        [newDeviceDic setValue:device.offlineTime forKey:@"offlineTime"];
        [cloudList addObject:[newDeviceDic copy]];
        [defaults setValue:[cloudList copy] forKey:@"cloudDeviceList"];
        [defaults synchronize];
    }
}

- (void)removeDeviceByCloudList:(DLDevice *)device {
    if (device) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *cloudDeviceList = [defaults objectForKey:@"cloudDeviceList"];
        NSMutableArray *cloudList = [NSMutableArray arrayWithArray:cloudDeviceList];
        NSDictionary *removeObj = nil;
        for (NSDictionary *dic in cloudList) {
            NSString *mac = [dic stringValueForKey:@"mac" defaultValue:@""];
            if ([mac isEqualToString:device.mac]) {
                removeObj = dic;
                break;
            }
        }
        if (removeObj) {
            [cloudList removeObject:removeObj];
        }
        NSLog(@"删除了设备：removeObj = %@", removeObj);
        NSArray *newCloudList = [cloudList copy];
        NSLog(@"新设备列表: cloudList = %@", newCloudList);
        [defaults setValue:newCloudList forKey:@"cloudDeviceList"];
        [defaults synchronize];
    }
}

- (void)updateOfflineInfoWithDevice:(DLDevice *)device {
    if (device) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *cloudDeviceList = [defaults objectForKey:@"cloudDeviceList"];
        NSMutableArray *cloudList = [NSMutableArray arrayWithArray:cloudDeviceList];
        NSDictionary *removeObj = nil;
        NSMutableDictionary *obj = nil;
        for (NSDictionary *dic in cloudList) {
            NSString *mac = [dic stringValueForKey:@"mac" defaultValue:@""];
            if ([mac isEqualToString:device.mac]) {
                removeObj = dic;
                obj = [NSMutableDictionary dictionaryWithDictionary:dic];
            }
        }
        if (obj) {
            NSString *gps = device.getGps;
            if (gps.length > 0) {
                [obj setValue:gps forKey:@"gps"];
            }
            if (device.offlineTime.length > 0) {
                [obj setValue:device.offlineTime forKey:@"offlineTime"];
            }
            [cloudList removeObject:removeObj];
            [cloudList addObject:[obj copy]];
        }
        [defaults setValue:[cloudList copy] forKey:@"cloudDeviceList"];
        [defaults synchronize];
    }
}

- (void)updateNameWithDevice:(DLDevice *)device {
    if (device) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *cloudDeviceList = [defaults objectForKey:@"cloudDeviceList"];
        NSMutableArray *cloudList = [NSMutableArray arrayWithArray:cloudDeviceList];
        NSDictionary *removeObj = nil;
        NSMutableDictionary *obj = nil;
        for (NSDictionary *dic in cloudList) {
            NSString *mac = [dic stringValueForKey:@"mac" defaultValue:@""];
            if ([mac isEqualToString:device.mac]) {
                removeObj = obj;
                obj = [NSMutableDictionary dictionaryWithDictionary:dic];
            }
        }
        if (obj) {
            if (device.deviceName >= 0) {
                [obj setValue:device.deviceName forKey:@"name"];
            }
            [cloudList removeObject:removeObj];
            [cloudList addObject:obj];
        }
        [defaults setValue:[cloudList copy] forKey:@"cloudDeviceList"];
        [defaults synchronize];
    }
}

- (void)dealloc {
    //移除扫描RSSI定时器
    [_readRSSITimer invalidate];
    _readRSSITimer = nil;
    
    [_getDeviceInfoTimer invalidate];
    _getDeviceInfoTimer = nil;
}

- (NSMutableDictionary<NSString *,DLDevice *> *)cloudDeviceList {
    if (!_cloudDeviceList) {
        _cloudDeviceList = [NSMutableDictionary dictionary];
    }
    return _cloudDeviceList;
}



@end
