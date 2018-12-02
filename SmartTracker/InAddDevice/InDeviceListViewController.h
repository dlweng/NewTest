//
//  InDeviceMenuViewController.h
//  Innway
//
//  Created by danly on 2018/8/5.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import <UIKit/UIKit.h>

@class InDeviceListViewController;
@class DLDevice;
@protocol InDeviceListViewControllerDelegate<NSObject>
- (void)deviceListViewController:(InDeviceListViewController *)menuVC didSelectedDevice:(DLDevice *)device;
- (void)deviceListViewControllerDidSelectedToAddDevice:(InDeviceListViewController *)menuVC;
- (void)deviceListViewController:(InDeviceListViewController *)menuVC moveDown:(BOOL)down;
- (void)deviceSettingBtnDidClick:(DLDevice *)device;
@end

@interface InDeviceListViewController : UIViewController

+ (instancetype)deviceListViewController;
- (void)reloadView;

// 控制界面当前选中的设备
@property (nonatomic, strong) DLDevice *selectDevice;
@property (nonatomic, weak) id<InDeviceListViewControllerDelegate> delegate;
// YES: 标识能向下移动， NO:表示能向上移动
@property (nonatomic, assign) BOOL down;

@end
