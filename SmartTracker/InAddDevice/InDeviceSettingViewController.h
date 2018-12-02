//
//  InDeviceSettingViewController.h
//  Innway
//
//  Created by danly on 2018/8/5.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLDevice.h"

@interface InDeviceSettingViewController : UIViewController

@property (nonatomic, strong) DLDevice *device;
+ (instancetype)deviceSettingViewController;

@end
