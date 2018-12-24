//
//  InDeviceMenuCell1.m
//  Innway
//
//  Created by danly on 2018/9/2.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import "InDeviceListCell.h"
#import "InCommon.h"
#import "DLCloudDeviceManager.h"

@interface InDeviceListCell ()
@property (weak, nonatomic) IBOutlet UIImageView *alertImageView;
@property (weak, nonatomic) IBOutlet UIImageView *batteryImageView;
@property (weak, nonatomic) IBOutlet UIImageView *rssiView;
@property (weak, nonatomic) IBOutlet UIImageView *cardView;
@property (weak, nonatomic) IBOutlet UIView *bgView;


@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIButton *moreBtn;

@end

@implementation InDeviceListCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.deviceSettingBtn.transform = CGAffineTransformRotate(self.deviceSettingBtn.transform, M_PI * 0.5);
    self.moreBtn.layer.transform = CATransform3DRotate(self.moreBtn.layer.transform, M_PI * 0.5, 0, 0, 1);
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

}

- (IBAction)deviceSettingDidClick:(id)sender {
    if ([self.delegate respondsToSelector:@selector(deviceListCellSettingBtnDidClick:)]) {
        [self.delegate deviceListCellSettingBtnDidClick:self];
    }
}

- (void)setDevice:(DLDevice *)device {
    _device = device;
    [self updateBattery:device];
    self.rssiView.image = [UIImage imageNamed:[[InCommon sharedInstance] getImageName:device.rssi]];
    self.titleLabel.text = device.deviceName;
    if (device.type == InDeviceSmartCardHolder) {
        self.cardView.image = [UIImage imageNamed:@"SmartCardHolder"];
    }
    else if (device.type == InDeviceSmartCard) {
        self.cardView.image = [UIImage imageNamed:@"SmartCard"];
    }
    self.timeLabel.text = device.offlineTimeInfo;
}

- (void)updateBattery:(DLDevice *)device {
    if (!device.online) {
        //设备掉线，不显示电池电量
        self.batteryImageView.hidden = YES;
        self.alertImageView.hidden = YES;
        return;
    }
    if (device.lastData.count > 0) {
        NSString *batteryImageName = @"charge";
        NSInteger charge = [device.lastData integerValueForKey:ChargingStateKey defaultValue:0];
        if (!charge) {
            NSInteger battery = [device.lastData integerValueForKey:ElectricKey defaultValue:0];
//            NSLog(@"去设置设备的电量图片： %zd, %@", battery, device.mac);
            if (battery > 90) {
                batteryImageName = @"100";
            }
            else if (battery > 80) {
                batteryImageName = @"90";
            }
            else if (battery > 70) {
                batteryImageName = @"80";
            }
            else if (battery > 60) {
                batteryImageName = @"70";
            }
            else if (battery > 50) {
                batteryImageName = @"60";
            }
            else if (battery > 40) {
                batteryImageName = @"50";
            }
            else if (battery > 30) {
                batteryImageName = @"40";
            }
            else if (battery > 20) {
                batteryImageName = @"30";
            }
            else if (battery > 10) {
                batteryImageName = @"20";
            } else if(battery > 0){
                batteryImageName = @"10";
            } else if(battery == 0){
                batteryImageName = @"0";
            }
        }
        self.batteryImageView.hidden = NO;
         [self.batteryImageView setImage:[UIImage imageNamed:batteryImageName]];
    }
}

- (void)setBeSelected:(BOOL)beSelected {
    NSArray *deviceList = [[DLCloudDeviceManager sharedInstance].cloudDeviceList copy];
    _beSelected = beSelected;
    UIColor *color = [UIColor clearColor];
    if (beSelected && deviceList.count > 1) {
        color = [UIColor colorWithRed:164.0/255.0 green:164.0/255.0 blue:164.0/255.0 alpha:0.5];
    }
    self.bgView.backgroundColor = color;
}


@end
