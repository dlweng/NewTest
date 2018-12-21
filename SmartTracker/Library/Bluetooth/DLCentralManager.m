//
//  DLBluetoothDeviceManager.m
//  Bluetooth
//
//  Created by danly on 2018/8/12.
//  Copyright © 2018年 date. All rights reserved.
//

#import "DLCentralManager.h"
#import "DLDevice.h"
#import "DLUUIDTool.h"
#import <UIKit/UIKit.h>
#import "DLCloudDeviceManager.h"
#import <pthread/pthread.h>

#define connectCallbackKey @"callback"
#define connectStartTimeKey @"startTime"
#define connectPeripheralKey @"peripheral"
#define connectTimeout 5 //连接超时时间

static DLCentralManager *instance = nil;
static pthread_rwlock_t _connectDeviceEventHandler = PTHREAD_RWLOCK_INITIALIZER;

@implementation DLKnowDevice
@end

@interface DLCentralManager()<CBCentralManagerDelegate> {
    NSMutableDictionary *_knownPeripherals;
    // 计算发现时间的延时器
    NSTimer *_scanTimer;
    int _time;   // 计算此次扫描设备已经进行了多长时间
    int _timeout;  // 一次扫描设备的时间
    
    // 定时去调用一次发现新设备的定时器
    NSTimer *_repeatScanTimer;
}

@property (nonatomic, strong) CBCentralManager *manager;
@property (nonatomic, strong) CentralManagerEvent startCompletion;
@property (nonatomic, strong) DidDiscoverDeviceEvent discoverEvent;
@property (nonatomic, strong) DidEndDiscoverDeviceEvent endDiscoverEvent;
// 保存各个设备对象的连接回调格式 @{peripheral.identifier.UUIDString : DidConnectToDeviceEvent};  这样才不会出现设备连接回调分配到错误的设备对象中
@property (nonatomic, strong) NSMutableDictionary *connectDeviceEventDict;
// 保存各个设备对象的断开连接回调格式 @{peripheral.identifier.UUIDString : DidDisConnectToDeviceEvent};
@property (nonatomic, strong) NSMutableDictionary *disConnectDeviceEventDict;

@end

@implementation DLCentralManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // 创建定时器，初始化发现列表
        _knownPeripherals = [NSMutableDictionary dictionary];
        // 一次扫描延时器
        _scanTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(run) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_scanTimer forMode:NSRunLoopCommonModes];
        [_scanTimer setFireDate:[NSDate distantFuture]];
        
        // 8秒钟扫描一次设备定时器
        _repeatScanTimer = [NSTimer timerWithTimeInterval:8 target:self selector:@selector(repeatScanNewDevice) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_repeatScanTimer forMode:NSRunLoopCommonModes];
        [_repeatScanTimer setFireDate:[NSDate distantFuture]];
        
        // 初始化配置
        _connectDeviceEventDict = [NSMutableDictionary dictionary];
        _disConnectDeviceEventDict = [NSMutableDictionary dictionary];
        
        [self detectionConnectTimeoutLoop];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startScaning) name:ApplicationDidEnterBackground object:nil];
    }
    return self;
}

- (void)dealloc {
    // 销毁定时器
    [_scanTimer invalidate];
    _scanTimer = nil;
    [_repeatScanTimer invalidate];
    _repeatScanTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ApplicationDidEnterBackground object:nil];
}

#pragma mark - Interface
+ (void)startSDKCompletion:(CentralManagerEvent)completion {
    if (!instance) {
        NSLog(@"启动蓝牙SDK");
        instance = [self sharedInstance];
        instance.manager = [[CBCentralManager alloc] initWithDelegate:instance queue:dispatch_get_main_queue() options:@{CBPeripheralManagerOptionShowPowerAlertKey:@YES}];
        instance.startCompletion = completion;
    }
}

- (void)startScanDeviceWithTimeout:(int)timeout discoverEvent:(DidDiscoverDeviceEvent)discoverEvent didEndDiscoverDeviceEvent:(DidEndDiscoverDeviceEvent)endDiscoverEvent {
        NSLog(@"开启设备发现功能");
    
    // 重置扫描设备参数
    _timeout = timeout;
    [_scanTimer setFireDate:[NSDate distantFuture]]; // 关闭定时器

    // 只删除断开连接的设备
    NSMutableArray *disconnectKeys = [NSMutableArray array];
    for (NSString *mac in _knownPeripherals.allKeys) {
        DLKnowDevice *knowDevice = _knownPeripherals[mac];
        if (knowDevice.peripheral.state == CBPeripheralStateDisconnected) {
            [disconnectKeys addObject:mac];
        }
    }
    for (NSString *mac in disconnectKeys) {
        [_knownPeripherals removeObjectForKey:mac];
    }
    
    // 开始扫描
    [self startScaning];
    
    // 开始扫描计时
    _time = 0;
    [_scanTimer setFireDate:[NSDate distantPast]];
    self.discoverEvent = discoverEvent;
    self.endDiscoverEvent = endDiscoverEvent;
}

- (void)stopScanning {
    [self.manager stopScan];
    // 更新一下云端列表
    if (self.endDiscoverEvent) {
        self.endDiscoverEvent(self, self.knownPeripherals);
    }
}

- (void)connectToDevice: (CBPeripheral *)peripheral completion:(DidConnectToDeviceEvent)completion {
    NSDictionary *options = @{CBConnectPeripheralOptionNotifyOnDisconnectionKey: @NO, CBConnectPeripheralOptionNotifyOnConnectionKey: @NO,CBConnectPeripheralOptionNotifyOnNotificationKey: @NO};
    [self.manager connectPeripheral:peripheral options:options];
    
    if (completion) {
        // @{peripheral.identifier.UUIDString : @{@"callback": DidConnectToDeviceEvent, @"startTime": 开始发起连接的时间}};
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:2];
        NSNumber *startTime = @(time(NULL));
        [dic setValue:completion forKey:connectCallbackKey];
        [dic setValue:startTime forKey:connectStartTimeKey];
        [dic setValue:peripheral forKey:connectPeripheralKey];
        NSLog(@"DLCentralManager: 去连接设备: ********************************** %@", peripheral);
        pthread_rwlock_wrlock(&_connectDeviceEventHandler);
        [self.connectDeviceEventDict setValue:[dic copy] forKey:peripheral.identifier.UUIDString];
        pthread_rwlock_unlock(&_connectDeviceEventHandler);
    }
}

- (void)disConnectToDevice: (CBPeripheral *)peripheral completion:(DidDisConnectToDeviceEvent)completion {
    [self.manager cancelPeripheralConnection:peripheral];
    if (self.manager.state != CBCentralManagerStatePoweredOn) {
        if (completion) {
            completion(self, peripheral, nil);
        }
        return;
    }
    if (completion) {
        // 保存断开连接的回调，字典格式{peripheral.identifier.UUIDString, DidDisConnectToDeviceEvent};
        [self.disConnectDeviceEventDict setValue:completion forKey:peripheral.identifier.UUIDString];
    }
}

#pragma mark - 内部工具方法
- (void)startScaning {
    NSLog(@"开始扫描设备");
    CBUUID *serverUUID = [DLUUIDTool CBUUIDFromInt:DLServiceUUID];
    NSArray *arr = nil;
    if (serverUUID) {
        arr = [NSArray arrayWithObject:serverUUID];
    }
    [self.manager scanForPeripheralsWithServices:arr options:nil];
}

- (void)run {
    //    NSLog(@"定时器计时:_time = %d", _time);
    _time++;
    if (_time >= _timeout) {
        // 关闭定时器，停止扫描
        [_scanTimer setFireDate:[NSDate distantFuture]];
        [self stopScanning];
    }
}

- (void)repeatScanNewDevice {
    // 每3秒钟扫描2秒钟设备
    [self startScaning];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_queue_create(0, 0), ^{
        [NSThread sleepForTimeInterval:6];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
                [weakSelf.manager stopScan];
                NSLog(@"停止扫描设备");
            }
        });
    });
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (self.manager.state) {
        case CBCentralManagerStateResetting:
        case CBCentralManagerStatePoweredOff:
        case CBCentralManagerStateUnknown:
        {
            NSLog(@"APP的蓝牙设置处于关闭状态，重置或未知状态");
            [_repeatScanTimer setFireDate:[NSDate distantFuture]];
            [self stopScanning];
            [[NSNotificationCenter defaultCenter] postNotificationName:BluetoothPoweredOffNotification object:nil];
            break;
        }
        case CBCentralManagerStatePoweredOn:
        {
            [_repeatScanTimer setFireDate:[NSDate distantPast]];
            NSLog(@"APP的蓝牙设置处于打开状态");
            break;
        }
        case CBCentralManagerStateUnauthorized:
            NSLog(@"APP的蓝牙设置处于未授权状态");
            break;
        case CBCentralManagerStateUnsupported:
            NSLog(@"本设备不支持蓝牙功能");
            break;
        default:
            NSLog(@"未知状态");
            break;
    }
    if (self.startCompletion) {
        self.startCompletion(self, (CBCentralManagerState)self.manager.state);
    }
}

- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"发现新设备： %@, advertisementData = %@, RSSI = %@", peripheral, advertisementData, RSSI);
// 有效代码
// 广播数据案例
//    advertisementData = {
//        kCBAdvDataIsConnectable = 1;
//        kCBAdvDataLocalName = Lily;  // 设备名称
//        kCBAdvDataServiceData =     {
//            D888 = <00000000 0014>;   // D888表示设备mac地址
//        };
//        kCBAdvDataServiceUUIDs =     (
//                                      E001 // E001表示是innway的设备
//                                      );
//    }
    if ([self effectivePeripheral:advertisementData]) {
        NSString *mac = [self getDeviceMac:advertisementData];
        if (mac.length > 0) {
            DLKnowDevice *knowDevice = [_knownPeripherals objectForKey:mac];
            if (!knowDevice) {
                // 发现列表不存在该设备，需要添加
//                NSLog(@"发现新设备: %@, advertisementData = %@", mac, advertisementData);
                knowDevice = [[DLKnowDevice alloc] init];
                knowDevice.peripheral = peripheral;
                [_knownPeripherals setValue:knowDevice forKey:mac];
            }
            
            //更新rssi
            knowDevice.rssi = RSSI;
            knowDevice.peripheral = peripheral;
            if(![DLCloudDeviceManager sharedInstance].cloudDeviceList[mac]) {
                // 设备不存在云端列表，且设备类型与客户查找的类型相同，才回调
                BOOL callback = NO;
                InDeviceType findDeviceType = [common getDeviceType:peripheral];
                if (common.deviceType == findDeviceType || (common.deviceType == InDeviceAll && (findDeviceType == InDeviceSmartCardHolder || findDeviceType == InDeviceSmartCard))) {
                    callback = YES;
                }
                if (callback && self.discoverEvent) {
                    self.discoverEvent(self, peripheral, mac);
                }
            }
            else {
                // 设备存在云端列表，更新
                [[DLCloudDeviceManager sharedInstance] updateCloudList];
            }
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"DLCentralManager: 连接设备成功: %@", peripheral);
    NSDictionary *eventDic = [self.connectDeviceEventDict objectForKey:peripheral.identifier.UUIDString];
    //将回调分发到对应的设备对象上
    if (eventDic) {
        DidConnectToDeviceEvent event = [eventDic objectForKey:connectCallbackKey];
        if (event) {
            event(self, peripheral, nil);
        }
        // 一回调马上移除掉该数据，因为一次连接只会对应一次回调
        pthread_rwlock_wrlock(&_connectDeviceEventHandler);
        [self.connectDeviceEventDict removeObjectForKey:peripheral.identifier.UUIDString];
        pthread_rwlock_unlock(&_connectDeviceEventHandler);
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"DLCentralManager: 连接设备失败: %@, error = %@", peripheral, error);
    // 将回调分发到对应的设备对象上
    NSDictionary *eventDic = [self.connectDeviceEventDict objectForKey:peripheral.identifier.UUIDString];
    //将回调分发到对应的设备对象上
    if (eventDic) {
        DidConnectToDeviceEvent event = [eventDic objectForKey:connectCallbackKey];
        if (event) {
            event(self, peripheral, error);
        }
        // 一回调马上移除掉该数据，因为一次连接只会对应一次回调
        pthread_rwlock_wrlock(&_connectDeviceEventHandler);
        [self.connectDeviceEventDict removeObjectForKey:peripheral.identifier.UUIDString];
        pthread_rwlock_unlock(&_connectDeviceEventHandler);
    }
    //连接失败也发出通知，让APP去重连
    [[NSNotificationCenter defaultCenter] postNotificationName:DeviceDisconnectNotification object:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
//#warning 测试代码
//    if (error) {
//        NSDictionary *cloudDeviceList = [DLCloudDeviceManager sharedInstance].cloudDeviceList;
//        DLDevice *tapDevice;
//        for (NSString *mac in cloudDeviceList.allKeys) {
//            DLDevice *device = cloudDeviceList[mac];
//            if ([device.peripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) {
//                tapDevice = device;
//                break;
//            }
//        }
//        
//        NSString *messgae;
//        if (tapDevice) {
//            messgae = [NSString stringWithFormat:@"%@\n设备:%@ 连接被断开了\n错误:%@",[common getCurrentTime], tapDevice.mac, error.localizedDescription];
//        }
//        else {
//            messgae = [NSString stringWithFormat:@"%@\n未知设备连接被断开了\n错误:%@",[common getCurrentTime],error.localizedDescription];
//        }
//        [InAlertView showAlertWithTitle:@"Information" message:messgae confirmHanler:nil];
//    }
    
    NSLog(@"CBCentralManager: 接收到系统的断开通知: %@, error = %@", peripheral, error);
    // 被动断开连接时，error才不为Nil，此时才需要去做重连
    // 发出断开连接通知
    [[NSNotificationCenter defaultCenter] postNotificationName:DeviceDisconnectNotification object:peripheral];
    // 将断开连接的通知分发到对应的设备对象上
    DidDisConnectToDeviceEvent event = [self.disConnectDeviceEventDict objectForKey:peripheral.identifier.UUIDString];
    if (event) {
        event(self, peripheral, error);
        [self.disConnectDeviceEventDict removeObjectForKey:peripheral.identifier.UUIDString];
    }
}

#pragma mark - Tool
- (NSString *)getDeviceMac:(NSDictionary *)advertisementData {
    if (advertisementData.count && [advertisementData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *kCBAdvDataServiceData = advertisementData[@"kCBAdvDataServiceData"];
        if (kCBAdvDataServiceData) {
            CBUUID *macUUID = [DLUUIDTool CBUUIDFromInt:DLDeviceMAC];
            NSData *data = kCBAdvDataServiceData[macUUID];
            if (!data) {
                // 适配旧的测试设备
                macUUID = [DLUUIDTool CBUUIDFromInt:0xD006];
                data = kCBAdvDataServiceData[macUUID];
            }
            if (data) {
                NSString *tempStr = [data.description stringByReplacingOccurrencesOfString:@" " withString:@""];
                NSMutableString *mac = [NSMutableString stringWithString:[tempStr substringWithRange:NSMakeRange(1, 2)]];
                [mac appendString:@":"];
                [mac appendString:[tempStr substringWithRange:NSMakeRange(3, 2)]];
                [mac appendString:@":"];
                [mac appendString:[tempStr substringWithRange:NSMakeRange(5, 2)]];
                [mac appendString:@":"];
                [mac appendString:[tempStr substringWithRange:NSMakeRange(7, 2)]];
                [mac appendString:@":"];
                [mac appendString:[tempStr substringWithRange:NSMakeRange(9, 2)]];
                [mac appendString:@":"];
                [mac appendString:[tempStr substringWithRange:NSMakeRange(11, 2)]];
                return mac;
            }
        }
    }
    return nil;
}

-(BOOL)effectivePeripheral:(NSDictionary *)advertisementData {
    if (advertisementData.count && [advertisementData isKindOfClass:[NSDictionary class]]) {
        NSArray *kCBAdvDataServiceUUIDs = advertisementData[@"kCBAdvDataServiceUUIDs"];
        if (kCBAdvDataServiceUUIDs.count > 0) {
            for (CBUUID *uuid in kCBAdvDataServiceUUIDs) {
                if ([uuid.UUIDString isEqualToString:@"E001"]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (void)detectionConnectTimeoutLoop {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (1) {
            // 不需要太频繁的检测, 1秒一次即可
            [NSThread sleepForTimeInterval:1];
            pthread_rwlock_wrlock(&_connectDeviceEventHandler);
            NSMutableArray *removeCallback = [NSMutableArray array];
            for (NSString *periperalUUID in weakSelf.connectDeviceEventDict.allKeys) {
                NSDictionary *eventDic = weakSelf.connectDeviceEventDict[periperalUUID];
                time_t startTime = [eventDic integerValueForKey:connectStartTimeKey defaultValue:time(NULL)];
                time_t exeTime = time(NULL) - startTime;
                if (exeTime >= 5) {
                    // 到了超时时间，还没有回调，回调连接超时
                    DidConnectToDeviceEvent event = eventDic[connectCallbackKey];
                    CBPeripheral *peripheral = eventDic[connectPeripheralKey];
                    NSError *error = [NSError errorWithDomain:NSStringFromClass([CBPeripheral class]) code:-2 userInfo:nil];
                    NSLog(@"运行环检测到设备连接超时: %@", peripheral);
                    [removeCallback addObject:periperalUUID];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (event) {
                            [weakSelf.manager cancelPeripheralConnection:peripheral];
                            event(weakSelf, peripheral, error);
                        }
                    });
                }
            }
            for (NSString *periperalUUID in removeCallback) {
                [self.connectDeviceEventDict removeObjectForKey:periperalUUID];
            }
            pthread_rwlock_unlock(&_connectDeviceEventHandler);
        }
    });
}

#pragma mark - Properity
- (NSMutableDictionary<NSString *, DLKnowDevice*> *)knownPeripherals {
    return [_knownPeripherals copy];
}

- (CBCentralManagerState)state {
    return self.manager.state;
}

@end
