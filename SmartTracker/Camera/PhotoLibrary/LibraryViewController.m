//
//  MainViewController.m
//  YBImageBrowserDemo
//
//  Created by 杨波 on 2018/9/13.
//  Copyright © 2018年 杨波. All rights reserved.
//

#import "LibraryViewController.h"
#import "LibraryImageCell.h"
#import "YBIBUtilities.h"
#import "YBImageBrowser.h"

static NSString * const kReuseIdentifierOfMainImageCell = @"kReuseIdentifierOfMainImageCell";

@interface LibraryViewController () <UICollectionViewDataSource, UICollectionViewDelegate, YBImageBrowserDataSource, YBImageBrowserDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, copy) NSArray *dataArray;
@end

@implementation LibraryViewController

#pragma mark - Show 'YBImageBrowser' : System album
- (void)showBrowserForSystemAlbumWithIndex:(NSInteger)index {
    YBImageBrowser *browser = [YBImageBrowser new];
    browser.dataSource = self;
    browser.currentIndex = index;
    [browser show];
}

// <YBImageBrowserDataSource>

- (NSUInteger)yb_numberOfCellForImageBrowserView:(YBImageBrowserView *)imageBrowserView {
    return self.dataArray.count;
}

- (id<YBImageBrowserCellDataProtocol>)yb_imageBrowserView:(YBImageBrowserView *)imageBrowserView dataForCellAtIndex:(NSUInteger)index {
    PHAsset *asset = (PHAsset *)self.dataArray[index];
    if (asset.mediaType == PHAssetMediaTypeVideo) {
        
        // Type 1 : 系统相册的视频 / Video of system album
        YBVideoBrowseCellData *data = [YBVideoBrowseCellData new];
        data.phAsset = asset;
        data.sourceObject = [self sourceObjAtIdx:index];

        return data;
    } else if (asset.mediaType == PHAssetMediaTypeImage) {
        
        // Type 2 : 系统相册的图片 / Image of system album
        YBImageBrowseCellData *data = [YBImageBrowseCellData new];
        data.phAsset = asset;
        data.sourceObject = [self sourceObjAtIdx:index];

        return data;
    }
    return nil;
}


#pragma mark - Tool
- (id)sourceObjAtIdx:(NSInteger)idx {
    LibraryImageCell *cell = (LibraryImageCell *)[self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]];
    return cell ? cell.mainImageView : nil;
}

#pragma mark - life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.collectionView];
    self.dataArray = [self.class getPHAssets];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(goBack)];
    self.navigationItem.title = @"Photo Library";
    [self detectionPhotoState];
}


- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

// 解决第一次访问授权提问的时候，不能加载出图片的问题
- (void)detectionPhotoState
{
    PHAuthorizationStatus authStatus = [PHPhotoLibrary authorizationStatus];
    //用户尚未授权
    if (authStatus == PHAuthorizationStatusNotDetermined)
    {
        __weak typeof(self) weakSelf = self;
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized)
            {
                NSLog(@"相册已授权， %@", [NSThread currentThread]);
                weakSelf.dataArray = [weakSelf.class getPHAssets];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.collectionView reloadData];
                });
            }
        }];
    }
}

#pragma mark - <UICollectionViewDataSource, UICollectionViewDelegate>
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.dataArray.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    LibraryImageCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kReuseIdentifierOfMainImageCell forIndexPath:indexPath];
    cell.data = self.dataArray[indexPath.row];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self showBrowserForSystemAlbumWithIndex:indexPath.row];
}

#pragma mark - getter
- (UICollectionView *)collectionView {
    if (!_collectionView) {
        CGFloat padding = 5, cellLength = ([UIScreen mainScreen].bounds.size.width - padding * 2) / 3;
        UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
        layout.itemSize = CGSizeMake(cellLength, cellLength);
        layout.sectionInset = UIEdgeInsetsMake(padding, padding, padding, padding);
        layout.minimumLineSpacing = 0;
        layout.minimumInteritemSpacing = 0;
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) collectionViewLayout:layout];
        [_collectionView registerNib:[UINib nibWithNibName:NSStringFromClass(LibraryImageCell.class) bundle:nil] forCellWithReuseIdentifier:kReuseIdentifierOfMainImageCell];
        _collectionView.backgroundColor = [UIColor whiteColor];
        _collectionView.alwaysBounceVertical = YES;
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
    }
    return _collectionView;
}


#pragma mark - Photo
+ (NSArray *)getPHAssets {
    NSMutableArray *resultArray = [NSMutableArray array];
    PHFetchResult *smartAlbumsFetchResult0 = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
    [smartAlbumsFetchResult0 enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PHAssetCollection  *_Nonnull collection, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray<PHAsset *> *assets = [self getAssetsInAssetCollection:collection];
        [resultArray addObjectsFromArray:assets];
    }];
    
    PHFetchResult *smartAlbumsFetchResult1 = [PHAssetCollection fetchTopLevelUserCollectionsWithOptions:nil];
    [smartAlbumsFetchResult1 enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PHAssetCollection * _Nonnull collection, NSUInteger idx, BOOL *stop) {
        NSArray<PHAsset *> *assets = [self getAssetsInAssetCollection:collection];
        [resultArray addObjectsFromArray:assets];
    }];
    
    return resultArray;
}

+ (NSArray *)getAssetsInAssetCollection:(PHAssetCollection *)assetCollection {
    NSMutableArray<PHAsset *> *arr = [NSMutableArray array];
    PHFetchResult *result = [PHAsset fetchAssetsInAssetCollection:assetCollection options:nil];
    [result enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PHAsset *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.mediaType == PHAssetMediaTypeImage) {
            [arr addObject:obj];
        } else if (obj.mediaType == PHAssetMediaTypeVideo) {
            [arr addObject:obj];
        }
    }];
    return arr;
}

- (void)goBack {
    if ([self.delegate respondsToSelector:(@selector(libraryViewControllerDidClickGoBack:))]) {
        [self.delegate libraryViewControllerDidClickGoBack:self];
    }
}

@end
