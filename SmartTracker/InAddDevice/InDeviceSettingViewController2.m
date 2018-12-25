//
//  InDeviceSettingViewController2.m
//  SmartTracker
//
//  Created by danlypro on 2018/12/24.
//  Copyright © 2018 danlypro. All rights reserved.
//

#import "InDeviceSettingViewController2.h"
#import "InCommon.h"
#import "InChangeDeviceNameView.h"
#import "DLCloudDeviceManager.h"
#import "InDeviceSettingFooterView.h"
#import "InAlarmTypeSelectionView.h"
#define InDeviceSettingCellReuseIdentifier2 @"InDeviceSettingCell2"

@interface InDeviceSettingViewController2 ()<UITableViewDelegate, UITableViewDataSource, DLDeviceDelegate>

@property (nonatomic, weak) UITableView *tableView;
@property (nonatomic, strong) UISwitch *disconnectAlertBtn;
@property (weak, nonatomic) IBOutlet UIButton *deleteDeviceBtn;

@end

@implementation InDeviceSettingViewController2

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Device details";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_back"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    
    UITableView *tb = [[UITableView alloc] initWithFrame:self.view.frame style:UITableViewStyleGrouped];
    self.tableView = tb;
    [self.view addSubview:tb];
    tb.delegate = self;
    tb.dataSource = self;
    
    self.disconnectAlertBtn = [[UISwitch alloc] init];
    self.disconnectAlertBtn.onTintColor = [InCommon uiBackgroundColor];
    [self.disconnectAlertBtn addTarget:self action:@selector(disconnectAlertBtnDidClick:) forControlEvents:UIControlEventValueChanged];
    self.deleteDeviceBtn.layer.masksToBounds = YES;
    self.deleteDeviceBtn.layer.cornerRadius = 10;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.device.delegate = self;
}

- (void)goBack {
    if (self.navigationController.viewControllers.lastObject == self) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Table view data source
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 35;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 3) {
        return 160;
    }
    return 6;
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Device name";
    }
    else if (section == 1) {
        return @"Device alarm";
    }
    else if (section == 2) {
        return @"Device alarm sound";
    }
    else if (section == 3) {
        return @"Device details";
    }
    return @"";
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *sectionName = @"";
    switch (section) {
        case 0:
            sectionName = @"    Device name";
            break;
        case 1:
            sectionName = @"    Device alarm";
            break;
        case 2:
            sectionName = @"    Device alarm sound";
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:InDeviceSettingCellReuseIdentifier2];
    cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1];
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:15];
   
    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = self.device.deviceName;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    else if(indexPath.section == 1) {
        cell.textLabel.text = @"Disconnect alarm";
        cell.accessoryView = self.disconnectAlertBtn;
        NSNumber *disconnectAlert = self.device.lastData[DisconnectAlertKey];
        self.disconnectAlertBtn.on = disconnectAlert.boolValue;
    }
    else if (indexPath.section == 2 && indexPath.row == 0) {
        cell.textLabel.text = @"Device alarm sound";
        NSNumber *alertMusic = self.device.lastData[AlertMusicKey];
        switch (alertMusic.integerValue) {
            case 2:
                cell.detailTextLabel.text = @"Equipment alarm 2";
                break;
            case 3:
                cell.detailTextLabel.text = @"Equipment alarm 3";
                break;
            default:
                cell.detailTextLabel.text = @"Equipment alarm 1";
                break;
        }
    }
    else if (indexPath.section == 3) {
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
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 0) {
        [InChangeDeviceNameView showChangeDeviceNameView:self.device.deviceName confirmHandle:^(NSString * _Nonnull newDeviceName) {
            NSLog(@"新设备名称: %@", newDeviceName);
            if (newDeviceName.length > 0) {
                [self saveNewDeviceName:newDeviceName];
                [self.tableView reloadData];
            }
            else {
                [InAlertView showAlertWithTitle:@"Information" message:@"请输入设备名称" confirmHanler:nil];
            }
        }];
        return;
    }
    else if (indexPath.section == 2 && indexPath.row == 0) {
        NSNumber *alertMusic = self.device.lastData[AlertMusicKey];
        NSInteger currentAlarmVoice = alertMusic.integerValue - 1;
        // 弹出选择框
        InAlarmType alertType = InDeviceAlert;
        [InAlarmTypeSelectionView showAlarmTypeSelectionView:alertType title:@"select ringtone" currentAlarmVoice:currentAlarmVoice confirmHanler:^(NSInteger newAlertVoice) {
            [self.device selecteDiconnectAlertMusic:newAlertVoice];
            [self.tableView reloadData];
        }];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == 3) {
        InDeviceSettingFooterView *footerView = [[InDeviceSettingFooterView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 80)];
        [footerView.deleteBtn addTarget:self action:@selector(deleteDeviceBtnDidClick) forControlEvents:UIControlEventTouchUpInside];
        return footerView;
    }
    return nil;
}

- (void)saveNewDeviceName:(NSString *)newDeviceName {
    // 保存设备名称
    self.device.deviceName = newDeviceName;
    // 保存设备名称到本地
    [[DLCloudDeviceManager sharedInstance] updateNameWithDevice:self.device];
}

- (IBAction)deleteDeviceBtnDidClick {
    [InAlertView showAlertWithMessage:@"Confirm delete device？" confirmHanler:^{
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

- (void)device:(DLDevice *)device didUpdateData:(NSDictionary *)data {
    [self.tableView reloadData];
}


@end
