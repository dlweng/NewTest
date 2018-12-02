//
//  DLUUIDTool.m
//  Bluetooth
//
//  Created by danly on 2018/8/18.
//  Copyright © 2018年 date. All rights reserved.
//

#import "DLUUIDTool.h"

@implementation DLUUIDTool

+ (CBUUID *)CBUUIDFromInt:(int)UUID {
    /*char t[16];
     t[0] = ((UUID >> 8) & 0xff); t[1] = (UUID & 0xff);
     NSData *data = [[NSData alloc] initWithBytes:t length:16];
     return [CBUUID UUIDWithData:data];
     */
    UInt16 cz = [DLUUIDTool swap:UUID];
    NSData *cdz = [[NSData alloc] initWithBytes:(char *)&cz length:2];
    CBUUID *cuz = [CBUUID UUIDWithData:cdz];
    return cuz;
}

/*!
 *  @method swap:
 *
 *  @param s Uint16 value to byteswap
 *
 *  @discussion swap byteswaps a UInt16
 *
 *  @return Byteswapped UInt16
 */

+ (UInt16) swap:(UInt16)s {
    UInt16 temp = s << 8;
    temp |= (s >> 8);
    return temp;
}



@end
