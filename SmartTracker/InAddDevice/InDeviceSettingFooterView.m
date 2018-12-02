//
//  InDeviceSettingFooterView.m
//  Innway
//
//  Created by danly on 2018/10/13.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import "InDeviceSettingFooterView.h"
#import "InCommon.h"

@interface InDeviceSettingFooterView ()

@end

@implementation InDeviceSettingFooterView

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!self.deleteBtn) {
        self.deleteBtn = [[UIButton alloc] init];
        [InCommon setUpWhiteStyleButton:self.deleteBtn];
        self.deleteBtn.bounds = CGRectMake(0, 0, 220, 44);
        [self.contentView addSubview:self.deleteBtn];
        self.deleteBtn.center = self.contentView.center;
        [self.deleteBtn setTitle:@"Delete device" forState:UIControlStateNormal];
    }
}

@end
