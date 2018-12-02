//
//  InAlertTableViewController.m
//  Innway
//
//  Created by danly on 2018/8/5.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import "InAlertTableViewController.h"

@interface InAlertTableViewController ()

@property (nonatomic, assign) InAlertViewType alertType;
@property (nonatomic, strong) DLDevice *device;
@property (nonatomic, assign) NSInteger alertNum;

@end

@implementation InAlertTableViewController

- (instancetype)initWithAlertType:(InAlertViewType)alertType withDevice:(DLDevice *)device {
    if (self = [super init]) {
        self.alertType = alertType;
        self.device = device;
        switch (self.alertType) {
            case InPhoneAlert:
            {
                NSNumber *phoneAlertMusic = [[NSUserDefaults standardUserDefaults] objectForKey:PhoneAlertMusicKey];
                self.alertNum = phoneAlertMusic.integerValue - 1;
                break;
            }
            case InDeviceAlert:
            {
                NSNumber *alertMusic = self.device.lastData[AlertMusicKey];
                self.alertNum = alertMusic.integerValue - 1;
                break;
            }
            default:
                break;
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
    
    switch (self.alertType) {
        case InDeviceAlert:
            self.navigationItem.title = @"设备警报声音";
            break;
        case InPhoneAlert:
            self.navigationItem.title = @"手机警报声音";
        default:
            break;
    }
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_back"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
}

- (void)goBack {
    switch (self.alertType) {
        case InPhoneAlert:
        {
            [[NSUserDefaults standardUserDefaults] setValue:@(self.alertNum+1) forKey:PhoneAlertMusicKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
            break;
        case InDeviceAlert:
            [self.device selecteDiconnectAlertMusic:self.alertNum+1];
            break;
        default:
            break;
    }
    if (self.navigationController.viewControllers.lastObject == self) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    if (self.alertType == InDeviceAlert) {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"设备警报声一";
                break;
            case 1:
                cell.textLabel.text = @"设备警报声二";
                break;
            case 2:
                cell.textLabel.text = @"设备警报声三";
                break;
            default:
                break;
        }
    }
    else {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"手机警报声一";
                break;
            case 1:
                cell.textLabel.text = @"手机警报声二";
                break;
            case 2:
                cell.textLabel.text = @"手机警报声三";
                break;
            default:
                break;
        }
    }
    if (indexPath.row == self.alertNum) {
        cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icon_checked"]];
    }
    else {
        cell.accessoryView = nil;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    self.alertNum = indexPath.row;
    [self.tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70;
}



@end
