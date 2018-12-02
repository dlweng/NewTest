//
//  InSearchDeviceViewController.m
//  Innway
//
//  Created by danly on 2018/10/1.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import "InSearchDeviceViewController.h"
#import "InCommon.h"
#import "DLCentralManager.h"
#import "DLCloudDeviceManager.h"
#import "InControlDeviceViewController.h"

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

@property (weak, nonatomic) IBOutlet UIView *searchBodyView;
@property (weak, nonatomic) IBOutlet UIView *successBodyView;
@property (weak, nonatomic) IBOutlet UIView *failedBodyView;
@property (weak, nonatomic) IBOutlet UILabel *titleTipLabel;
@property (weak, nonatomic) IBOutlet UILabel *firstTipLabel;
@property (weak, nonatomic) IBOutlet UILabel *secondTipLabel;
@property (weak, nonatomic) IBOutlet UILabel *thirdTipLabel;
@property (weak, nonatomic) IBOutlet UIButton *confirmBtn;
@property (nonatomic, assign) InSearchViewType type;
@property (weak, nonatomic) IBOutlet UILabel *tryAagainLabel;
@property (weak, nonatomic) IBOutlet UIView *phoneBodyView;

@property (nonatomic, strong) NSTimer *searchAnimationTimer;
@property (nonatomic, copy) NSString *findDeviceMac;
@property (nonatomic, strong) void(^comeback)(void);

@property (weak, nonatomic) IBOutlet UIImageView *successCardImageView;
@property (weak, nonatomic) IBOutlet UIImageView *failedCardImageView;
@property (weak, nonatomic) IBOutlet UIImageView *searchCardImageView;

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
    self.searchAnimationTimer = [NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(animation) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.searchAnimationTimer forMode:NSRunLoopCommonModes];
    
    self.successCardImageView.image = [UIImage imageNamed:@"successCardHolder"];
    self.failedCardImageView.image = [UIImage imageNamed:@"successCardHolder"];
    self.searchCardImageView.image = [UIImage imageNamed:@"searchCardHolder"];
    self.navigationItem.title = @"Add a new smart card holder";
    if (common.deviceType == InDeviceSmartCard) {
        self.successCardImageView.image = [UIImage imageNamed:@"failedCard"];
        self.failedCardImageView.image = [UIImage imageNamed:@"failedCard"];
        self.searchCardImageView.image = [UIImage imageNamed:@"searchCardHolder"];
        self.navigationItem.title = @"Add a new smart card";
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    self.topOptionViewHeightConstraint.constant = screenHeight / 3.8;
    if (screenHeight == 568) {
        // iphone 5, 4s
        self.topOptionViewHeightConstraint.constant = screenHeight / 4.3;
    }
    self.type = InSearch;
    [self updateView];
    [self confirm];
    self.findDeviceMac = nil;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopAnimation];
}

- (void)updateView {
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    if (self.type == InSearch) {
        self.searchBodyView.hidden = NO;
        self.successBodyView.hidden = YES;
        self.failedBodyView.hidden = YES;
        self.tryAagainLabel.hidden = YES;
        self.phoneBodyView.hidden = NO;
        self.phoneOptionViewHeightConstraint.constant = 151;
        self.confirmBtnTopConstraint.constant = screenHeight / 14.0;
        if (screenHeight == 568) {
            self.confirmBtnTopConstraint.constant = screenHeight / 26.0;
        }
        [self.confirmBtn setTitle:@"Confirm" forState:UIControlStateNormal];
        self.titleTipLabel.text = @"Successive instructions";
        self.firstTipLabel.text = @"1. Make sure to turn on your phone's Bluetooth.";
        self.secondTipLabel.text = @"2. Hold the button on the Smart card 3 sec until your hear a beep and the led starts flashing.";
        self.thirdTipLabel.text = @"3. Hold the Smart card close to your phone.";
    }
    else if (self.type == InSuccess) {
        self.searchBodyView.hidden = YES;
        self.successBodyView.hidden = NO;
        self.failedBodyView.hidden = YES;
        self.tryAagainLabel.hidden = YES;
        self.phoneBodyView.hidden = NO;
        [self.confirmBtn setTitle:@"Confirm" forState:UIControlStateNormal];
        self.phoneOptionViewHeightConstraint.constant = 151;
        self.confirmBtnTopConstraint.constant = screenHeight / 14.0;
        if (screenHeight == 568) {
            self.confirmBtnTopConstraint.constant = screenHeight / 26.0;
        }
        self.titleTipLabel.text = @"Successive instructions";
        self.firstTipLabel.text = @"1. Make sure to turn on your phone's Bluetooth.";
        self.secondTipLabel.text = @"2. Hold the button on the Smart card until your hear a beep and the led starts flashing.";
        self.thirdTipLabel.text = @"3. Hold the Smart card close to your phone.";
    }
    else if (self.type == InFailed) {
        self.searchBodyView.hidden = YES;
        self.successBodyView.hidden = YES;
        self.failedBodyView.hidden = NO;
        self.tryAagainLabel.hidden = NO;
        self.phoneBodyView.hidden = YES;
        [self.confirmBtn setTitle:@"return" forState:UIControlStateNormal];
        self.phoneOptionViewHeightConstraint.constant = 70;
        self.confirmBtnTopConstraint.constant = 0;
        self.titleTipLabel.text = @"you can";
        self.firstTipLabel.text = @"1. Turn off and then turn on Bluetooth.";
        self.secondTipLabel.text = @"2. Hold the button on the Smart card and check if can hear a beep sound.";
        self.thirdTipLabel.text = @"3. Near the Smart card to your phone";
    }
}

- (IBAction)confirm {
    switch (self.type) {
        case InSearch:
        {
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
