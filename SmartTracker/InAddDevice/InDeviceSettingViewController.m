//
//  InDeviceSettingViewController.m
//  Innway
//
//  Created by danly on 2018/8/5.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import "InCommon.h"
#import "InDeviceSettingViewController.h"
#import "DLCloudDeviceManager.h"
#import "InDeviceSettingFooterView.h"
#import "InChangeDeviceNameView.h"
#import "InAlarmTypeSelectionView.h"
#define InDeviceSettingCellReuseIdentifier @"InDeviceSettingCell"

@interface InDeviceSettingViewController ()<UITableViewDataSource, UITableViewDelegate, DLDeviceDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, assign) NSNumber *phoneAlertMusic;
@property (nonatomic, strong) UISwitch *flashBtn;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;

@end

@implementation InDeviceSettingViewController

+ (instancetype)deviceSettingViewController {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"InDeviceSettingViewController" bundle:nil];
    InDeviceSettingViewController *deviceSettingVC = sb.instantiateInitialViewController;
    return deviceSettingVC;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Setting";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_back"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    self.flashBtn = [[UISwitch alloc] init];
    self.flashBtn.onTintColor = [InCommon uiBackgroundColor];
    [self.flashBtn addTarget:self action:@selector(flashBtnDidClick:) forControlEvents:UIControlEventValueChanged];
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"NEAR", @"FAR"]];
    self.segmentedControl.tintColor = [InCommon uiBackgroundColor];
    self.segmentedControl.userInteractionEnabled = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceRSSIChange:) name:DeviceRSSIChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView setContentOffset:CGPointZero animated:NO];
    });
    NSLog(@"手机警报声音: %zd", self.phoneAlertMusic.integerValue);
    if (!self.phoneAlertMusic) {
        self.phoneAlertMusic = @(1);
    }
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.device.delegate = self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceRSSIChangeNotification object:nil];
}

- (void)saveNewDeviceName:(NSString *)newDeviceName {
    // 保存设备名称
    self.device.deviceName = newDeviceName;
    // 保存设备名称到本地
    [[DLCloudDeviceManager sharedInstance] updateNameWithDevice:self.device];
}

- (void)goBack {
    if (self.navigationController.viewControllers.lastObject == self) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 1:
            return 2;
        case 0:
        case 2:
        case 3:
            return 1;
        default:
            return 0;
    }
}

// 下面两个方法都必须设置，才能成功设置分组头的值
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"Alert Tone";
        default:
            return @"";
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *sectionName = @"";
    switch (section) {
        case 0:
            sectionName = @"    Alert Tone";
            break;
        default:
            break;
    }
    UILabel *label = [[UILabel alloc] init];
    label.text = sectionName;
    label.font = [UIFont systemFontOfSize:13.0];
    label.textColor = [UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1];
    return label;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return 35;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:InDeviceSettingCellReuseIdentifier];
    cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1];
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:15];
    switch (indexPath.section) {
        case 0:
        {
            self.phoneAlertMusic = [[NSUserDefaults standardUserDefaults] objectForKey:PhoneAlertMusicKey];
            cell.textLabel.text = @"Phone Alert Tone";
            switch (self.phoneAlertMusic.integerValue) {
                case 2:
                    cell.detailTextLabel.text = @"Alert2";
                    break;
                case 3:
                    cell.detailTextLabel.text = @"Alert3";
                    break;
                default:
                    cell.detailTextLabel.text = @"Alert1";
                    break;
            }
            break;
        }
        case 1:
        {
            switch (indexPath.row) {
                case 0: {
                    cell.textLabel.text = @"Flash Light";
                    cell.accessoryView = self.flashBtn;
                    self.flashBtn.on = [common flashStatus];
                    break;
                }
                case 1:{
                    cell.textLabel.text = @"Geofence";
                    cell.accessoryView = self.segmentedControl;
                    if (self.device.rssi.intValue >= -56) {
                        self.segmentedControl.selectedSegmentIndex = 0;
                    }
                    else {
                        self.segmentedControl.selectedSegmentIndex = 1;
                    }
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case 2:
        {
            cell.textLabel.text = @"Help Center";
            break;
        }
        case 3:
        {
            cell.textLabel.text = @"APP Version";
            cell.detailTextLabel.text = @"1.0.0";
            break;
        }
        default:
            break;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *title = @"Select device alert tone";
    if (indexPath.section == 0) {
        InAlarmType alertType = InPhoneAlert;
        // 获取当前的报警声音
        NSInteger currentAlarmVoice = 0;
        NSNumber *phoneAlertMusic = [[NSUserDefaults standardUserDefaults] objectForKey:PhoneAlertMusicKey];
        if (phoneAlertMusic) {
            currentAlarmVoice = phoneAlertMusic.integerValue - 1;
        }
        else {
            currentAlarmVoice = 0;
        }
        title = @"Select phone alert tone";
        // 弹出选择框
        __weak typeof(self) weakSelf = self;
        [InAlarmTypeSelectionView showAlarmTypeSelectionView:alertType title:title currentAlarmVoice:currentAlarmVoice confirmHanler:^(NSInteger newAlertVoice) {
            [[NSUserDefaults standardUserDefaults] setValue:@(newAlertVoice) forKey:PhoneAlertMusicKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [weakSelf.tableView reloadData];
        }];
    }
}

- (void)device:(DLDevice *)device didUpdateData:(NSDictionary *)data {
    [self.tableView reloadData];
}

- (void)flashBtnDidClick:(UISwitch *)btn {
    [common saveFlashStatus:btn.isOn];
}

- (void)deviceRSSIChange:(NSNotification *)noti {
    DLDevice *device = noti.object;
    if (device.mac == self.device.mac) {
        [self.tableView reloadData];
    }
}

@end
