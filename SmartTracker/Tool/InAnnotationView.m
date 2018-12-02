//
//  InAnnotationView.m
//  Innway
//
//  Created by danly on 2018/9/2.
//  Copyright © 2018年 innwaytech. All rights reserved.
//

#import "InAnnotationView.h"

@implementation InAnnotation
@end


#define TitleFont  17
#define MaxSize    CGSizeMake(250, 100)

@implementation NSString (Bubble)

- (CGSize)sizeWithText:(UIFont *)font maxSize:(CGSize)maxSize

{
    NSDictionary *attrs = @{NSFontAttributeName : font};
    return [self boundingRectWithSize:maxSize options:NSStringDrawingUsesLineFragmentOrigin attributes:attrs context:nil].size;
}

@end

@interface UIBubbleBtn:UIButton
@end

@implementation UIBubbleBtn

- (CGRect)titleRectForContentRect:(CGRect)contentRect {
    // 上：10 下：10 左：10 右：22
    CGSize titleSize = [self.currentTitle sizeWithText:[UIFont systemFontOfSize:TitleFont] maxSize:MaxSize];
    CGFloat width = titleSize.width;
    CGFloat heigth = contentRect.size.height - 32;
    CGFloat x = (contentRect.size.width - titleSize.width) * 0.5;
    CGFloat y = 10;
    return CGRectMake(x, y, width, heigth);
}

@end


@interface InAnnotationView()
@property (nonatomic, weak) UIBubbleBtn *bubble;
@end

@implementation InAnnotationView

- (void)setAnnotation:(id<MKAnnotation>)annotation
{
    [super setAnnotation:annotation];
    if ([annotation isMemberOfClass:[InAnnotation class]]) {
        self.image = [UIImage imageNamed:@"annotation"];
    }
    
}

//#pragma mark - 气泡设置
//- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    NSLog(@"被选中");
//    if (self.bubble.hidden) {
//        [self.bubble setTitle:self.annotation.title forState:UIControlStateNormal];
//        CGSize titleSize = [self.annotation.title sizeWithText: [UIFont systemFontOfSize:TitleFont] maxSize:MaxSize];
//        CGFloat width = titleSize.width + 20;
//        CGFloat height = titleSize.height + 32;
//        CGFloat x = self.frame.size.width * 0.5 - 26;
//        CGFloat y = -height;
//        self.bubble.frame = CGRectMake(x, y, width, height);
//
//    }
//    self.bubble.hidden = !self.bubble.hidden;
//}

//- (UIButton *)bubble {
//    if (!_bubble) {
//        UIBubbleBtn *btn = [[UIBubbleBtn alloc] init];
//        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
//        btn.titleLabel.font = [UIFont systemFontOfSize:TitleFont];
//        UIImage *image = [UIImage imageNamed:@"bubble"];
//        // 在图片端设置变型w
////        UIEdgeInsets insets = UIEdgeInsetsMake(10, 10, 50, 10);
////        image = [image resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch];
//        [btn setBackgroundImage:image forState:UIControlStateNormal];
//        [self addSubview:btn];
//        _bubble = btn;
//        _bubble.hidden = YES;
//    }
//    return _bubble;
//}

@end
