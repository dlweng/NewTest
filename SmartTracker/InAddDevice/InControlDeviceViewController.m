//
//  InControlDeviceViewController.m
//  Innway
//
//  Created by danly on 2018/8/4.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import "InControlDeviceViewController.h"
#import "InDeviceListViewController.h"
#import "InDeviceSettingViewController.h"
#import "DLCloudDeviceManager.h"
#import "InAnnotationView.h"
#import <MapKit/MapKit.h>
#import "InCommon.h"
#import "InSelectionViewController.h"
#import "InSelectionViewController.h"
#import <AVFoundation/AVFoundation.h>
#define coverViewAlpha 0.85  // 覆盖层的透明度

@interface InControlDeviceViewController ()<DLDeviceDelegate, InDeviceListViewControllerDelegate, MKMapViewDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topBodyViewTopConstraint;
@property (weak, nonatomic) IBOutlet UIView *topBodyView;
@property (weak, nonatomic) IBOutlet UIButton *controlDeviceBtn;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *controlBtnBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomBtnViewHeightConstaint;

// 设置界面
@property (nonatomic, weak) UIView *settingView;
@property (nonatomic, weak) UIViewController *settingVC;
@property (nonatomic, strong) NSLayoutConstraint *settingViewLeftConstraint;
@property (nonatomic, strong) NSLayoutConstraint *settingViewHeightConstraint;

// 设备列表
@property (weak, nonatomic) IBOutlet UIView *deviceListBodyView;
@property (weak, nonatomic) IBOutlet UIView *deviceListBackgroupView;
@property (nonatomic, strong)InDeviceListViewController *deviceListVC;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *deviceListBodyHeightConstraint;

// 地图
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
// 存储掉线设备大头针的位置
@property (nonatomic, strong) NSMutableDictionary *deviceAnnotation;

// 显示设置界面的透明覆盖层
@property (nonatomic, weak) UIView *coverView;

// 拍照
@property (strong, nonatomic) IBOutlet UIView *customTakePhotoView;
@property (weak, nonatomic) IBOutlet UIView *imageBodyView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (strong,nonatomic)UIImagePickerController * imagePikerViewController;
@property (nonatomic, strong) UIImagePickerController *libraryPikerViewController;
//@property (nonatomic,strong)AVCaptureSession *captureSession;



// 按钮闪烁动画
@property (nonatomic, strong) NSTimer *animationTimer;
@property (nonatomic, assign) BOOL isBtnAnimation; // 标识按钮动画是否开启
@property (nonatomic, assign) BOOL btnTextIsHide;
// 标识当前是否在拍照界面，是的话接收到设备的05命令不要发出查找手机的警报，而是要拍照
@property (nonatomic, assign) BOOL inTakePhoto;
// 标识当前正在查找手机的设备
@property (nonatomic, strong) NSMutableDictionary *searchPhoneDevices;
@end

@implementation InControlDeviceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 界面调整
    self.topBodyViewTopConstraint.constant += 64;
    if ([InCommon isIPhoneX]) { //iphonex
        //iphoneX底部和顶部需要多留20px空白
        self.topBodyViewTopConstraint.constant += 20;
        self.bottomBtnViewHeightConstaint.constant += 20;
        self.controlBtnBottomConstraint.constant += 20;
    }
    
    // 设置按钮圆弧
    self.controlDeviceBtn.layer.masksToBounds = YES;
    self.controlDeviceBtn.layer.cornerRadius = 5;
    
    [self setupNarBar];
    [self addDeviceListView];
    [self setUpImagePiker];
    [[DLCloudDeviceManager sharedInstance] autoConnectCloudDevice];
    
    //地图设置
    self.mapView.delegate = self;
    self.mapView.userTrackingMode = MKUserTrackingModeFollow;
    
    // 实时监听设备的RSSI值更新
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceRSSIChange:) name:DeviceRSSIChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceChangeOnline:) name:DeviceOnlineChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchPhone:) name:DeviceSearchPhoneNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchDeviceAlert:) name:DeviceSearchDeviceAlertNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopBtnAnimation) name:DeviceGetAckFailedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUI) name:ApplicationWillEnterForeground object:nil];
    
    // 添加云端列表的监视
    [[DLCloudDeviceManager sharedInstance] addObserver:self forKeyPath:@"cloudDeviceList" options:NSKeyValueObservingOptionNew context:nil];
    
    // 设置定时器
    self.animationTimer = [NSTimer timerWithTimeInterval:0.4 target:self selector:@selector(showBtnAnimation) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.animationTimer forMode:NSRunLoopCommonModes];
    [self stopBtnAnimation];
    
    if (![common isOpensLocation]) {
        [InAlertView showAlertWithMessage:@"跳转到设置界面打开定位功能" confirmHanler:^{
            [common goToAPPSetupView];
        } cancleHanler:nil];
    }
    
    self.searchPhoneDevices = [NSMutableDictionary dictionary];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 设置云列表的第一台设备未当前选中的设备
    DLCloudDeviceManager *cloudManager = [DLCloudDeviceManager sharedInstance];
    if (cloudManager.cloudDeviceList.count > 0) {
        if (self.deviceListVC.selectDevice && [cloudManager.cloudDeviceList objectForKey:self.deviceListVC.selectDevice.mac]) {
            // 当设备列表已有选中设备，且存在云端列表中，不需要重新设置
        }
        else {
            NSString *mac = cloudManager.cloudDeviceList.allKeys[0];
            DLDevice *device = cloudManager.cloudDeviceList[mac];
            self.device = device;
            self.deviceListVC.selectDevice = self.device;
        }
    }
    else {
        // 没有设备则跳转到添加界面
        [self deviceListViewControllerDidSelectedToAddDevice:self.deviceListVC];
    }
    [self.deviceListVC reloadView];
    [self.device getDeviceInfo];
    [self updateUI];
    // 在viewDidLoad设置没有效果
    self.mapView.showsUserLocation = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceRSSIChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceOnlineChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceSearchPhoneNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceSearchDeviceAlertNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceGetAckFailedNotification object:nil];
    [[DLCloudDeviceManager sharedInstance] removeObserver:self forKeyPath:@"cloudDeviceList"];
    [self.animationTimer invalidate];
    self.animationTimer = nil;
}

#pragma mark UI设置
- (void)setupNarBar {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_more"] style:UIBarButtonItemStylePlain target:self action:@selector(goToDeviceSettingVC)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon_menu"] style:UIBarButtonItemStylePlain target:self action:@selector(goToGetPhoto)];
}

- (void)updateUI {
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        // 在后台不用去更新，因为每次界面显示都会更新一次UI
        return;
    }
    if (self.device) {
        self.navigationItem.title = self.device.deviceName;
    }
    [self setupControlDeviceBtnText];
    [self.deviceListVC reloadView];
    [self updateAnnotation];
}

- (void)setupControlDeviceBtnText {
    NSString *deviceName = self.device.deviceName;
    [self.controlDeviceBtn setTitle:[NSString stringWithFormat:@"Ring %@", deviceName] forState:UIControlStateNormal];
}

- (void)addDeviceListView {
    self.deviceListVC = [InDeviceListViewController deviceListViewController];
    self.deviceListVC.delegate = self;
    [self addChildViewController:self.deviceListVC];
    [self.deviceListBodyView addSubview:self.deviceListVC.view];
    self.deviceListVC.view.frame = self.deviceListBodyView.bounds;
    [self deviceListViewController:self.deviceListVC moveDown:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSLog(@"keyPath = %@发生改变, change = %@, object = %@",keyPath, change, object);
}

#pragma mark - Action
//控制设备
- (IBAction)controlDeviceBtnDidClick:(UIButton *)sender {
    if (self.searchPhoneDevices.count > 0) {
        // 清楚所有正在查找手机的设备信息
        for (NSString *mac in self.searchPhoneDevices.allKeys) {
            DLDevice *device = self.searchPhoneDevices[mac];
            device.isSearchPhone = NO;
        }
        [self.searchPhoneDevices removeAllObjects];
        [self stopSearchPhone];
        return;
    }
//    NSLog(@"下发控制指令");
    if (self.device.online) {
        if (self.device.isSearchDevice) {
            self.device.isSearchDevice = NO;
            NSLog(@"关闭查找设备");
            [self stopBtnAnimation];
        }
        else {
            NSLog(@"打开查找设备");
            self.device.isSearchDevice = YES;
            [self startBtnAnimation];
            [self.device startSearchDeviceTimer]; // 开启查找需要监听，防止出现发送失败，一直在闪烁按钮的问题
        }
        [self.device searchDevice];
    }
    else {
        if (self.device.isSearchDevice) { // 离线状态，如果手机在查找设备，要去关闭按钮动画
            self.device.isSearchDevice = NO;
            [self stopBtnAnimation];
        }
    }
}

//进入设备设置界面
- (void)goToDeviceSettingVC {
    NSLog(@"进入设备设置界面");
    InDeviceSettingViewController *vc = [InDeviceSettingViewController deviceSettingViewController];
    vc.device = self.device;
    [self safePushViewController:vc];
}

- (IBAction)toLocation {
    NSLog(@"开始定位");
    [self.mapView setCenterCoordinate:self.mapView.userLocation.coordinate];
}

- (IBAction)toSwitchMapMode {
    NSLog(@"切换地图模式");
    //    MKMapTypeStandard = 0,
    //    MKMapTypeSatellite,
    if (self.mapView.mapType == MKMapTypeStandard) {
        self.mapView.mapType = MKMapTypeSatellite;
    }
    else {
        self.mapView.mapType = MKMapTypeStandard;
    }
}

#pragma mark - 更新设备数据
- (void)device:(DLDevice *)device didUpdateData:(NSDictionary *)data{
    if (device == self.device) {
        [self updateUI];
    }
}

- (void)updateDevice:(DLDevice *)device {
    self.device = device;
    [self.device getDeviceInfo];
    [self updateUI];
    [self toLocation];
}

#pragma mark - deviceListDelegate
- (void)deviceListViewController:(InDeviceListViewController *)menuVC didSelectedDevice:(DLDevice *)device {
//    [self deviceListViewController:self.deviceListVC moveDown:MAXFLOAT];
    if (device != self.device) {
        [self updateDevice:device];
    }
}

- (void)deviceListViewControllerDidSelectedToAddDevice:(InDeviceListViewController *)menuVC {
    InSelectionViewController *selectionViewController = [InSelectionViewController selectionViewController:^{
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:selectionViewController];
    [self presentViewController:nav animated:YES completion:nil];
}

// 设备列表-上下滑动的处理
- (void)deviceListViewController:(InDeviceListViewController *)menuVC moveDown:(BOOL)down {
    CGFloat heightConstant;
    if (down) {
        //往下
        CGFloat minHeight = 196;
        //        if ([DLCloudDeviceManager sharedInstance].cloudDeviceList.count > 1) {
        //            minHeight = 146;
        //        }
        CGFloat maxMenuHeight = [UIScreen mainScreen].bounds.size.height * 0.5;
        heightConstant = minHeight - maxMenuHeight;
    }
    else {
        // 往上
        heightConstant = 0;
    }
    [UIView animateWithDuration:0.25 animations:^{
        self.deviceListBodyHeightConstraint.constant = heightConstant;
    }];
  
}


#pragma mark - Map
-(void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
//    NSLog(@"地图用户位置更新, %f, %f", userLocation.coordinate.latitude, userLocation.coordinate.longitude);
    [InCommon sharedInstance].currentLocation = userLocation.coordinate;
}

// 画自定义大头针的方法
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    NSLog(@"%@", NSStringFromClass([annotation class]));
    if ([annotation isKindOfClass:[InAnnotation class]]) {
        InAnnotation *myAnnotation = (InAnnotation *)annotation;
        NSString *reuseID = @"InAnnotationView";
        InAnnotationView *annotationView = (InAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:reuseID];
        if (annotationView == nil) {
            annotationView = [[InAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuseID];
            annotationView.canShowCallout = YES;
        }
        myAnnotation.annotationView = annotationView;
        return annotationView;
    }
    return nil;
}

- (void)goToLocationOfflineDevice:(UIButton *)btn {
    for (NSString *mac in self.deviceAnnotation.allKeys) {
        InAnnotation *annotation = self.deviceAnnotation[mac];
        if (annotation.annotationView.rightCalloutAccessoryView == btn) {
            [self goThereWithAddress:@"DJDS" andLat:[NSString stringWithFormat:@"%f", annotation.coordinate.latitude] andLon:[NSString stringWithFormat:@"%f", annotation.coordinate.longitude]];
            NSLog(@"去定位离线设备的位置, %f, %f", annotation.coordinate.longitude, annotation.coordinate.latitude);
        }
    }
}

- (void)deviceChangeOnline:(NSNotification *)notification {
//    NSLog(@"接收到设备:%@, 状态改变的通知: %@",  notification.object);
    [self updateAnnotation];
}

- (void)updateAnnotation{
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        return;
    }
    NSMutableDictionary *cloudDeviceList = [DLCloudDeviceManager sharedInstance].cloudDeviceList;
    for (NSString *mac in cloudDeviceList.allKeys) {
        DLDevice *device = cloudDeviceList[mac];
        InAnnotation *annotation = [self.deviceAnnotation objectForKey:mac];
        if (device.online && annotation) {
            // 设备在线，但是存在大头针，删除大头针
            [self.deviceAnnotation removeObjectForKey:mac];
            [self.mapView removeAnnotation:annotation];
        }
        else if (!device.online && !annotation) {
            annotation = [[InAnnotation alloc] init];
            annotation.title = [NSString stringWithFormat:@"%@", device.deviceName];
            annotation.coordinate = device.coordinate;
            [self reversGeocode:annotation.coordinate completion:^(NSString *str) {
                annotation.subtitle = str;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self.mapView selectAnnotation:annotation animated:YES];
                });
            }];
            annotation.device = device;
            [self.deviceAnnotation setObject:annotation forKey:mac];
            [self.mapView addAnnotation:annotation];
        }
        else if(!device.online && annotation) {
            annotation.title = [NSString stringWithFormat:@"%@", device.deviceName];
            annotation.coordinate = device.coordinate;
        }
    }
}

/**
 *  反地理编码: 把经纬度转换地名
 */
- (void)reversGeocode:(CLLocationCoordinate2D)coordinate completion:(void (^)(NSString *))completion{
    //  1. 取出经纬度信息
    NSString *latitudeStr = [NSString stringWithFormat:@"%f", coordinate.latitude];
    NSString *longitudeStr = [NSString stringWithFormat:@"%f", coordinate.longitude];
    
    //  创建位置对象
    CLLocation *location = [[CLLocation alloc] initWithLatitude:latitudeStr.doubleValue longitude:longitudeStr.doubleValue];
    
    //  1. 创建地理编码器
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    //  2. 反地理编码,
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        
        for (CLPlacemark *placemark in placemarks) {
            NSMutableString *address = [NSMutableString stringWithString:@"Near "];
            if (placemark.subThoroughfare.length > 0) {
                [address appendFormat:@"%@ ", placemark.subThoroughfare];
            }
            if (placemark.thoroughfare.length > 0) {
                [address appendFormat:@"%@, ", placemark.thoroughfare];
            }
            if (placemark.subLocality.length > 0) {
                [address appendFormat:@"%@ ", placemark.subLocality];
            }
            if (placemark.locality.length > 0) {
                [address appendFormat:@"%@", placemark.locality];
            }
            if (completion) {
                completion(address);
            }
        }
    }];
}

-(BOOL)canOpenUrl:(NSString *)string {
    
    return  [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:string]];
    
}

- (void)goThereWithAddress:(NSString *)address andLat:(NSString *)lat andLon:(NSString *)lon {
    
    if ([self canOpenUrl:@"baidumap://"]) {///跳转百度地图
        
        NSString *urlString = [[NSString stringWithFormat:@"baidumap://map/direction?origin={{我的位置}}&destination=latlng:%@,%@|name=%@&mode=driving&coord_type=bd09ll",lat, lon,address] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
        
        return;
        
    }else if ([self canOpenUrl:@"iosamap://"]) {///跳转高德地图
        
        NSString *urlString = [[NSString stringWithFormat:@"iosamap://navi?sourceApplication=%@&backScheme=%@&lat=%@&lon=%@&dev=0&style=2",@"神骑出行",@"TrunkHelper",lat, lon] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
        
        return;
        
    }else{////跳转系统地图
        
        CLLocationCoordinate2D loc = CLLocationCoordinate2DMake([lat doubleValue], [lon doubleValue]);
        
        MKMapItem *currentLocation = [MKMapItem mapItemForCurrentLocation];
        
        MKMapItem *toLocation = [[MKMapItem alloc] initWithPlacemark:[[MKPlacemark alloc] initWithCoordinate:loc addressDictionary:nil]];
        
        [MKMapItem openMapsWithItems:@[currentLocation, toLocation]
         
                       launchOptions:@{MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
                                       
                                       MKLaunchOptionsShowsTrafficKey: [NSNumber numberWithBool:YES]}];
        
        return;
        
    }
    
}

- (void)deviceRSSIChange:(NSNotification *)noti {
    DLDevice *device = noti.object;
    if (device.mac == self.device.mac) {
        [self updateUI];
    }
}

#pragma mark - 安全跳转界面
- (void)safePopViewController: (UIViewController *)viewController {
    if (self.navigationController.viewControllers.lastObject == self) {
        [self.navigationController popToViewController:viewController animated:YES];
        return;
    }
}

- (void)safePushViewController:(UIViewController *)viewController {
    if (self.navigationController.viewControllers.lastObject == self) {
        [self.navigationController pushViewController:viewController animated:YES];
        return;
    }
}

#pragma mark - Take photo
- (void)goToGetPhoto {
//    NSLog(@"去获取图片");
    self.imagePikerViewController.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.imagePikerViewController.showsCameraControls = NO;
    [[NSBundle mainBundle] loadNibNamed:@"InCustomTablePhotoVuew" owner:self options:nil];
    self.customTakePhotoView.frame = self.imagePikerViewController.cameraOverlayView.frame;
    self.customTakePhotoView.backgroundColor = [UIColor clearColor];
    self.imagePikerViewController.cameraOverlayView = self.customTakePhotoView;
    self.customTakePhotoView = nil;
    [self presentViewController:self.imagePikerViewController animated:YES completion:NULL];
    self.imageBodyView.hidden = YES;
    self.inTakePhoto = YES;
}

- (void)setUpImagePiker {
    // 设置相机的
    self.imagePikerViewController = [[UIImagePickerController alloc] init];
    self.imagePikerViewController.delegate = self;
    self.imagePikerViewController.allowsEditing = YES;
    // 设置相册的
    self.libraryPikerViewController = [[UIImagePickerController alloc] init];
    self.libraryPikerViewController.delegate = self;
    self.libraryPikerViewController.allowsEditing = YES;
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    // 设置相册的导航栏
    [self.libraryPikerViewController.navigationBar setBarTintColor:[UIColor clearColor]];
    [self.libraryPikerViewController.navigationBar setTranslucent:NO];
    [self.libraryPikerViewController.navigationBar setTintColor:[UIColor whiteColor]];
#warning 看是否需要设置导航栏
//    [InCommon setNavgationBar:self.libraryPikerViewController.navigationBar];
//    // 设置标题颜色
//    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
//    attrs[NSForegroundColorAttributeName] = [UIColor whiteColor];
//    [self.libraryPikerViewController.navigationBar setTitleTextAttributes:attrs];
}
- (IBAction)setPhotoSharkLight {
    NSLog(@"设置闪光灯");
//    [common setupSharkLight];
}

- (IBAction)changeCameraDirection {
    NSLog(@"改变相机的方向");
//    [self swapFrontAndBackCameras];
}

//// 切换前后置摄像头
//- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position
//{
//    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
//    for (AVCaptureDevice *device in devices )
//        if ( device.position == position )
//            return device;
//    return nil;
//}
//
//- (void)swapFrontAndBackCameras {
//    NSArray *inputs =self.captureSession.inputs;
//    for (AVCaptureDeviceInput *input in inputs) {
//        AVCaptureDevice *device = input.device;
//        if ([device hasMediaType:AVMediaTypeVideo]) {
//            AVCaptureDevicePosition position = device.position;
//            AVCaptureDevice *newCamera =nil;
//            AVCaptureDeviceInput *newInput =nil;
//            if (position ==AVCaptureDevicePositionFront)
//            {
//                NSLog(@"当前是前置摄像头，要切换到后置摄像头");
//                newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
//            }
//            else
//            {
//                NSLog(@"当前是后置摄像头，要切换到前置摄像头");
//                newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
//            }
//            newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
//            [self.captureSession beginConfiguration];
//            [self.captureSession removeInput:input];
//            [self.captureSession addInput:newInput];
//            [self.captureSession commitConfiguration];
//            break;
//        }
//    }
//}

- (IBAction)goPhotoLibrary {
    NSLog(@"进入相册");
    // 解决iPhone5S上导航栏会消失的Bug
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    self.libraryPikerViewController.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    [self.imagePikerViewController presentViewController:self.libraryPikerViewController animated:YES completion:NULL];
    self.inTakePhoto = NO;
}

- (IBAction)takePhoto {
    NSLog(@"拍照保存");
    [self.imagePikerViewController takePicture];
}

- (IBAction)takePhotoBack {
    NSLog(@"拍完照返回");
    [self dismissViewControllerAnimated:YES completion:NULL];
    self.inTakePhoto = NO;
}

- (void)goBackTakePhotoView {
    [self.imagePikerViewController dismissViewControllerAnimated:YES completion:nil];
    self.inTakePhoto = YES;
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    if (picker == self.libraryPikerViewController) {
//        self.imageBodyView.hidden = NO;
        // 相册界面点击图片显示
//        UIImage * image = info[UIImagePickerControllerOriginalImage];
//        self.imageView.image = image;
        [self goBackTakePhotoView];
        return;
    }
    else if (picker == self.imagePikerViewController) {
        // 相机拍完照进入保存
        UIImage * image = info[UIImagePickerControllerEditedImage];
        if (!image) {
            image = info[UIImagePickerControllerOriginalImage];
        }
//        self.imageView.image = image;
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSaveImageWithError:contextInfo:), (__bridge void *)self);
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self goBackTakePhotoView];
}

- (void)image:(UIImage *)image didFinishSaveImageWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSLog(@"保存图片结果: image = %@, error = %@, contextInfo = %@", image, error, contextInfo);
}

#pragma mark - 按钮动画
// 查找设备的按钮动画存在一个问题：由于查找设备回复和通过设备主动控制上报的值是相同的，无法分辨，在打开设备的时候，去关闭，马上又打开，可能会出现动画被停止重新开始的情况：手机打开 -> 设备回复在被查找，并警报 -> 手机关闭按钮 -> 手机打开按钮 ->(关闭到打开的时间太短，所以这里又回了一次设备被关闭的回复，动画被关闭) -> 刚刚最后一次打开的回复（动画重新被打开）
// 没有改进方案，因为无法辨别是回复还是设备被找到，设备的按钮被按的情况，所以在每次回复都肯定要处理,否则没有处理回复，意味着按设备按钮无法关闭手机按钮的动画,下发指令到回复测试2秒左右
- (void)startBtnAnimation {
//    NSLog(@"打开按钮动画");
    if (!self.isBtnAnimation) {
        self.isBtnAnimation = YES;
        self.btnTextIsHide = NO;
        [self.animationTimer setFireDate:[NSDate distantPast]];
    }
}

- (void)stopBtnAnimation {
//    NSLog(@"关闭按钮动画");
    self.isBtnAnimation = NO;
    [self.animationTimer setFireDate:[NSDate distantFuture]];
    // 显示按钮文字
    self.btnTextIsHide = YES;
    [self showBtnAnimation];
}

- (void)showBtnAnimation {
    self.btnTextIsHide = !self.btnTextIsHide;
    if (!self.btnTextIsHide) {
        [self setupControlDeviceBtnText];
    }
    else {
        [self.controlDeviceBtn setTitle:@"" forState:UIControlStateNormal];
    }
}

- (void)searchPhone:(NSNotification *)noti {
    if (self.inTakePhoto) {
        [self takePhoto];
        return;
    }
    DLDevice *device = noti.userInfo[@"Device"];
    if (device.isSearchPhone) {
        device.isSearchPhone = NO;
        [self.searchPhoneDevices removeObjectForKey:device.mac];
        [self stopSearchPhone];
    }
    else {
        if (self.searchPhoneDevices.count == 0) {
            // 只有在当前没有声音和闪光动画的时候才需要去开启
//            [common playSoundAlertMusic];
            [self startBtnAnimation];
        }
        
        device.isSearchPhone = YES;
        [self.searchPhoneDevices setValue:device forKey:device.mac];
        
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            // 发送本地通知
            [common sendLocalNotification:[NSString stringWithFormat:@"%@ is finding iPhone now!", device.deviceName]];
        }
    }
}

- (void)stopSearchPhone {
    if (self.searchPhoneDevices.count == 0) {
//        [common stopSoundAlertMusic];
        [self stopBtnAnimation];
    }
}

- (void)homeBtnDidClick {
    NSLog(@"home键被按");
}

- (void)searchDeviceAlert:(NSNotification *)noti {
    DLDevice *device = noti.userInfo[@"device"];
    if (device == self.device) {
        if (device.isSearchDevice) {
            [self startBtnAnimation];
        }
        else {
            [self stopBtnAnimation];
        }
    }
}

#pragma mark - Properity
- (NSMutableDictionary *)deviceAnnotation {
    if (!_deviceAnnotation) {
        _deviceAnnotation = [NSMutableDictionary dictionary];
    }
    return _deviceAnnotation;
}

//- (AVCaptureSession *)captureSession
//{
//    if(_captureSession == nil)
//    {
//        _captureSession = [[AVCaptureSession alloc] init];
//        //设置分辨率
//        if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
//            _captureSession.sessionPreset=AVCaptureSessionPreset1280x720;
//        }
//        
//        //添加摄像头
//        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
//        NSLog(@"devices = %@", devices);
//        for (AVCaptureDevice *device in devices) {
//            AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
//            if ([_captureSession canAddInput:deviceInput]){
//                [_captureSession addInput:deviceInput];
//            }
//        }
//    }
//    return _captureSession;
//}

@end
