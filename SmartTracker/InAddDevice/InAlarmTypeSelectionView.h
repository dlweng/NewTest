//
//  InAlarmTypeSelectionView.h
//  Innway
//
//  Created by danly on 2018/10/20.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLDevice.h"

NS_ASSUME_NONNULL_BEGIN
/**
 界面显示类型
 */
typedef NS_ENUM(NSInteger, InAlarmType) {
    /**
     设备警报
     */
    InDeviceAlert = 0,
    
    /**
     手机警报
     */
    InPhoneAlert = 1
};

typedef void (^alarmCompletionHanler)(NSInteger newAlertVoice);
@interface InAlarmTypeSelectionView : UIView

+ (void)showAlarmTypeSelectionView:(InAlarmType)alarmType title:(NSString *)title currentAlarmVoice:(NSInteger)currentAlarmVoice confirmHanler:(alarmCompletionHanler)confirmHanler;

@end

NS_ASSUME_NONNULL_END
