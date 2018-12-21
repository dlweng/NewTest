//
//  NSTimer+InTimer.m
//  Innway
//
//  Created by danlypro on 2018/12/7.
//  Copyright © 2018 innwaytech. All rights reserved.
//

#import "NSTimer+InTimer.h"

@implementation NSTimer (InTimer)

+ (NSTimer *)newTimerWithTimeInterval:(NSTimeInterval)inerval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block {
    return [NSTimer timerWithTimeInterval:inerval target:self selector:@selector(sgl_blcokInvoke:) userInfo:[block copy] repeats:repeats];
}

+ (void)sgl_blcokInvoke:(NSTimer *)timer {
    
    void (^block)(NSTimer *timer) = timer.userInfo;
    
    if (block) {
        block(timer);
    }
}
@end
