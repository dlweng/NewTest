//
//  NSTimer+InTimer.h
//  Innway
//
//  Created by danlypro on 2018/12/7.
//  Copyright © 2018 innwaytech. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTimer (InTimer)

+ (NSTimer *)newTimerWithTimeInterval:(NSTimeInterval)inerval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block;

@end

NS_ASSUME_NONNULL_END
