//
//  InChangeDeviceNameView.h
//  Innway
//
//  Created by danly on 2018/10/20.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^completionHanler)(NSString *newDeviceName);
@interface InChangeDeviceNameView : UIView

+ (void)showChangeDeviceNameView:(NSString *)deviceName confirmHandle:(completionHanler)confirmHandle;

@end

NS_ASSUME_NONNULL_END
