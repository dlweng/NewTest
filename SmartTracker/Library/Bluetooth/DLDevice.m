//
//  DLPeripheral.m
//  Bluetooth
//
//  Created by danly on 2018/8/18.
//  Copyright © 2018年 date. All rights reserved.
//

// 设置设备在线的逻辑：只有获取到写数据的角色特征值才设置为在线。 因为有多次出现连接上了获取不到特征值， 而且首次获取不到，后面再次去获取特征值也是无效的，只能断开重新连接。
// 在连接并去调用获取特征值5秒后还未获取到特征值，将会断开重新连接


#import "DLDevice.h"
#import "DLUUIDTool.h"
#import "DLCentralManager.h"
#import "InCommon.h"
#import "NSTimer+InTimer.h"
#import <AVFoundation/AVFoundation.h>
#import "DLCloudDeviceManager.h"

// 设置离线的RSSI值
#define offlineRSSI @(-120)

// 设置重连超时  重连超时时间一定要为连接超时时间的倍数
#define reconnectTimeOut 17
#define reconnectMaxCount 10

@interface DLDevice()<AVAudioPlayerDelegate> {
    NSNumber *_rssi;
    dispatch_source_t _searchDeviceackDelayTimer;// 查找设备ack回复计时器
    dispatch_source_t _disciverServerTimer;// 获取写数据特征值计时器
    BOOL _disConnect; // 只有删除设备或者注销账户该值会被值为YES
    
    NSTimer *_offlineReconnectTimer; //断开重连计时器
    int _offlineReconnectTime; //计算从断开到重连的时间
}

@property (nonatomic, assign) BOOL isGetSearchDeviceAck; // 标识下发查找设备命令得到ack否
@property (nonatomic, assign) NSInteger isDiscoverAllCharacter; //标志是否获取到写数据特征值

// 保存设置的值，等ack回来之后更新本地数据
@property (nonatomic, assign) int reconnectNum;
@property (nonatomic, assign) BOOL disconnectAlert;
@property (nonatomic, assign) BOOL reconnectAlert;
@property (nonatomic, assign) NSInteger alertMusic;
@property (nonatomic, strong) NSMutableDictionary *data;
@property (nonatomic, strong) NSMutableArray *rssiValues; // 更新RSSI逻辑，1秒获取一次RSSI，3秒更新一次UI，将3秒钟获取到的3次RSSI的最大值通知到界面
@property (nonatomic, strong) AVAudioPlayer *searchPhonePlayer;
@property (nonatomic, strong) AVAudioPlayer *offlinePlayer;
@end

@implementation DLDevice

+ (instancetype)device:(CBPeripheral *)peripheral {
    DLDevice *device = [[DLDevice alloc] init];
    device.peripheral = peripheral;
    return device;
}

- (instancetype)init {
    if (self = [super init]) {
        // 增加断开连接监听
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reconnectDevice:) name:DeviceDisconnectNotification object:nil];
        // 蓝牙关闭监听
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bluetoothPoweredOff) name:BluetoothPoweredOffNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWasKilled) name:APPBeKilledNotification object:nil];
        
        _disConnect = NO;
        _isGetSearchDeviceAck = NO;
        self.isOfflineSounding = NO;
        self.isSearchPhone = NO;
        // 初始化断开重连计时器数据
        __block typeof(self) weakSelf = self;
        _offlineReconnectTimer = [NSTimer newTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            [weakSelf offlineTiming];
        }];

        [[NSRunLoop currentRunLoop] addTimer:_offlineReconnectTimer forMode:NSRunLoopCommonModes];
        // 加到主循环的定时器会自动被触发，需要先关闭定时器
        [_offlineReconnectTimer setFireDate:[NSDate distantFuture]];
        _offlineReconnectTime = -1;
    
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceDisconnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BluetoothPoweredOffNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:APPBeKilledNotification object:nil];
}

#pragma mark - 获取特征值的处理
- (void)discoverServices {
    if (_peripheral) {
        NSLog(@"去获取设备服务:%@", self.mac);
        CBUUID *serviceUUID = [DLUUIDTool CBUUIDFromInt:DLServiceUUID];
        CBUUID *firmwareServerUUID = [DLUUIDTool CBUUIDFromInt:DLFirmwareServerUUID];
        [_peripheral discoverServices:@[serviceUUID, firmwareServerUUID]];
        self.isDiscoverAllCharacter = 0;
        [self startDiscoverServerTimer];
    }
    else {
        NSLog(@"无法去获取设备服务:%@, 外设不存在", self.mac);
    }
}

- (void)startDiscoverServerTimer {
    _disciverServerTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    __weak typeof(_disciverServerTimer) weakTimer = _disciverServerTimer;
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_disciverServerTimer, ^{
        dispatch_source_cancel(weakTimer);
        if (weakSelf.isDiscoverAllCharacter == 0) {
            if (weakSelf.peripheral) {
                 [[DLCentralManager sharedInstance] disConnectToDevice:weakSelf.peripheral completion:nil];
            }
        }
    });
    // 设置5秒超时
    dispatch_source_set_timer(_disciverServerTimer, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC), 0, 0);
    dispatch_resume(_disciverServerTimer);
}

- (void)peripheral:(CBPeripheral *)_peripheral didDiscoverServices:(NSError *)error {
    NSArray *services = [_peripheral services];
    CBUUID *serverUUID = [DLUUIDTool CBUUIDFromInt:DLServiceUUID];
    CBUUID *firmwareServerUUID = [DLUUIDTool CBUUIDFromInt:DLFirmwareServerUUID];
    for (CBService *service in services) {
        if ([service.UUID.UUIDString isEqualToString:serverUUID.UUIDString]) {
            CBUUID *ntfUUID = [DLUUIDTool CBUUIDFromInt:DLNTFCharacteristicUUID];
            CBUUID *writeUUID = [DLUUIDTool CBUUIDFromInt:DLWriteCharacteristicUUID];
            [self.peripheral discoverCharacteristics:@[ntfUUID, writeUUID] forService:service];
        }
        else if ([service.UUID.UUIDString isEqualToString:firmwareServerUUID.UUIDString]) {
            CBUUID *firmwareChaUUID = [DLUUIDTool CBUUIDFromInt:DLFirmwareCharacteristicUUID];
            [self.peripheral discoverCharacteristics:@[firmwareChaUUID] forService:service];
            NSLog(@"service = %@", service);
        }
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    CBUUID *ntfUUID = [DLUUIDTool CBUUIDFromInt:DLNTFCharacteristicUUID];
    CBUUID *writeUUID = [DLUUIDTool CBUUIDFromInt:DLWriteCharacteristicUUID];
    CBUUID *firmwareChaUUID = [DLUUIDTool CBUUIDFromInt:DLFirmwareCharacteristicUUID];
    NSArray *characteristics = [service characteristics];
    for (CBCharacteristic *characteristic in characteristics) {
        if ([characteristic.UUID.UUIDString isEqualToString:firmwareChaUUID.UUIDString]) {
            NSLog(@"characteristic = %@", characteristic);
            [self.peripheral readValueForCharacteristic:characteristic];
            return; //获取硬件数据
        }
        if ([characteristic.UUID.UUIDString isEqualToString:writeUUID.UUIDString]) {
            self.isDiscoverAllCharacter++;
        }
        if ([characteristic.UUID.UUIDString isEqualToString:ntfUUID.UUIDString]) {
            self.isDiscoverAllCharacter++;
            [self notification:DLServiceUUID characteristicUUID:DLNTFCharacteristicUUID p:self.peripheral on:YES];
        }
        if (self.isDiscoverAllCharacter == 2) {
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                [NSThread sleepForTimeInterval:0.2];
                //激活设备
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"去激活设备: %@", weakSelf.mac);
                    [weakSelf activeDevice];
                });
                if (self.firstAdd) { 
                    self.firstAdd = NO;
                    [NSThread sleepForTimeInterval:0.2];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSLog(@"第一次添加，去发关闭断连通知的命令");
                        [weakSelf setDisconnectAlert:NO reconnectAlert:NO];
                    });
                }
                [NSThread sleepForTimeInterval:0.2];
                // 获取设备信息
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.online = YES;  //设置在线
                    weakSelf.reconnectNum = 0;
                    NSLog(@"设置设备在线");
                    [weakSelf readRSSI];
                    [weakSelf getDeviceInfo]; //防止两次发生时间太接近，导致下发失败
                });
            });
        }
    }
}

#pragma mark - RSSI值更新的相关处理
- (NSNumber *)rssi {
    if (!_rssi) {
        _rssi = offlineRSSI;
    }
    return _rssi;
}

- (void)setRssi:(NSNumber *)rssi {
    if (_rssi.intValue == offlineRSSI.intValue && rssi.intValue != offlineRSSI.intValue) { // 从离线变为在线的第一次马上发出通知
        _rssi = rssi;
        // RSSI改变要发出通知
        [[NSNotificationCenter defaultCenter] postNotificationName:DeviceRSSIChangeNotification object:self];
    }
    else {
        [self.rssiValues addObject:rssi]; //加入新值
        // 找出最大值
        if (self.rssiValues.count == 3) {
            _rssi = [self getMaxRssi]; // 赋值最大值
            // RSSI改变要发出通知
            [[NSNotificationCenter defaultCenter] postNotificationName:DeviceRSSIChangeNotification object:self];
            // 清除RSSI数组
            [self.rssiValues removeAllObjects];
        }
    }
}

- (void)readRSSI {
    if (self.online && self.connected) {
        [self.peripheral readRSSI];
    }
}

- (NSNumber *)getMaxRssi {
    NSNumber *maxRssi = offlineRSSI;
    for (NSNumber *rssi in self.rssiValues) {
        if (rssi.intValue > maxRssi.intValue) {
            maxRssi = rssi;
        }
    }
    return maxRssi;
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    if (peripheral == self.peripheral && !error) {
        NSLog(@"接收到设备信号值: %@, mac:%@", RSSI, self.mac);
        self.rssi = RSSI;
    }
}

#pragma mark - 写数据快捷接口
- (void)activeDevice {
    uint8_t active[1] = {0x01};
    [self write:[NSData dataWithBytes:active length:1]];
}

- (void)getDeviceInfo {
    if (!self.connected) {
        return;
    }
    uint8_t getDeviceInfo[4] = {0xEE, 0x01, 0x00, 0x00};
    NSLog(@"mac = %@, 去获取设备硬件数据， %@", self.mac, [NSData dataWithBytes:getDeviceInfo length:4]);
    [self write:[NSData dataWithBytes:getDeviceInfo length:4]];
}

- (void)searchDevice {
    uint8_t search[4] = {0xEE, 0x03, 0x00, 0x00};
    [self write:[NSData dataWithBytes:search length:4]];
}

- (void)searchPhoneACK {
    NSLog(@"回应设备:%@ 的查找数据", _mac);
    uint8_t search[4] = {0xEE, 0x06, 0x00, 0x00};
    [self write:[NSData dataWithBytes:search length:4]];
}

- (void)setDisconnectAlert:(BOOL)disconnectAlert reconnectAlert:(BOOL)reconnectAlert {
    self.disconnectAlert = disconnectAlert;
    self.reconnectAlert = reconnectAlert;
    int disconnect = disconnectAlert? 0x01 : 0x00;
    int reconnect = reconnectAlert? 0x01: 0x00;
    uint8_t command[6] = {0xEE, 0x07, 0x02, disconnect, reconnect, 0x00};
    NSLog(@"改变设备：%@, 断连通知：%d, 重连通知：%d， 写数据: %@", _mac, disconnectAlert, reconnectAlert, [NSData dataWithBytes:command length:6]);
    [self write:[NSData dataWithBytes:command length:6]];
}

//警报音编码，可选 01，02，03
- (void)selecteDiconnectAlertMusic:(NSInteger)alertMusic {
    self.alertMusic = alertMusic;
    int alert;
    switch (alertMusic) {
        case 1:
            alert = 0x01;
            break;
        case 2:
            alert = 0x02;
            break;
        case 3:
            alert = 0x03;
            break;
        default:
            alert = 0x01;
            break;
    }
    char command[5] = {0xEE, 0x09, 0x01, alert, 0x00};
    [self write:[NSData dataWithBytes:command length:5]];
}

- (void)parseData:(NSData *)data {
    NSString *dataStr = data.description;
    dataStr =  [dataStr stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *cmd = [dataStr substringWithRange:NSMakeRange(3, 2)];
    NSString *length = [dataStr substringWithRange:NSMakeRange(5, 2)];
    NSString *payload = [dataStr substringWithRange:NSMakeRange(7, length.integerValue * 2)];
    if ([cmd isEqualToString:@"02"]) {
        if (payload.length != 10) {
            return;
        }
        //获取设备信息的回调
        NSString *electric = [payload substringWithRange:NSMakeRange(0, 2)];
        NSString *chargingState = [payload substringWithRange:NSMakeRange(2, 2)];
        NSString *disconnectAlert = [payload substringWithRange:NSMakeRange(4, 2)];
        NSString *reconnectAlert = [payload substringWithRange:NSMakeRange(6, 2)];
        NSString *alertMusic = [payload substringWithRange:NSMakeRange(8, 2)];
        NSInteger electricNum = [common getIntValueByHex:electric];
        [self.data setValue:@(electricNum) forKey:ElectricKey];
        NSLog(@"mac:%@ 电量：16进制:%@, 10进制:%zd, peripheral = %@", _mac, electric, electricNum, self.peripheral);
        [self.data setValue:@(chargingState.boolValue) forKey:ChargingStateKey];
        [self.data setValue:@(disconnectAlert.boolValue) forKey:DisconnectAlertKey];
        [self.data setValue:@(reconnectAlert.boolValue) forKey:ReconnectAlertKey];
        [self.data setValue:@(alertMusic.integerValue) forKey:AlertMusicKey];
//        NSLog(@"获取到的设备数据: %@", self.data.description);
    }
    else if ([cmd isEqualToString:@"04"]) {
        if (payload.length != 2) {
            return;
        }
        _isGetSearchDeviceAck = YES; //标识获得了查找设备的ack
        NSString *alertStatus = [payload substringWithRange:NSMakeRange(0, 2)];
        if (!alertStatus.boolValue) {
            _isSearchDevice = NO;
//            NSLog(@"接收到设备状态通知，关闭查找设备");
        }
        else {
            _isSearchDevice = YES;
//            NSLog(@"接收到设备状态通知，打开查找设备");
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:DeviceSearchDeviceAlertNotification object:self userInfo:@{@"device":self}];
    }
    else if ([cmd isEqualToString:@"05"]) {
        NSLog(@"设备:%@ 寻找手机，手机要发出警报，05数据:%@", _mac, data);
        // 收到设备查找，要做出回应
        [self searchPhoneACK];
        [[NSNotificationCenter defaultCenter] postNotificationName:DeviceSearchPhoneNotification object:self userInfo:@{@"Device":self}];
    }
    else if ([cmd isEqualToString:@"08"]) {
        [self.data setValue:@(self.disconnectAlert) forKey:DisconnectAlertKey];
        [self.data setValue:@(self.reconnectAlert) forKey:ReconnectAlertKey];
    }
    else if ([cmd isEqualToString:@"0a"]) {
        [self.data setValue:@(self.alertMusic) forKey:AlertMusicKey];
    }
}

#pragma mark - 写数据
- (void) write:(NSData *)data {
    if (self.peripheral && self.connected) {
        [self writeValue:DLServiceUUID characteristicUUID:DLWriteCharacteristicUUID p:self.peripheral data:data andResponseType:CBCharacteristicWriteWithoutResponse];
    }
}

- (void) writeValue:(int)serviceUUID characteristicUUID:(int)characteristicUUID p:(CBPeripheral *)p data:(NSData *)data andResponseType:(CBCharacteristicWriteType)responseType
{
    if (!self.connected) {
        return;
    }
    CBUUID *su = [DLUUIDTool CBUUIDFromInt:serviceUUID];
    CBUUID *cu = [DLUUIDTool CBUUIDFromInt:characteristicUUID];
    CBService *service = [self findServiceFromUUID:su p:p];
    if (!service) {
        NSLog(@"mac:%@, 重连设备 %s", self.mac, [self CBUUIDToString:su]);
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:cu service:service];
    if (!characteristic) {
        NSLog(@"mac:%@, 写数据查找不到角色: %s", self.mac, [self CBUUIDToString:cu]);
        return;
    }
    [p writeValue:data forCharacteristic:characteristic type:responseType];
}

- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"mac:%@, 写入的响应值: %@,  %@", self.mac, characteristic, error);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if ([peripheral.identifier.UUIDString isEqualToString:self.peripheral.identifier.UUIDString]) {
        NSLog(@"mac:%@, 接收读响应数据, peripheral：%@,  characteristic = %@, error = %@", self.mac, self.peripheral, characteristic.value, error);
        // 读硬件版本号
        CBUUID *firmwareChaUUID = [DLUUIDTool CBUUIDFromInt:DLFirmwareCharacteristicUUID];
        if ([characteristic.UUID.UUIDString isEqualToString:firmwareChaUUID.UUIDString]) {
            NSString *value = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
            self.firmware = value;
            return;
        }
        
        // 读普通数据
        [self parseData:characteristic.value];
        if (self.delegate) {
            [self.delegate device:self didUpdateData:self.lastData];
        }
    }
}

- (void)notification:(int)serviceUUID characteristicUUID:(int)characteristicUUID p:(CBPeripheral *)p on:(BOOL)on {
    CBUUID *su = [DLUUIDTool CBUUIDFromInt:serviceUUID];
    CBUUID *cu = [DLUUIDTool CBUUIDFromInt:characteristicUUID];
    CBService *service = [self findServiceFromUUID:su p:p];
    if (!service) {
        NSLog(@"mac:%@, 通知功能更查找不到服务: %s", self.mac, [self CBUUIDToString:su]);
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:cu service:service];
    if (!characteristic) {
        NSLog(@"mac:%@,  通知功能更查找不到角色: %s", self.mac, [self CBUUIDToString:cu]);
        return;
    }
    [p setNotifyValue:on forCharacteristic:characteristic];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    NSLog(@"mac:%@, 接收来自设备的通知, characteristic = %@, error = %@", self.mac, characteristic, error);
    
    [self parseData:characteristic.value];
}

#pragma mark - 连接与断开连接
- (void)connectToDevice:(void (^)(DLDevice *device, NSError *error))completion {
    if (!self.peripheral) {
        NSError *error = [NSError errorWithDomain:NSStringFromClass([DLCentralManager class]) code:-2 userInfo:@{NSLocalizedDescriptionKey: @"与设备建立连接失败"}];
        if (completion) {
            completion(self, error);
        }
        return;
    }
    if (!self.connecting) {
        NSLog(@"开始去连接设备:%@", self.mac);
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_queue_create(0, 0), ^{
            [[DLCentralManager sharedInstance] connectToDevice:weakSelf.peripheral completion:^(DLCentralManager *manager, CBPeripheral *peripheral, NSError *error) {
                if (!error) {
                    NSLog(@"连接设备成功:%@", weakSelf.mac);
                    // 连接成功，去获取设备服务
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self stopReconnectTimer];
                        self.isOfflineSounding = NO;
                        peripheral.delegate = weakSelf;
                        [weakSelf discoverServices];
                        if (completion) {
                            completion(weakSelf, nil);
                        }
                    });
                    return ;
                }
                else {
                    NSLog(@"连接设备失败:%@", weakSelf.mac);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) {
                            completion(weakSelf, error);
                        }
                    });
                }
            }];
        });
    }
    else {
        if (completion) {
            completion(self, nil);
        }
    }
}

- (void)disConnectToDevice:(void (^)(DLDevice *device, NSError *error))completion {
    // 只有删除设备和注销账户可以调用可以接口去断连
    _disConnect = YES;
    // 当前如果有正在重连的操作，需要去关闭
    [_offlineReconnectTimer setFireDate:[NSDate distantFuture]];
    self.reconnectNum = reconnectMaxCount;
    if (!self.peripheral) {
        // 不存在外设，当成断开设备连接成功
        if (completion) {
            completion(self, nil);
        }
        return;
    }
    NSLog(@"开始去断开设备连接:%@", self.mac);
    __weak typeof(self) weakSelf = self;
    [[DLCentralManager sharedInstance] disConnectToDevice:self.peripheral completion:^(DLCentralManager *manager, CBPeripheral *peripheral, NSError *error) {
        if (completion) {
            completion(weakSelf, error);
        }
    }];
}

- (void)reconnectDevice:(NSNotification *)notification {
    CBPeripheral *peripheral = notification.object;
    if ([peripheral.identifier.UUIDString isEqualToString:self. peripheral.identifier.UUIDString]) {
        NSLog(@"断开连接的设备： %@", peripheral);
        if (!_disConnect) // 非用户主动断开的情况
        {
            // 去做超时重连
            [self reconnectOprate];
        }
        else {
            // 用户断连的，直接设置离线
            [self changeStatusToDisconnect:NO];
        }
    }
}

- (void)reconnectOprate {
    //被动的掉线且蓝牙打开，去做重连
    if (self.online && !self.isReconnectTimer) { //当前是在线，需要计时设置为离线
        // 开始重连计时
        [_offlineReconnectTimer setFireDate:[NSDate distantPast]];
        //                    // 激活后台线程 重连超时大于10秒，才需要这两行代码
        self.isReconnectTimer = YES; // 标志开始了重连计时
        [common beginBackgroundTask];
    }
    if (self.reconnectNum < reconnectMaxCount) {
        if (self.connecting) {
            return; // 如果当前设备处于正在连接的状态，不去做重连
        }
        self.reconnectNum++;
        NSLog(@"设备连接被断开，去重连设备, mac = %@, 重连计数: %d", self.mac, self.reconnectNum);
        // 去重连设备
        self.isDiscoverAllCharacter = 0;
        [self connectToDevice:^(DLDevice *device, NSError *error) {
            if (error) {
                NSLog(@"mac: %@, 设备重连失败", self.mac);
            }
            else {
                NSLog(@"mac: %@, 设备重连成功", self.mac);
            }
        }];
    }
    else {
        self.reconnectNum = 0; //初始化重连基数
        NSLog(@"已经重连%d次, 不再去重连:%@", self.reconnectNum, self.mac);
        
    }
}

// 计算重连时间
- (void)offlineTiming {
    _offlineReconnectTime++;
    NSLog(@"重连时间: %d，mac: %@", _offlineReconnectTime, self.mac);
    if (_offlineReconnectTime >= reconnectTimeOut) {
        if (!self.connected) { // 判断重连的条件降低
            NSLog(@"重连超时，还没连上设备, 保存设备离线信息 mac = %@", self.mac);
            [self changeStatusToDisconnect:YES];
        }
        else {
            NSLog(@"重连超时，已经连上设备, mac = %@", self.mac);
        }
        [self stopReconnectTimer];
    }
    
}

- (void)stopReconnectTimer {
    // 关闭计时器
    _offlineReconnectTime = -1;
    [_offlineReconnectTimer setFireDate:[NSDate distantFuture]];
    // 初始化重连标志
    self.isReconnectTimer = NO;
    self.reconnectNum = 0;
    // 关闭后台任务
    [common endBackgrondTask];
}

#pragma mark - 查找服务和角色的作用
/*
 *  @method findServiceFromUUID:
 *
 *  @param UUID CBUUID to find in service list
 *  @param p Peripheral to find service on
 *
 *  @return pointer to CBService if found, nil if not
 *
 *  @discussion findServiceFromUUID searches through the services list of a peripheral to find a
 *  service with a specific UUID
 *
 */
-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p {
    for(int i = 0; i < p.services.count; i++) {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID]) return s;
    }
    return nil; //Service not found on this peripheral
}

/*
 *  @method findCharacteristicFromUUID:
 *
 *  @param UUID CBUUID to find in Characteristic list of service
 *  @param service Pointer to CBService to search for charateristics on
 *
 *  @return pointer to CBCharacteristic if found, nil if not
 *
 *  @discussion findCharacteristicFromUUID searches through the characteristic list of a given service
 *  to find a characteristic with a specific UUID
 *
 */
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service {
    for(int i=0; i < service.characteristics.count; i++) {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([self compareCBUUID:c.UUID UUID2:UUID]) return c;
    }
    return nil; //Characteristic not found on this service
}

/*
 *  @method compareCBUUID
 *
 *  @param UUID1 UUID 1 to compare
 *  @param UUID2 UUID 2 to compare
 *
 *  @returns equal
 *
 *  @discussion compareCBUUID compares two CBUUID's to each other and returns YES if they are equal and NO if they are not
 *
 */

-(BOOL) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2 {
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1 length:16];
    [UUID2.data getBytes:b2 length:16];
    return memcmp(b1, b2, UUID1.data.length) == 0;
}

/*
 *  @method CBUUIDToString
 *
 *  @param UUID UUID to convert to string
 *
 *  @returns Pointer to a character buffer containing UUID in string representation
 *
 *  @discussion CBUUIDToString converts the data of a CBUUID class to a character pointer for easy printout using printf()
 *
 */
-(const char *) CBUUIDToString:(CBUUID *) UUID {
    return [[UUID.data description] cStringUsingEncoding:NSStringEncodingConversionAllowLossy];
}

#pragma mark - 设备离线处理
- (void)changeStatusToDisconnect:(BOOL)notification {
    if (self.online) {
        self.online = NO;
        // 1.设置rssi掉线
        _rssi = offlineRSSI;
        // 2.获取最新位置与时间， 并保存
        NSLog(@"保存设备离线信息");
        _coordinate = common.currentLocation;
        _offlineTime = [common getCurrentTime];
        [[DLCloudDeviceManager sharedInstance] updateOfflineInfoWithDevice:self];
        if (notification) {
            if ([self.lastData boolValueForKey:DisconnectAlertKey defaultValue:NO]) {
                // 如果原来是在线状态，再去发送离线通知和声音，提高用户体验, 因为只有获取到服务才认为在线，连接与在线状态不等同
                // 关闭的断开连接通知，则不通知
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
                    NSLog(@"去做掉线通知: %@", self.mac);
                    [common sendLocalNotification:[NSString stringWithFormat:@"%@ disconnects from iPhone.", self.deviceName]];
                }
                self.isOfflineSounding = YES;
                self.isSearchPhone = NO;
                NSLog(@"播放离线音乐");
            }
        }
    }
    
   

//     如果正在查找设备，关闭查找动画
//    _isSearchDevice = NO;
//    [[NSNotificationCenter defaultCenter] postNotificationName:DeviceSearchDeviceAlertNotification object:self userInfo:@{@"device":self}];
    
    // 做完离线处理再做离线通知
    [[NSNotificationCenter defaultCenter] postNotificationName:DeviceOnlineChangeNotification object:@(self.online)];
}

// 关闭蓝牙做离线处理
- (void)bluetoothPoweredOff {
//    if (self.online) {
//        if (!_isGetSearchDeviceAck) { // 关闭蓝牙的时候，肯定接受不到设备的回复，如果按钮有正在查找设备的动画，需要关闭
//            [[NSNotificationCenter defaultCenter] postNotificationName:DeviceGetAckFailedNotification object:nil];
//        }
//    }
    // 去做离线倒计时
    if (self.online && !self.isReconnectTimer) { //当前是在线，需要计时设置为离线
        // 开始重连计时
        [_offlineReconnectTimer setFireDate:[NSDate distantPast]];
        //                    // 激活后台线程 重连超时大于10秒，才需要这两行代码
        self.isReconnectTimer = YES; // 标志开始了重连计时
        [common beginBackgroundTask];
    }
}

- (void)appWasKilled {
    if (self.online) {
        [self changeStatusToDisconnect:NO];
    }
}

#pragma mark - 设备离线位置和时间的处理
- (void)setupCoordinate:(NSString *)gps {
    if ([gps isKindOfClass:[NSString class]]) {
        NSArray *strs = [gps componentsSeparatedByString:@","];
        if (strs.count == 2) {
            NSString *latitude = strs[0];
            NSString *longitude = strs[1];
            _coordinate.latitude = latitude.doubleValue;
            _coordinate.longitude = longitude.doubleValue;
            NSLog(@"_coordinate.latitude = %f, _coordinate.longitude = %f", _coordinate.latitude, _coordinate.longitude);
        }
    }
}

- (NSString *)getGps{
    CLLocationCoordinate2D deviceLocation = _coordinate;
    NSString *gps = [NSString stringWithFormat:@"%lf,%lf", deviceLocation.latitude, deviceLocation.longitude];
    return gps;
}

- (NSString *)offlineTimeInfo {
    if (_online) {
        return @"Last seen just now";
    }
    [self compareOfflineTimer];
    return _offlineTimeInfo;
}

- (NSString *)offlineTime {
    if (!_offlineTime) {
        _offlineTime = [common getCurrentTime];
        return _offlineTime;
    }
    return _offlineTime;
}

- (void)compareOfflineTimer {
    NSDateComponents *comp = [common differentWithDate:self.offlineTime];
    NSInteger year = comp.year;
    NSInteger mouth = comp.month;
    NSInteger day = comp.day;
    NSInteger hour = comp.hour;
    NSInteger minute = comp.minute;
    if (year == 0 && mouth == 0 && day == 0 && hour == 0) {
        _offlineTimeInfo = [NSString stringWithFormat:@"Last seen %zd minutes ago", minute];
        return;
    }
    if (year == 0 && mouth == 0 && day == 0) {
        _offlineTimeInfo = [NSString stringWithFormat:@"Last seen %zd hours %zd minutes ago", hour, minute];
        return;
    }
    day = mouth * 30 + year * 365 + day;
    _offlineTimeInfo = [NSString stringWithFormat:@"Last seen %zd days %zd hours ago", day, hour];
    return;
}

#pragma mark - 查找设备ACK超时处理
- (void)startSearchDeviceTimer {
    _isGetSearchDeviceAck = NO;
    _searchDeviceackDelayTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    __weak typeof(self) weakSelf = self;
    __weak typeof(_searchDeviceackDelayTimer) weakTimer = _searchDeviceackDelayTimer;
    dispatch_source_set_event_handler(_searchDeviceackDelayTimer, ^{
        dispatch_source_cancel(weakTimer);
        [weakSelf checkSearchDeviceAckReuslt];
    });
    // 设置3秒超时
    dispatch_source_set_timer(_searchDeviceackDelayTimer, dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC), 0, 0);
    dispatch_resume(_searchDeviceackDelayTimer);
}

- (void)checkSearchDeviceAckReuslt {
    if (!_isGetSearchDeviceAck) { // 获取ack失败，发出通知
        [[NSNotificationCenter defaultCenter] postNotificationName:DeviceGetAckFailedNotification object:nil];
    }
    [self stopSearchDeviceTimer];
}

- (void)stopSearchDeviceTimer {
    NSLog(@"结束查找设备定时器");
    dispatch_source_cancel(_searchDeviceackDelayTimer);
    _searchDeviceackDelayTimer = nil;
}

#pragma mark - 手机报警
- (void)playSearchPhoneSound {
    NSNumber *phoneAlertMusic = [[NSUserDefaults standardUserDefaults] objectForKey:PhoneAlertMusicKey];
    NSString *alertMusic;
    switch (phoneAlertMusic.integerValue) {
        case 2:
            alertMusic = @"voice2.mp3";
            break;
        case 3:
            alertMusic = @"voice3.mp3";
            break;
        default:
            alertMusic = @"voice1.mp3";
            break;
    }
    NSString *musicPath = [[NSBundle mainBundle] pathForResource:alertMusic ofType:nil];
    NSURL *fileURL = [NSURL fileURLWithPath:musicPath];
    // 设置后台播放代码
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    // 这个进入后台10秒钟后播放没声音
    //    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    // 这个可以在后台播放
    [audioSession setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
    [audioSession setActive:YES error:nil];
    NSError *error = nil;
    self.searchPhonePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&error];
    self.searchPhonePlayer.delegate = self;
    self.searchPhonePlayer.numberOfLoops = 300;
    self.searchPhonePlayer.volume = 1.0;
    [self.searchPhonePlayer play];
    [common startSharkAnimation]; //关闭闪光灯
}

- (void)stopSearchPhoneSound {
    [common stopSharkAnimation]; //打开闪光灯
    if (self.searchPhonePlayer.isPlaying) {
        [self.searchPhonePlayer stop];
    }
}

#pragma mark - 离线提示音
- (void)playOfflineSound {
    if (self.offlinePlayer.isPlaying) {
        return;
    }
    NSNumber *phoneAlertMusic = [[NSUserDefaults standardUserDefaults] objectForKey:PhoneAlertMusicKey];
    NSString *alertMusic;
    switch (phoneAlertMusic.integerValue) {
        case 2:
            alertMusic = @"voice2.mp3";
            break;
        case 3:
            alertMusic = @"voice3.mp3";
            break;
        default:
            alertMusic = @"voice1.mp3";
            break;
    }
    NSString *musicPath = [[NSBundle mainBundle] pathForResource:alertMusic ofType:nil];
    NSURL *fileURL = [NSURL fileURLWithPath:musicPath];
    // 设置后台播放代码
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    // 这个可以在后台播放
    [audioSession setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:nil];
    [audioSession setActive:YES error:nil];
    NSError *error = nil;
    self.offlinePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&error];
    self.offlinePlayer.delegate = self;
    self.offlinePlayer.numberOfLoops = 1;
    self.offlinePlayer.volume = 1.0;
    [self.offlinePlayer play];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void)stopOfflineSound {
    if (self.offlinePlayer.isPlaying) {
        [self.offlinePlayer stop];
    }
}

#pragma mark - Properity
- (void)setPeripheral:(CBPeripheral *)peripheral {
    if ([_peripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) {
        [_peripheral setDelegate:nil];
        _peripheral = peripheral;
        NSLog(@"为设备更换新的peripheral对象: %@", peripheral);
        [peripheral setDelegate:self];
        return;
    }
    self.online = NO;
    NSLog(@"赋值外设，去设备在线状态为离线：mac:%@, 旧的外设对象： %@, 新的外设对象：%@", self.mac, _peripheral, peripheral);
    [_peripheral setDelegate:nil];
    _peripheral = peripheral;
    if (peripheral) {
        [peripheral setDelegate:self];
    }
}

- (NSMutableDictionary *)data {
    if (!_data) {
        _data = [NSMutableDictionary dictionary];
        [self.data setValue:@(0) forKey:ElectricKey];
        [self.data setValue:@(0) forKey:ChargingStateKey];
        [self.data setValue:@(0) forKey:DisconnectAlertKey];
        [self.data setValue:@(0) forKey:ReconnectAlertKey];
        [self.data setValue:@(1) forKey:AlertMusicKey];
        [self.data setValue:@(0) forKey:AlertStatusKey];
    }
    return _data;
}

- (NSDictionary *)lastData {
    return [self.data copy];
}

- (NSString *)deviceName {
    if (_deviceName.length == 0) {
        _deviceName = self.peripheral.name;
    }
    if (_deviceName.length == 0) {
        _deviceName = @"Smart Card Holder";
    }
    return _deviceName;
}

- (void)setOnline:(BOOL)online {
    _online = online;
    if (_online) {
        // 关闭定时器
        _offlineTime = nil; // 初始化时间信息
        // 做设备上线通知 ; // 因为离线通知需要在做完离线处理的时候才能做，跟上线分开
        [[NSNotificationCenter defaultCenter] postNotificationName:DeviceOnlineChangeNotification object:@(self.online)];
    }
}


- (BOOL)connecting {
    if ([DLCentralManager sharedInstance].state != CBCentralManagerStatePoweredOn) {
        return NO;
    }
    if (_peripheral && (_peripheral.state == CBPeripheralStateConnected || _peripheral.state == CBPeripheralStateConnecting)) {
        return YES;
    }
    return NO;
}

- (BOOL)connected {
    if ([DLCentralManager sharedInstance].state != CBCentralManagerStatePoweredOn) {
        return NO;
    }
    if (_peripheral && (_peripheral.state == CBPeripheralStateConnected)) {
        return YES;
    }
    return NO;
}

- (NSMutableArray *)rssiValues {
    if (!_rssiValues) {
        _rssiValues = [NSMutableArray array];
    }
    return _rssiValues;
}

- (void)setIsSearchPhone:(BOOL)isSearchPhone {
    _isSearchPhone = isSearchPhone;
    if (isSearchPhone) {
        [self playSearchPhoneSound];
    }
    else {
        [self stopSearchPhoneSound];
    }
}

- (void)setIsOfflineSounding:(BOOL)isOfflineSounding {
    _isOfflineSounding = isOfflineSounding;
    if (isOfflineSounding) {
        [self playOfflineSound];
    }
    else {
        [self stopOfflineSound];
    }
}

@end
