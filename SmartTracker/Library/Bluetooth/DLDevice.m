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
#import "DLCloudDeviceManager.h"

// 设置离线的RSSI值
#define offlineRSSI @(-120)

// 设置重连超时  重连超时时间一定要为连接超时时间的倍数
#define reconnectTimeOut 9  // 实际的超时时间是reconnectTimeOut - 1
#define connectTimerOut 4 // 去连接设备5秒没连上认为超时

@interface DLDevice() {
    NSNumber *_rssi;
    dispatch_source_t _searchDeviceackDelayTimer;// 查找设备ack回复计时器
    dispatch_source_t _disciverServerTimer;// 获取写数据特征值计时器
    BOOL _disConnect; // 标识用户主动断开了设备连接，不做重连
    dispatch_source_t _connectTimer;// 计算连接超时的计时器
    
    NSTimer *_offlineReconnectTimer; //断开重连计时器
    int _offlineReconnectTime; //计算从断开到重连的时间
    int _connectHandler; //连接计数
}

@property (nonatomic, assign) BOOL isGetSearchDeviceAck; // 标识下发查找设备命令得到ack否
@property (nonatomic, assign) BOOL isDiscoverServer; //标志是否获取到写数据特征值

// 保存设置的值，等ack回来之后更新本地数据
@property (nonatomic, assign) BOOL disconnectAlert;
@property (nonatomic, assign) BOOL reconnectAlert;
@property (nonatomic, assign) NSInteger alertMusic;
@property (nonatomic, strong) NSMutableDictionary *data;
@property (nonatomic, strong) NSMutableArray *rssiValues; // 更新RSSI逻辑，1秒获取一次RSSI，3秒更新一次UI，将3秒钟获取到的3次RSSI的最大值通知到界面
@end

@implementation DLDevice

+ (instancetype)device:(CBPeripheral *)peripheral {
    DLDevice *device = [[DLDevice alloc] init];
    device.peripheral = peripheral;
    
    // 增加断开连接监听
    [[NSNotificationCenter defaultCenter] addObserver:device selector:@selector(reconnectDevice:) name:DeviceDisconnectNotification object:nil];
    // 蓝牙关闭监听
    [[NSNotificationCenter defaultCenter] addObserver:device selector:@selector(bluetoothPoweredOff) name:BluetoothPoweredOffNotification object:nil];
    return device;
}

- (instancetype)init {
    if (self = [super init]) {

        _disConnect = NO;
        _isGetSearchDeviceAck = NO;
        
        // 初始化断开重连计时器数据
        _offlineReconnectTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(offlineTiming) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_offlineReconnectTimer forMode:NSRunLoopCommonModes];
        // 加到主循环的定时器会自动被触发，需要先关闭定时器
        [_offlineReconnectTimer setFireDate:[NSDate distantFuture]];
        _offlineReconnectTime = 0;
        
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceDisconnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BluetoothPoweredOffNotification object:nil];
}

#pragma mark - 获取特征值的处理
- (void)discoverServices {
    if (_peripheral) {
        NSLog(@"去获取设备服务:%@", self.mac);
        CBUUID *serviceUUID = [DLUUIDTool CBUUIDFromInt:DLServiceUUID];
        [_peripheral discoverServices:@[serviceUUID]];
        self.isDiscoverServer = NO;
        [self startDiscoverServerTimer];
    }
    else {
        NSLog(@"无法去获取设备服务:%@, 外设不存在", self.mac);
    }
}

- (void)startDiscoverServerTimer {
    _disciverServerTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    __weak typeof(_disciverServerTimer) weakTimer = _disciverServerTimer;
    dispatch_source_set_event_handler(_disciverServerTimer, ^{
        dispatch_source_cancel(weakTimer);
        if (!self.isDiscoverServer) {
            // 如果连接上设备去获取特征值超过5秒没查找到，断开重新连接设备
            [self disConnectAndReconnectDevice:nil];
        }
        NSLog(@"发现服务定时器超时被执行");
    });
    // 设置5秒超时
    dispatch_source_set_timer(_disciverServerTimer, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC), 0, 0);
    dispatch_resume(_disciverServerTimer);
}

- (void)peripheral:(CBPeripheral *)_peripheral didDiscoverServices:(NSError *)error {
    NSArray *services = [_peripheral services];
    CBUUID *serverUUID = [DLUUIDTool CBUUIDFromInt:DLServiceUUID];
    for (CBService *service in services) {
        if ([service.UUID.UUIDString isEqualToString:serverUUID.UUIDString]) {
//            NSLog(@"发现服务0xE001");
            CBUUID *ntfUUID = [DLUUIDTool CBUUIDFromInt:DLNTFCharacteristicUUID];
            CBUUID *writeUUID = [DLUUIDTool CBUUIDFromInt:DLWriteCharacteristicUUID];
            [self.peripheral discoverCharacteristics:@[ntfUUID, writeUUID] forService:service];
        }
    }
}

- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    CBUUID *ntfUUID = [DLUUIDTool CBUUIDFromInt:DLNTFCharacteristicUUID];
    CBUUID *writeUUID = [DLUUIDTool CBUUIDFromInt:DLWriteCharacteristicUUID];
    NSArray *characteristics = [service characteristics];
    for (CBCharacteristic *characteristic in characteristics) {
        if ([characteristic.UUID.UUIDString isEqualToString:writeUUID.UUIDString]) {
            [self.peripheral readRSSI]; // 先读一次信号值，显示到UI，优化用户体验
            self.isDiscoverServer = YES;
            self.online = YES;  //设置在线
            NSLog(@"去激活设备: %@", _mac);
            [self activeDevice];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self getDeviceInfo]; //防止两次发生时间太接近，导致下发失败
            });
            
        }
        if ([characteristic.UUID.UUIDString isEqualToString:ntfUUID.UUIDString]) {
//            NSLog(@"发现E003, 打开监听来自设备通知的功能");
            [self notification:DLServiceUUID characteristicUUID:DLNTFCharacteristicUUID p:self.peripheral on:YES];
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
    if (self.online) {
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
        self.rssi = RSSI;
    }
}

#pragma mark - 写数据快捷接口
- (void)activeDevice {
    char active[1] = {0x01};
    [self write:[NSData dataWithBytes:active length:1]];
}

- (void)getDeviceInfo {
    if (!self.isDiscoverServer) {
        return;
    }
    char getDeviceInfo[4] = {0xEE, 0x01, 0x00, 0x00};
    NSLog(@"mac = %@, 去获取设备硬件数据， %@", self.mac, [NSData dataWithBytes:getDeviceInfo length:4]);
    [self write:[NSData dataWithBytes:getDeviceInfo length:strlen(getDeviceInfo)]];
}

- (void)searchDevice {
    char search[4] = {0xEE, 0x03, 0x00, 0x00};
    [self write:[NSData dataWithBytes:search length:4]];
}

- (void)searchPhoneACK {
    NSLog(@"回应设备:%@ 的查找数据", _mac);
    char search[4] = {0xEE, 0x06, 0x00, 0x00};
    [self write:[NSData dataWithBytes:search length:4]];
}

- (void)setDisconnectAlert:(BOOL)disconnectAlert reconnectAlert:(BOOL)reconnectAlert {
    self.disconnectAlert = disconnectAlert;
    self.reconnectAlert = reconnectAlert;
    int disconnect = disconnectAlert? 0x01 : 0x00;
    int reconnect = reconnectAlert? 0x01: 0x00;
    char command[] = {0xEE, 0x07, 0x02, disconnect, reconnect, 0x00};
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
    //校验和
//    NSString *cs = [dataStr substringWithRange:NSMakeRange(7+length.integerValue*2, 2)];
//    NSLog(@"cmd = %@, length = %@, payload = %@, cs = %@", cmd, length, payload, cs);
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
//    [self readData];
}

//- (void)readData {
//    if (self.peripheral) {
//        [self readValue:DLServiceUUID characteristicUUID:DLNTFCharacteristicUUID p:self.peripheral];
//    }
//    else {
//        NSLog(@"mac:%@, 查找不到外设，无法读数据", self.mac);
//    }
//}

//-(void) readValue: (int)serviceUUID characteristicUUID:(int)characteristicUUID p:(CBPeripheral *)p {
//    CBUUID *su = [DLUUIDTool CBUUIDFromInt:serviceUUID];
//    CBUUID *cu = [DLUUIDTool CBUUIDFromInt:characteristicUUID];
//    CBService *service = [self findServiceFromUUID:su p:p];
//    if (!service) {
//        NSLog(@"mac:%@, 读数据查找不到服务: %s", self.mac, [self CBUUIDToString:su]);
//        return;
//    }
//    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:cu service:service];
//    if (!characteristic) {
//        NSLog(@"mac:%@, 读数据查找不到角色: %s", self.mac, [self CBUUIDToString:cu]);
//        return;
//    }
//    [p readValueForCharacteristic:characteristic];
//}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if ([peripheral.identifier.UUIDString isEqualToString:self.peripheral.identifier.UUIDString]) {
        NSLog(@"mac:%@, 接收读响应数据, peripheral：%@,  characteristic = %@, error = %@", self.mac, self.peripheral, characteristic.value, error);
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
    _disConnect = NO; // 重新设置断开连接的标识
    __block NSNumber *isCallback; // 标识是否已经被回调
    if (!self.peripheral) {
        NSError *error = [NSError errorWithDomain:NSStringFromClass([DLCentralManager class]) code:-2 userInfo:@{NSLocalizedDescriptionKey: @"与设备建立连接失败"}];
        if (completion) {
            completion(self, error);
        }
        return;
    }
    if (self.peripheral.state == CBPeripheralStateConnecting) {
        [self disConnectToDevice:^(DLDevice *device, NSError *error) {
            
        }];
    }
    if (self.peripheral.state == CBPeripheralStateDisconnected || self.peripheral.state == CBPeripheralStateDisconnecting) {
        _connectHandler++;
        NSLog(@"开始去连接设备:%@, 连接计数:%d", self.mac, _connectHandler);
        [[DLCentralManager sharedInstance] connectToDevice:self.peripheral completion:^(DLCentralManager *manager, CBPeripheral *peripheral, NSError *error) {
            NSLog(@"设备连接结果： %@, 线程:%@", self.mac, [NSThread currentThread]);
            self->_connectHandler--;
            if (!error) {
                NSLog(@"连接设备成功:%@, 连接计数:%d", self.mac, self->_connectHandler);
                // 连接成功，去获取设备服务
                peripheral.delegate = self;
                [self discoverServices];
                if (completion) {
                    completion(self, nil);
                }
                isCallback = @(YES);
                return ;
            }
            else {
                if (self->_offlineReconnectTime > 0 && self->_offlineReconnectTime <= reconnectTimeOut && self->_connectHandler == 0) {
                    NSLog(@"连接失败，在重连超时时间内，重新去连接: %@", self.mac);
                    // 在重连超时时间内，去做重连
                    [self disConnectAndReconnectDevice:nil];
                }
                else {
                    NSLog(@"连接失败: %@, error = %@, 连接计数:%d", self.mac, error, self->_connectHandler);
                    if (completion) {
                        completion(self, error);
                    }
                    isCallback = @(YES);
                }
            }
        }];
        
        // 开启连接计时器, 超时没连接上认为连接失败
        _connectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        __weak typeof(_connectTimer) weakTimer = _connectTimer;
        dispatch_source_set_event_handler(_connectTimer, ^{
            dispatch_source_cancel(weakTimer);
            if (!isCallback.boolValue) { //没被回调，才进入这里
                self->_connectHandler--;
                NSError *error = [NSError errorWithDomain:NSStringFromClass([self class]) code:-1 userInfo:nil];
                if (completion) {
                    completion(self, error);
                }
                if (self->_offlineReconnectTime > 0 && self->_offlineReconnectTime <= reconnectTimeOut && self->_connectHandler == 0) {
                    NSLog(@"连接设备超时，在重连超时时间内，去重连设备: %@", self.mac);
                    // 在重连超时时间内，去做重连
                    [self disConnectAndReconnectDevice:nil];
                }
                else {
                    NSLog(@"连接设备超时，不在重连超时时间内，去回调 %@, error = %@, 连接计数: %d", self.mac, error, self->_connectHandler);
                    if (self->_connectHandler == 0) {
                        [self disConnectToDevice:nil];
                    }
                    if (completion) {
                        completion(self, error);
                    }
                }
            }
            else {
                NSLog(@"过了连接超时时间，已经连接上设备: %@", self.mac);
            }
        });
        // 设置5秒超时
        dispatch_source_set_timer(_connectTimer, dispatch_time(DISPATCH_TIME_NOW, connectTimerOut*NSEC_PER_SEC), 0, 0);
        dispatch_resume(_connectTimer);
    }
    else {
        if (completion) {
            completion(self, nil);
        }
    }
}

- (void)disConnectToDevice:(void (^)(DLDevice *device, NSError *error))completion {
    _disConnect = YES;
    if (!self.peripheral) {
        // 不存在外设，当成断开设备连接成功
        if (completion) {
            completion(self, nil);
        }
        return;
    }
    NSLog(@"开始去断开设备连接:%@", self.mac);
    [[DLCentralManager sharedInstance] disConnectToDevice:self.peripheral completion:^(DLCentralManager *manager, CBPeripheral *peripheral, NSError *error) {
        if (completion) {
            completion(self, error);
        }
    }];
}

// 获取不到服务的情况下，必须断开重连
- (void)disConnectAndReconnectDevice:(void (^)(DLDevice *device, NSError *error))completion {
    _disConnect = YES;
    if (self.peripheral) {
        NSLog(@"开始去断开设备连接:%@", self.mac);
        if (self.connected) {
            [[DLCentralManager sharedInstance] disConnectToDevice:self.peripheral completion:^(DLCentralManager *manager, CBPeripheral *peripheral, NSError *error) {
                dispatch_async(dispatch_queue_create(0, 0), ^{
                    [self connectToDevice:^(DLDevice *device, NSError *error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (completion) {
                                completion(device, error);
                            }
                        });
                    }];
                });
            }];
        }
        else {
            dispatch_async(dispatch_queue_create(0, 0), ^{
                [self connectToDevice:^(DLDevice *device, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) {
                            completion(device, error);
                        }
                    });
                }];
            });
            
        }
    }
    else {
        if (completion) {
            completion(self, nil); //不存在外设的情况不处理
        }
    }
}

- (void)reconnectDevice:(NSNotification *)notification {
    CBPeripheral *peripheral = notification.object;
    if ([peripheral.identifier.UUIDString isEqualToString:self. peripheral.identifier.UUIDString]) {
        if (!_disConnect)
        {
            // 只处理被动断连的离线
            // 删除和重连的时候才会做主动离线
            // 删除的主动离线，在删除接口做了离线赋值
            // 重连的主动离线本身就是被动断连触发的，由被动断连去做离线处理
            // 获取服务超时的主动断连，由于还未被赋值为在线，不需要去重新赋值为离线
            if ([DLCentralManager sharedInstance].state == CBCentralManagerStatePoweredOn) {
                //被动的掉线且蓝牙打开，去做重连
                NSLog(@"设备连接被断开，去重连设备, mac = %@, 线程 = %@", self.mac, [NSThread currentThread]);
                // 去重连设备
                self.isDiscoverServer = NO;
                
                // 开始重连计时
                [_offlineReconnectTimer setFireDate:[NSDate distantPast]];
                
//                // 激活后台线程 重连超时大于10秒，才需要这两行代码
//                self.isReconnectTimer = YES; // 标志开始了重连计时
//                [common beginBackgroundTask];
                
                // 去连接设备
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
                // 做离线处理
                [self changeStatusToDisconnect];
            }
        }
    }
}

// 计算重连时间
- (void)offlineTiming {
    _offlineReconnectTime++;
    NSLog(@"重连时间: %d", _offlineReconnectTime);
    if (_offlineReconnectTime >= reconnectTimeOut) {
        // 重连超时结束
        _offlineReconnectTime = 0;
        // 停止计时器，去报设备离线
        [_offlineReconnectTimer setFireDate:[NSDate distantFuture]];
        NSLog(@"重连超时时间已到, 线程:%@", [NSThread currentThread]);
        if (!self.isDiscoverServer) {
            // 到超时时间还没重连上，判断设备为离线
            NSLog(@"重连超时，还没连上设备, mac = %@", self.mac);
            [self changeStatusToDisconnect];
        }
        else {
            NSLog(@"重连超时，已经连上设备, mac = %@", self.mac);
        }
//        // 标志计时结束， 重连超时时间大于10秒，才需要这两行代码
//        self.isReconnectTimer = NO;
//        [common endBackgrondTask];
    }
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
- (void)changeStatusToDisconnect{
    BOOL oldOnline = self.online; // 保存旧的在线状态
    NSLog(@"self.mac = %@, 设备离线，去做离线处理, 旧的在线状态：%d", self.mac, oldOnline);
    self.online = NO;
    _rssi = offlineRSSI;  // 1.设置rssi掉线
    // 2.获取最新位置与时间， 并保存
    _coordinate = common.currentLocation;
    _offlineTime = [common getCurrentTime];
    [[DLCloudDeviceManager sharedInstance] updateOfflineInfoWithDevice:self];
    if ([self.lastData boolValueForKey:DisconnectAlertKey defaultValue:NO]) {
        if (oldOnline) { // 如果原来是在线状态，再去发送离线通知和声音，提高用户体验, 因为只有获取到服务才认为在线，连接与在线状态不等同
            // 关闭的断开连接通知，则不通知
            if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
                NSLog(@"去做掉线通知: %@", self.mac);
                [common sendLocalNotification:[NSString stringWithFormat:@"%@ 已断开连接", self.deviceName]];
            }
            [common playSound];
        }
    }
    else {
#warning 测试使用
        if (oldOnline) { // 如果原来是在线状态，再去发送离线通知和声音，提高用户体验, 因为只有获取到服务才认为在线，连接与在线状态不等同
            // 关闭的断开连接通知，则不通知
            if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
                NSLog(@"去做掉线通知: %@", self.mac);
                [common sendLocalNotification:[NSString stringWithFormat:@"%@ 已断开连接", self.deviceName]];
                [common playSound];
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
    if (self.online) {
        [self changeStatusToDisconnect];
        
        if (!_isGetSearchDeviceAck) { // 关闭蓝牙的时候，肯定接受不到设备的回复，如果按钮有正在查找设备的动画，需要关闭
            [[NSNotificationCenter defaultCenter] postNotificationName:DeviceGetAckFailedNotification object:nil];
        }
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
    else {
        [self compareOfflineTimer];
    }
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
    NSInteger second = comp.second;
    if (year == 0 && mouth == 0 && day == 0 && hour == 0 && minute == 0) {
        _offlineTimeInfo = [NSString stringWithFormat:@"Last seen %zd second ago", second];
        return;
    }
    if (year == 0 && mouth == 0 && day == 0 && hour == 0) {
        _offlineTimeInfo = [NSString stringWithFormat:@"Last seen %zd minutes %zd seconds ago", minute ,second];
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


#pragma mark - Properity
- (void)setPeripheral:(CBPeripheral *)peripheral {
    if ([_peripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) {
        // 已经赋值过的设备不需要重新设置
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
    if (_deviceName.length == 0 || [_deviceName isEqualToString:@"Lily"] || [_deviceName isEqualToString:@"Innway Card"]) {
        _deviceName = @"Card Holder";
        
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

- (BOOL)connected {
    if ([DLCentralManager sharedInstance].state != CBCentralManagerStatePoweredOn) {
        return NO;
    }
    if (_peripheral && (_peripheral.state == CBPeripheralStateConnected || _peripheral.state == CBPeripheralStateConnecting)) {
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

@end
