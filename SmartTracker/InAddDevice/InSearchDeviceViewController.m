//
//  InSearchDeviceViewController.m
//
//  Created by danly on 2018/10/1.
//  Copyright © 2018年 . All rights reserved.
//

#import "InSearchDeviceViewController.h"
#import "InControlDeviceViewController.h"
#import "DLCloudDeviceManager.h"
#import "DLCentralManager.h"
#import "InCommon.h"
#import "NSTimer+InTimer.h"


/**
 界面显示类型
 */
typedef NS_ENUM(NSInteger, InSearchViewType) {
    InSearch = 0,
    InSuccess = 1,
    InFailed = 2
};

@interface InSearchDeviceViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *waiting1;
@property (weak, nonatomic) IBOutlet UIImageView *waiting2;
@property (weak, nonatomic) IBOutlet UIImageView *waiting3;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *confirmBtnTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topOptionViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *phoneOptionViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageBodyViewHeightConstraing;

@property (nonatomic, assign) InSearchViewType type;
@property (weak, nonatomic) IBOutlet UIButton *confirmBtn;
@property (weak, nonatomic) IBOutlet UIView *searchBodyView;
@property (weak, nonatomic) IBOutlet UIView *successBodyView;
@property (weak, nonatomic) IBOutlet UIView *failedBodyView;
@property (weak, nonatomic) IBOutlet UILabel *tryAagainLabel;
@property (weak, nonatomic) IBOutlet UIView *phoneBodyView;
@property (weak, nonatomic) IBOutlet UIImageView *successCardImageView;
@property (weak, nonatomic) IBOutlet UIImageView *failedCardImageView;
@property (weak, nonatomic) IBOutlet UIImageView *searchCardImageView;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *sucessCardWidthConstrain;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *failedCardWidthConstrain;
@property (weak, nonatomic) IBOutlet UILabel *successMessageLabel;
@property (weak, nonatomic) IBOutlet UILabel *failedMessageLabel;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *successbodyViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *failedBodyViewHeightConstraint;


@property (nonatomic, strong) NSTimer *searchAnimationTimer;
@property (nonatomic, copy) NSString *findDeviceMac;
@property (nonatomic, strong) void(^comeback)(void);

/**
 动画的显示标识
 0：隐藏所有搜索图标
 1：显示第一个搜索图标
 2：显示前两个个搜索图标
 3：显示全部搜索图标
 */
@property (nonatomic, assign) NSInteger showWating;

@end

@implementation InSearchDeviceViewController

+ (instancetype)searchDeviceViewController:(void (^)(void))comeback {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"InAddDevice" bundle:nil];
    InSearchDeviceViewController *searchVC = [sb instantiateViewControllerWithIdentifier:@"InSearchDeviceViewController"];
    searchVC.comeback = comeback;
    return searchVC;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_back"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    [InCommon setUpWhiteStyleButton:self.confirmBtn];
    
    __weak typeof(self) weakSelf = self;
    self.searchAnimationTimer = [NSTimer newTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf animation];
    }];
    [[NSRunLoop currentRunLoop] addTimer:self.searchAnimationTimer forMode:NSRunLoopCommonModes];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    self.topOptionViewHeightConstraint.constant = screenHeight / 4;
    if (screenHeight == 568) {
        // iphone 5, 4s
        self.topOptionViewHeightConstraint.constant = screenHeight / 5;
        self.successbodyViewHeightConstraint.constant = self.topOptionViewHeightConstraint.constant * 0.8;
        self.failedBodyViewHeightConstraint.constant = self.topOptionViewHeightConstraint.constant * 0.8;
    }
    self.type = InSearch;
    [self updateView];
    [self.searchAnimationTimer setFireDate:[NSDate distantFuture]];
    [self confirm];
    self.findDeviceMac = nil;
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopAnimation];
}

- (void)updateView {
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    NSString *message = @"";
    switch (common.deviceType) {
        case InDeviceSmartCardHolder:
        {
            self.successCardImageView.image = [UIImage imageNamed:@"successCardHolder"];
            self.failedCardImageView.image = [UIImage imageNamed:@"successCardHolder"];
            self.searchCardImageView.image = [UIImage imageNamed:@"searchCardHolder"];
            self.navigationItem.title = @"Add a new smart card holder";
            self.successMessageLabel.text = @"Found Smart Card Holder";
            self.failedMessageLabel.text = @"No Smart Card Holder Found";
            break;
        }
        case InDeviceSmartCard:
        {
            self.successCardImageView.image = [UIImage imageNamed:@"failedCard"];
            self.failedCardImageView.image = [UIImage imageNamed:@"failedCard"];
            self.searchCardImageView.image = [UIImage imageNamed:@"searchCard"];
            self.navigationItem.title = @"Add a new smart card";
            self.successMessageLabel.text = @"Found Smart Card";
            self.failedMessageLabel.text = @"No Smart Card Found";
            break;
        }
        default:
            break;
    }
    
    if (self.type == InSearch) {
        self.searchBodyView.hidden = NO;
        self.successBodyView.hidden = YES;
        self.failedBodyView.hidden = YES;
        self.tryAagainLabel.hidden = YES;
        self.phoneBodyView.hidden = NO;
        self.messageBodyViewHeightConstraing.constant = 166;
        self.phoneOptionViewHeightConstraint.constant = 151;
        self.confirmBtnTopConstraint.constant = screenHeight / 18.0;
        if (screenHeight == 568) {
            self.confirmBtnTopConstraint.constant = screenHeight / 35.0;
            self.phoneOptionViewHeightConstraint.constant = 140;
        }
        [self.confirmBtn setTitle:@"Confirm" forState:UIControlStateNormal];
        self.titleLabel.text = @"Instructions:";
        message = @"1. Make sure to turn on your phone's Bluetooth.\n2. Hold the button on the Smart card 3 sec until your hear a beep and the led starts flashing.\n3. Hold the Smart card close to your phone.";
    }
    else if (self.type == InSuccess) {
        self.searchBodyView.hidden = YES;
        self.successBodyView.hidden = NO;
        self.failedBodyView.hidden = YES;
        self.tryAagainLabel.hidden = YES;
        self.phoneBodyView.hidden = NO;
        [self.confirmBtn setTitle:@"Confirm" forState:UIControlStateNormal];
        self.messageBodyViewHeightConstraing.constant = 166;
        self.phoneOptionViewHeightConstraint.constant = 151;
        self.confirmBtnTopConstraint.constant = screenHeight / 18.0;
        if (screenHeight == 568) {
            self.confirmBtnTopConstraint.constant = screenHeight / 35.0;
            self.phoneOptionViewHeightConstraint.constant = 140;
        }
        self.titleLabel.text = @"Successive instructions:";
        message = @"1. Make sure to turn on your phone's Bluetooth.\n2. Hold the button on the Smart card until your hear a beep and the led starts flashing.\n3. Hold the Smart card close to your phone.";
    }
    else if (self.type == InFailed) {
        self.searchBodyView.hidden = YES;
        self.successBodyView.hidden = YES;
        self.failedBodyView.hidden = NO;
        self.tryAagainLabel.hidden = NO;
        self.phoneBodyView.hidden = YES;
        [self.confirmBtn setTitle:@"return" forState:UIControlStateNormal];
        self.messageBodyViewHeightConstraing.constant = 120;
        self.phoneOptionViewHeightConstraint.constant = 70;
        self.confirmBtnTopConstraint.constant = 0;
        self.titleLabel.text = @"you can";
        message = @"• Turn off and then turn on Bluetooth.\n• Hold the button on the Smart card and check if can hear a beep sound.\n• Near the Smart card to your phone";
    }
    NSMutableParagraphStyle  *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle  setLineSpacing:5];
    NSMutableAttributedString  *infoString = [[NSMutableAttributedString alloc] initWithString:message];
    [infoString  addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [message length])];
    // 设置Label要显示的text
    [self.messageLabel  setAttributedText:infoString];
}

- (IBAction)confirm {
    switch (self.type) {
        case InSearch:
        {
            if ([DLCentralManager sharedInstance].state != CBCentralManagerStatePoweredOn) {
                [InAlertView showAlertWithTitle:@"Information" message:@"Enable Bluetooth to pair with the device." confirmHanler:nil];
                return;
            }
            NSLog(@"开始搜索新设备");
            [self startAnimation];
            [self searchNewDevice];
            break;
        }
        case InSuccess:
        {
            NSLog(@"跳转到控制界面");
            [self addNewDevice];
            break;
        }
        case InFailed: {
            NSLog(@"返回搜索");
            self.type = InSearch;
            [self updateView];
            break;
        }
        default:
            break;
    }
}

- (void)searchNewDevice {
    __block BOOL find = NO;
    [[DLCentralManager sharedInstance] startScanDeviceWithTimeout:10 discoverEvent:^(DLCentralManager *manager, CBPeripheral *peripheral, NSString *mac) {
        if (!find) {
            DLDevice *device = [[DLCloudDeviceManager sharedInstance].cloudDeviceList objectForKey:mac];
            if (!device) {
                // 找到新设备
                find = YES;
                self.type = InSuccess;
                [self stopAnimation];
                [self updateView];
                self.findDeviceMac = mac;
            }
        }
    } didEndDiscoverDeviceEvent:^(DLCentralManager *manager, NSMutableDictionary<NSString *,DLKnowDevice *> *knownPeripherals) {
        if (!find) {
            [self stopAnimation];
            [self hideAllWating];
            self.type = InFailed;
            [self updateView];
        }
    }];
}

- (void)addNewDevice {
    NSLog(@"去添加新设备");
    DLDevice *device = [[DLCloudDeviceManager sharedInstance] addDevice:self.findDeviceMac];
    if (device) {
        // 添加设备成功， 去建立连接
        if (self.comeback) {
            // 从控制界面弹出的添加，需要在这里返回控制界面
            self.comeback();
        }
        else {
            // 没有控制界面的添加，需要重新创建控制界面
            InControlDeviceViewController *controlDeviceVC = [[InControlDeviceViewController alloc] init];
            controlDeviceVC.device = device;
            [self.navigationController pushViewController:controlDeviceVC animated:YES];
        }
    }
    else {
        [InAlertView showAlertWithTitle:@"Information" message:@"添加设备失败" confirmHanler:nil];
    }
}
- (void)goBack {
    if (self.navigationController.viewControllers.lastObject == self) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)startAnimation {
    [self.searchAnimationTimer setFireDate:[NSDate distantPast]];
}

- (void)stopAnimation {
    [self.searchAnimationTimer setFireDate:[NSDate distantFuture]];
}

- (void)hideAllWating {
    self.waiting1.hidden = YES;
    self.waiting2.hidden = YES;
    self.waiting3.hidden = YES;
}

- (void)animation {
    switch (self.showWating) {
        case 0:
            self.waiting1.hidden = YES;
            self.waiting2.hidden = YES;
            self.waiting3.hidden = YES;
            break;
        case 1:
            self.waiting1.hidden = NO;
            self.waiting2.hidden = YES;
            self.waiting3.hidden = YES;
            break;
        case 2:
            self.waiting1.hidden = NO;
            self.waiting2.hidden = NO;
            self.waiting3.hidden = YES;
            break;
        case 3:
            self.waiting1.hidden = NO;
            self.waiting2.hidden = NO;
            self.waiting3.hidden = NO;
            break;
        default:
            break;
    }
    self.showWating++;
    self.showWating = self.showWating % 4;
    NSLog(@"self.showWating = %zd", self.showWating);
}

- (void)dealloc {
    [self.searchAnimationTimer invalidate];
    self.searchAnimationTimer = nil;
}

@end
