//
//  DLUUIDTool.h
//  Bluetooth
//
//  Created by danly on 2018/8/18.
//  Copyright © 2018年 date. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#define DLDeviceMAC   0xD888
#define DLServiceUUID 0xE001
#define DLWriteCharacteristicUUID 0xE002
#define DLNTFCharacteristicUUID 0xE003

@interface DLUUIDTool : NSObject

+ (CBUUID *)CBUUIDFromInt:(int)UUID;

@end
