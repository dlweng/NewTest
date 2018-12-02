//
//  InChangeDeviceNameView.m
//  Innway
//
//  Created by danly on 2018/10/20.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import "InChangeDeviceNameView.h"
#import "InCommon.h"

@interface InChangeDeviceNameView ()

@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIView *bodyView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *confirmBtnWidthCOnstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cancleBtnWidthConstraint;
@property (nonatomic, strong) completionHanler confirmHandle;
@property (weak, nonatomic) IBOutlet UIButton *confirmBtn;
@property (weak, nonatomic) IBOutlet UIButton *cancelBtn;


@end

@implementation InChangeDeviceNameView

+ (void)showChangeDeviceNameView:(NSString *)deviceName confirmHandle:(completionHanler)confirmHandle {
    InChangeDeviceNameView *changeView = [[InChangeDeviceNameView alloc] init];
    if (deviceName.length > 0) {
        changeView.textField.text = deviceName;
    }
    changeView.confirmHandle = confirmHandle;
    [changeView show];
}

- (instancetype)init {
    if (self = [super init]) {
        self = [[[NSBundle mainBundle] loadNibNamed:@"InChangeDeviceNameView" owner:self options:nil] lastObject];
        
        self.bodyView.backgroundColor = [UIColor whiteColor];
        self.bodyView.layer.cornerRadius = 5.0;
        if ([UIScreen mainScreen].bounds.size.width == 320) {
            self.confirmBtnWidthCOnstraint.constant = 110;
            self.cancleBtnWidthConstraint.constant = 110;
        }
        [InCommon setUpBlackStyleButton:self.confirmBtn];
        [InCommon setUpWhiteStyleButton:self.cancelBtn];
    }
    return self;
}

- (IBAction)textFieldValueChange:(UITextField *)sender {
}

- (IBAction)confirmBtnDidClick {
    [self removeFromSuperview];
    if (self.confirmHandle) {
        self.confirmHandle(self.textField.text);
    }
}

- (IBAction)cancelBtnDidClick {
    [self removeFromSuperview];
}

- (void)show {
    UIWindow *rootWindow = [UIApplication sharedApplication].keyWindow;
    [rootWindow addSubview:self];
    self.frame = [UIScreen mainScreen].bounds;
}

@end
