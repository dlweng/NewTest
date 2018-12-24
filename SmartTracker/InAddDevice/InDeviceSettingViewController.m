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
@property (weak, nonatomic) IBOutlet UIButton *deleteDeviceBtn;
@property (nonatomic, strong) UISwitch *disconnectAlertBtn;
@property (nonatomic, assign) NSNumber *phoneAlertMusic;

@end

@implementation InDeviceSettingViewController

+ (instancetype)deviceSettingViewController {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"InDeviceSettingViewController" bundle:nil];
    InDeviceSettingViewController *deviceSettingVC = sb.instantiateInitialViewController;
    return deviceSettingVC;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Device settings";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_back"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    
    self.disconnectAlertBtn = [[UISwitch alloc] init];
    [self.disconnectAlertBtn addTarget:self action:@selector(disconnectAlertBtnDidClick:) forControlEvents:UIControlEventValueChanged];
    self.deleteDeviceBtn.layer.masksToBounds = YES;
    self.deleteDeviceBtn.layer.cornerRadius = 10;
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

- (IBAction)deleteDeviceBtnDidClick {
    [InAlertView showAlertWithMessage:@"Unpair and delete device?" confirmHanler:^{
        [self deleteDevice];
    } cancleHanler:nil];
}

- (void)deleteDevice {
    DLCloudDeviceManager *manager = [DLCloudDeviceManager sharedInstance];
    [manager deleteDevice:self.device.mac];
    if (self.navigationController.viewControllers.lastObject == self) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)disconnectAlertBtnDidClick: (UISwitch *)btn {
    [self.device setDisconnectAlert:btn.isOn reconnectAlert:NO];
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
        case 0:
        case 1:
        case 2:
            return 1;
        case 3:
            return 2;
        default:
            return 0;
    }
}

// 下面两个方法都必须设置，才能成功设置分组头的值
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"Device alarm";
        case 1:
            return @"Device alarm sound";
        case 2:
            return @"";
        case 3:
            return @"Device details";
        default:
            return @"";
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *sectionName = @"";
    switch (section) {
        case 0:
            sectionName = @"    Device alarm";
            break;
        case 1:
            sectionName = @"    Device alarm sound";
            break;
        case 2:
            sectionName = @"";
            break;
        case 3:
            sectionName = @"    Device details";
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
    if (section == 2) {
        return 0;
    }
    return 35;
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
            cell.textLabel.text = @"Disconnect alarm";
            cell.accessoryView = self.disconnectAlertBtn;
            NSNumber *disconnectAlert = self.device.lastData[DisconnectAlertKey];
            self.disconnectAlertBtn.on = disconnectAlert.boolValue;
            break;
        }
        case 1:
        {
            self.phoneAlertMusic = [[NSUserDefaults standardUserDefaults] objectForKey:PhoneAlertMusicKey];
            cell.textLabel.text = @"Cell phone alarm sound";
            switch (self.phoneAlertMusic.integerValue) {
                case 2:
                    cell.detailTextLabel.text = @"Mobile phone alarm 2";
                    break;
                case 3:
                    cell.detailTextLabel.text = @"Mobile phone alarm 3";
                    break;
                default:
                    cell.detailTextLabel.text = @"Mobile phone alarm 1";
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
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"Device Address";
                    cell.detailTextLabel.text = self.device.mac;
                    break;
                case 1:
                    cell.textLabel.text = @"Firmware";
                    cell.detailTextLabel.text = self.device.firmware;
                    break;
                default:
                    break;
            }
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
    if (indexPath.section == 1) {
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
        title = @"Select ringone";
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

@end
