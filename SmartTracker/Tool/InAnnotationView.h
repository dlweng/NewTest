//
//  InAnnotationView.h
//
//  Created by danly on 2018/9/2.
//  Copyright © 2018年 . All rights reserved.
//

#import <MapKit/MapKit.h>

@class InAnnotationView;
@class DLDevice;
@interface InAnnotation : MKPointAnnotation
@property (nonatomic, strong) InAnnotationView *annotationView;
@property (nonatomic, strong) DLDevice *device;
@end


@interface InAnnotationView : MKAnnotationView
@end
