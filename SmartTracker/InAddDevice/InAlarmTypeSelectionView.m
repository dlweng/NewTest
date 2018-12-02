//
//  InAlarmTypeSelectionView.m
//  Innway
//
//  Created by danly on 2018/10/20.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import "InAlarmTypeSelectionView.h"

@interface InAlarmTypeSelectionView ()<UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *bodyView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *confirmBtnWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cancelBtnWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bodyViewHeigthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewHeightConstraint;
@property (nonatomic, strong) alarmCompletionHanler confirmHanler;
@property (nonatomic, assign) NSInteger alertVoice;
@property (nonatomic, assign) InAlarmType alarmType;
@property (weak, nonatomic) IBOutlet UIButton *confirmBtn;
@property (weak, nonatomic) IBOutlet UIButton *cancelBtn;



@end

@implementation InAlarmTypeSelectionView

+ (void)showAlarmTypeSelectionView:(InAlarmType)alarmType title:(NSString *)title currentAlarmVoice:(NSInteger)currentAlarmVoice confirmHanler:(alarmCompletionHanler)confirmHanler {
    InAlarmTypeSelectionView *alarmView = [[InAlarmTypeSelectionView alloc] init];
    alarmView.confirmHanler = confirmHanler;
    alarmView.titleLabel.text = title;
    alarmView.alertVoice = currentAlarmVoice;
    alarmView.alarmType = alarmType;
    [alarmView show];
}

- (instancetype)init {
    if (self = [super init]) {
        self = [[[NSBundle mainBundle] loadNibNamed:@"InAlarmTypeSelectionView" owner:self options:nil] lastObject];
        self.bodyView.backgroundColor = [UIColor whiteColor];
        self.bodyView.layer.cornerRadius = 5.0;
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.bounces = NO;
        // 重新设置布局
        if ([UIScreen mainScreen].bounds.size.width == 320) {
            self.confirmBtnWidthConstraint.constant = 110;
            self.cancelBtnWidthConstraint.constant = 110;
        }
        self.bodyViewHeigthConstraint.constant += 100;
        self.tableViewHeightConstraint.constant += 100;
        
        [InCommon setUpBlackStyleButton:self.confirmBtn];
        [InCommon setUpWhiteStyleButton:self.cancelBtn];
    }
    return self;
}

#pragma mark - UITableViewDataSource, UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    
    if (self.alarmType == InDeviceAlert) {
        switch (indexPath.row) {

            case 1:
                cell.textLabel.text = @"Equipment alarm 2";
                break;
            case 2:
                cell.textLabel.text = @"Equipment alarm 3";
                break;
            default:
                cell.textLabel.text = @"Equipment alarm 1";
                break;
        }
    }
    else {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Mobile phone alarm 1";
                break;
            case 1:
                cell.textLabel.text = @"Mobile phone alarm 2";
                break;
            case 2:
                cell.textLabel.text = @"Mobile phone alarm 3";
                break;
            default:
                break;
        }
    }
    if (indexPath.row == self.alertVoice) {
        cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"check"]];
    }
    else {
        cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"uncheck"]];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    self.alertVoice = indexPath.row;
    [self.tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (void)show {
    UIWindow *rootWindow = [UIApplication sharedApplication].keyWindow;
    [rootWindow addSubview:self];
    self.frame = [UIScreen mainScreen].bounds;
}

- (IBAction)confirmDidClick {
    [self removeFromSuperview];
    if (self.confirmHanler) {
        self.confirmHanler(self.alertVoice+1);
    }
}

- (IBAction)cancelDidClick {
    [self removeFromSuperview];
}


@end
