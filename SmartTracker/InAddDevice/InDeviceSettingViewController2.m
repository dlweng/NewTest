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
#define InDeviceSettingCellReuseIdentifier2 @"InDeviceSettingCell2"

@interface InDeviceSettingViewController2 ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, weak) UITableView *tableView;

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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Device name";
    }
    return @"";
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *sectionName = @"";
    switch (section) {
        case 0:
            sectionName = @"    Device name";
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
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
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
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == 0) {
        InDeviceSettingFooterView *footerView = [[InDeviceSettingFooterView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 80)];
        [footerView.deleteBtn addTarget:self action:@selector(deleteDeviceBtnDidClick) forControlEvents:UIControlEventTouchUpInside];
        return footerView;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return 160;
    }
    return 0;
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



@end
