//
//  InDeviceMenuCell1.m
//  Innway
//
//  Created by danly on 2018/9/2.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import "InDeviceListCell.h"
#import "InCommon.h"

@interface InDeviceListCell ()
@property (weak, nonatomic) IBOutlet UIImageView *alertImageView;
@property (weak, nonatomic) IBOutlet UIImageView *batteryImageView;
@property (weak, nonatomic) IBOutlet UIImageView *rssiView;
@property (weak, nonatomic) IBOutlet UIImageView *cardView;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@end

@implementation InDeviceListCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.deviceSettingBtn.transform = CGAffineTransformRotate(self.deviceSettingBtn.transform, M_PI * 0.5);
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
//        if (batteryImageName.integerValue == 5) {
//            self.batteryImageView.hidden = YES;
//            self.alertImageView.hidden = NO;
//        }
//        else {
//            self.alertImageView.hidden = YES;
//            self.batteryImageView.hidden = NO;
//            [self.batteryImageView setImage:[UIImage imageNamed:batteryImageName]];
//        }
    }
}

- (void)setBeSelected:(BOOL)beSelected {
    _beSelected = beSelected;
    UIColor *color = [UIColor whiteColor];
    if (beSelected) {
        color = [UIColor colorWithRed:80.0/255.0f green:179.0/255.0f blue:122/255.0f alpha:1];
    }
    self.timeLabel.textColor = color;
    self.titleLabel.textColor = color;
}

//- (void)setBeSelected:(BOOL)beSelected {
//    _beSelected = beSelected;
//    if (beSelected) {
//        self.contentView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.7];
//    }
//    else {
//        self.contentView.backgroundColor = [UIColor clearColor];
//    }
//}

@end
