//
//  InDeviceMenuViewController.m
//  Innway
//
//  Created by danly on 2018/8/5.
//  Copyright © 2018年 innwaytech. All rights reserved.
//
#define InDeviceListCellReuseIdentifier @"InDeviceListCell"
#define InDeviceListAddDeviceCellReuseIdentifier @"InDeviceListAddDeviceCell"

#import "InDeviceListViewController.h"
#import "DLCloudDeviceManager.h"
#import "InDeviceListCell.h"
#import "InDeviceListAddDeviceCell.h"
#import "InCommon.h"
#import "NSTimer+InTimer.h"

@interface InDeviceListViewController ()<UITableViewDelegate, UITableViewDataSource, InDeviceListCellDelegate, DLDeviceDelegate> {
    NSTimer *_offlineTimer;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *upDownView;
@property (nonatomic, assign) CGPoint oldPoint;
@property (weak, nonatomic) IBOutlet UIImageView *upDownImage;

@end

@implementation InDeviceListViewController

+ (instancetype)deviceListViewController {
    InDeviceListViewController *menuVC = [[InDeviceListViewController alloc] init];
    menuVC.tableView.backgroundColor = [UIColor redColor];
    return menuVC;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerNib:[UINib nibWithNibName:@"InDeviceListCell" bundle:nil] forCellReuseIdentifier:InDeviceListCellReuseIdentifier];
    [self.tableView registerNib:[UINib nibWithNibName:@"InDeviceListAddDeviceCell" bundle:nil] forCellReuseIdentifier:InDeviceListAddDeviceCellReuseIdentifier];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOnlineChange:) name:DeviceOnlineChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceRSSIChange:) name:DeviceRSSIChangeNotification object:nil];
    self.view.backgroundColor = [UIColor clearColor];
    self.tableView.backgroundColor = [UIColor clearColor];
    
    self.upDownView.userInteractionEnabled = YES;

    // 添加点击手势
    [self.upDownView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(upDown:)]];
    [self.upDownView addGestureRecognizer:[[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(upDown:)]];
    // 添加上下清扫手势
    UISwipeGestureRecognizer *upSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(turnUp)];
    [self.view addGestureRecognizer:upSwipeGestureRecognizer];
    upSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
    UISwipeGestureRecognizer *downSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(turnDown)];
    [self.view addGestureRecognizer:downSwipeGestureRecognizer];
    downSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    
    self.down = YES;
    
    __weak typeof(self) weakSelf = self;
    _offlineTimer = [NSTimer newTimerWithTimeInterval:10 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf.tableView reloadData];
    }];
    [[NSRunLoop currentRunLoop] addTimer:_offlineTimer forMode:NSRunLoopCommonModes];
    [_offlineTimer setFireDate:[NSDate distantPast]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceOnlineChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceRSSIChangeNotification object:nil];
    [_offlineTimer setFireDate:[NSDate distantFuture]];
    [_offlineTimer invalidate];
    _offlineTimer = nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cloudList.count + 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == self.cloudList.count) {
        return 50;
    }
    return 70;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == self.cloudList.count) {
        InDeviceListAddDeviceCell *cell = [tableView dequeueReusableCellWithIdentifier:InDeviceListAddDeviceCellReuseIdentifier];
        cell.backgroundColor = [UIColor clearColor];
        return cell;
    }
    else {
        InDeviceListCell *cell = [tableView dequeueReusableCellWithIdentifier:InDeviceListCellReuseIdentifier];
        cell.backgroundColor = [UIColor clearColor];
        NSString *mac = self.cloudList.allKeys[indexPath.row];
        DLDevice *device = self.cloudList[mac];
        device.delegate = self;
        cell.device = device;
        cell.delegate = self;
        cell.beSelected = self.selectDevice == device ? YES : NO;
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    if (indexPath.row == self.cloudList.count) {
        if ([self.delegate respondsToSelector:@selector(deviceListViewControllerDidSelectedToAddDevice:)]) {
            [self.delegate deviceListViewControllerDidSelectedToAddDevice:self];
        }
    }
    else {
        NSString *mac = self.cloudList.allKeys[indexPath.row];
        DLDevice *device = self.cloudList[mac];
        self.selectDevice = device; // 标识哪台设备被选中，并更新界面
        [self.tableView reloadData];
        if ([self.delegate respondsToSelector:@selector(deviceListViewController:didSelectedDevice:)]) {
            [self.delegate deviceListViewController:self didSelectedDevice:device];
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    NSLog(@"开始拖动");
}

- (void)deviceOnlineChange:(NSNotification *)noti {
    [self.tableView reloadData];
}

- (void)deviceListCellSettingBtnDidClick:(InDeviceListCell *)cell {
    if ([self.delegate respondsToSelector:@selector(deviceSettingBtnDidClick:)]) {
        [self.delegate deviceSettingBtnDidClick:cell.device];
    }
}

- (void)deviceRSSIChange:(NSNotification *)noti {
    [self.tableView reloadData];
}

- (void)reloadView {
    [self.tableView reloadData];
}

- (void)upDown:(UIPanGestureRecognizer *)pan {
    self.down = !self.down;
    if ([self.delegate respondsToSelector:@selector(deviceListViewController:moveDown:)]) {
         [self.delegate deviceListViewController:self moveDown:self.down];
    }
}

- (void)turnUp {
    if (self.down) {
        self.down = NO;
        if ([self.delegate respondsToSelector:@selector(deviceListViewController:moveDown:)]) {
            [self.delegate deviceListViewController:self moveDown:self.down];
        }
    }
}

- (void)turnDown {
    if (!self.down) {
        self.down = YES;
        if ([self.delegate respondsToSelector:@selector(deviceListViewController:moveDown:)]) {
            [self.delegate deviceListViewController:self moveDown:self.down];
        }
    }
}

- (void)setDown:(BOOL)down {
    _down = down;
    if (down) {
        self.upDownImage.image = [UIImage imageNamed:@"up"];
    }
    else {
        self.upDownImage.image = [UIImage imageNamed:@"down"];
    }
}

- (void)device:(DLDevice *)device didUpdateData:(NSDictionary *)data{
//    NSLog(@"接收到设备数据， device.mac = %@， data = %@", device.mac, data);
    [self.tableView reloadData];
}

- (NSDictionary *)cloudList {
    return [[DLCloudDeviceManager sharedInstance].cloudDeviceList copy];
}

@end
