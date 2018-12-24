//
//  MainViewController.h
//  YBImageBrowserDemo
//
//  Created by 杨波 on 2018/9/13.
//  Copyright © 2018年 杨波. All rights reserved.
//

#import <UIKit/UIKit.h>

@class LibraryViewController;
@protocol LibraryViewControllerDelegate <NSObject>

- (void)libraryViewControllerDidClickGoBack:(LibraryViewController *)vc;

@end

@interface LibraryViewController : UIViewController

@property (nonatomic, weak) id<LibraryViewControllerDelegate> delegate;

@end
