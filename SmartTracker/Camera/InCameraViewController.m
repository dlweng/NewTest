//
//  InCameraViewController.m
//  Camera
//
//  Created by danlypro on 2018/12/8.
//  Copyright © 2018 danlypro. All rights reserved.
//

#import "InCameraViewController.h"
#import "LLSimpleCamera.h"
#import "LibraryViewController.h"
#import "InCommon.h"

@interface InCameraViewController()<LibraryViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *cameraBodyView;
@property (weak, nonatomic) IBOutlet UIButton *flashBtn;

@property (weak, nonatomic) IBOutlet UIButton *changeCameraBtn;
@property (strong, nonatomic) LLSimpleCamera *camera;

@end

@implementation InCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.camera = [[LLSimpleCamera alloc] initWithQuality:AVCaptureSessionPresetHigh
                                                 position:LLCameraPositionRear
                                             videoEnabled:NO];
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
     [self.camera attachToViewController:self view:self.cameraBodyView withFrame:CGRectMake(0, 0, screenSize.width, screenSize.height-93)];
    self.camera.fixOrientationAfterCapture = NO;
    self.camera.tapToFocus = NO;
    __weak typeof(self) weakSelf = self;
    [self.camera setOnDeviceChange:^(LLSimpleCamera *camera, AVCaptureDevice * device) {
        //进入拍照界面的时候，会先回调这里
        NSLog(@"前后摄像头切换");
        if([camera isFlashAvailable]) {
            weakSelf.flashBtn.hidden = NO;
            if(camera.flash == LLCameraFlashOff) {
                weakSelf.flashBtn.selected = NO;
            }
            else {
                weakSelf.flashBtn.selected = YES;
            }
        }
        else {
            weakSelf.flashBtn.hidden = YES;
        }
    }];
    
    [self.camera setOnError:^(LLSimpleCamera *camera, NSError *error) {
        NSLog(@"捕捉到错误: error = %@", error);
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.camera start];
}

- (void)image:(UIImage *)image didFinishSaveImageWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSLog(@"保存图片结果: image = %@, error = %@, contextInfo = %@", image, error, contextInfo);
}

- (IBAction)flashBtnDidClick {
    NSLog(@"闪光灯");
    if(self.camera.flash == LLCameraFlashOff) {
        BOOL done = [self.camera updateFlashMode:LLCameraFlashOn];
        if(done) {
            self.flashBtn.selected = YES;
            self.flashBtn.tintColor = [UIColor whiteColor];
        }
    }
    else {
        BOOL done = [self.camera updateFlashMode:LLCameraFlashOff];
        if(done) {
            self.flashBtn.selected = NO;
            self.flashBtn.tintColor = [UIColor grayColor];
        }
    }
}

- (IBAction)changeCamera {
    NSLog(@"切换镜头方向");
    if([LLSimpleCamera isFrontCameraAvailable] && [LLSimpleCamera isRearCameraAvailable])  {
        [self.camera togglePosition];
    }
}


- (IBAction)goToLibrary {
    NSLog(@"进入相册");
    LibraryViewController *libraryVC = [[LibraryViewController alloc] init];
    libraryVC.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:libraryVC];
    
    // 设置状态栏和导航栏  设置状态栏是因为在IPhone5s上状态栏会消失
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [InCommon setNavgationBar:nav.navigationBar];
    NSMutableDictionary *titleTextAttributes = [NSMutableDictionary dictionary];
    titleTextAttributes[NSForegroundColorAttributeName] = [UIColor whiteColor];
    nav.navigationBar.titleTextAttributes = titleTextAttributes;
    nav.navigationBar.tintColor = [UIColor whiteColor];
    
    
    [self presentViewController:nav animated:YES completion:nil];
    // 界面切换要回调
    if ([self.delegate respondsToSelector:@selector(cameraViewControllerDidChangeToLibrary:)]) {
        [self.delegate cameraViewControllerDidChangeToLibrary:YES];
    }
}

- (IBAction)takePhoto {
    NSLog(@"拍照");
    [self takeAPhoto];
}


- (IBAction)goBackAction {
    NSLog(@"返回");
    if ([self.delegate respondsToSelector:@selector(cameraViewControllerDidClickGoBack:)]) {
        [self.delegate cameraViewControllerDidClickGoBack:self];
    }
}

- (void)libraryViewControllerDidClickGoBack:(LibraryViewController *)vc {
    [vc dismissViewControllerAnimated:YES completion:nil];
    if ([self.delegate respondsToSelector:@selector(cameraViewControllerDidChangeToLibrary:)]) {
        [self.delegate cameraViewControllerDidChangeToLibrary:NO];
    }
}

- (void)takeAPhoto {
    [self.camera capture:^(LLSimpleCamera *camera, UIImage *image, NSDictionary *metadata, NSError *error) {
        NSLog(@"获取照片, image = %@, metadata = %@, error = %@", image, metadata, error);
        if(!error) {
            // 相机拍完照进入保存
            UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSaveImageWithError:contextInfo:), (__bridge void *)self);
        }
        else {
            NSLog(@"An error has occured: %@", error);
        }
    } exactSeenImage:YES];
}

@end
