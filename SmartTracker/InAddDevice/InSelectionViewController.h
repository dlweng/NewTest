//
//  InSelectionViewController.h
//  Innway
//
//  Created by danly on 2018/10/1.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface InSelectionViewController : UIViewController

+ (instancetype)selectionViewController:(void (^)(void))comeback;

@end

NS_ASSUME_NONNULL_END
