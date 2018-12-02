//
//  InAlertTableViewController.h
//  Innway
//
//  Created by danly on 2018/8/5.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLDevice.h"

/**
 界面显示类型
 */
typedef NS_ENUM(NSInteger, InAlertViewType) {
    /**
     设备警报
     */
    InDeviceAlert = 0,
    
    /**
     手机警报
     */
    InPhoneAlert = 1
};


@interface InAlertTableViewController : UITableViewController

- (instancetype)initWithAlertType:(InAlertViewType)alertType withDevice:(DLDevice *)device;

@end
