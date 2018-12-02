//
//  InDeviceMenuCell1.h
//  Innway
//
//  Created by danly on 2018/9/2.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLDevice.h"

@class InDeviceListCell;
@protocol InDeviceListCellDelegate<NSObject>
- (void)deviceListCellSettingBtnDidClick:(InDeviceListCell *)cell;
@end
@interface InDeviceListCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIButton *deviceSettingBtn;
@property (nonatomic, strong) DLDevice *device;
@property (nonatomic, assign) BOOL beSelected; // 被选中也没被选中颜色不同
@property (nonatomic, weak) id<InDeviceListCellDelegate> delegate;
@end
