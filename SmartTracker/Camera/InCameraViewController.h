//
//  InCameraViewController.h
//  Camera
//
//  Created by danlypro on 2018/12/8.
//  Copyright © 2018 danlypro. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class InCameraViewController;
@protocol InCameraViewControllerDelegate <NSObject>

- (void)cameraViewControllerDidClickGoBack:(InCameraViewController *)vc;
// 在相机和相册页面之间切换的时候调用， YES:进入相册界面  NO:进入相机界面
- (void)cameraViewControllerDidChangeToLibrary:(BOOL)isLibrary;

@end

@interface InCameraViewController : UIViewController

@property (nonatomic, weak) id<InCameraViewControllerDelegate> delegate;
- (void)takeAPhoto;

@end

NS_ASSUME_NONNULL_END
