//
//  ScrollTextLabel.h
//  TestMarQueeLabel
//
//  Created by hzzhanyawei on 15/9/22.
//  Copyright © 2015年 Netease. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 *  滚动的类型
 */
typedef NS_ENUM(NSInteger, ScrollTextLabelType){
    /**
     *  从右至左循环滚动
     */
    STL_Forward = 0,
    /**
     *  从左至右循环滚动
     */
    STL_Backward,
    /**
     *  从右至左来回滚动
     */
    STL_RightToLeft,
    /**
     *  从左至右来回滚动
     */
    STL_LeftToRight
};

@interface ScrollTextLabel : UILabel

/**
 *  滚动的类型。
 */
@property (nonatomic, assign)ScrollTextLabelType type;
/**
 *  滚动的速率，值越大速度越快
 */
@property (nonatomic, assign)IBInspectable CGFloat rate;
/**
 *  平滑区域长度，文字首尾平滑渐变区域的大小。
 */
@property (nonatomic, assign)IBInspectable CGFloat fadeLength;
/**
 *  尾部空白长度，滚动一圈后
 */
@property (nonatomic, assign)IBInspectable CGFloat tailBlankLength;
/**
 *  滚动开始的时延,可以不设置，默认是1s
 */
@property (nonatomic, assign)IBInspectable CGFloat animationDelay;




/**
 *  初始化ScrollTextLabel
 *
 *  @param frame 显示区域
 *
 *  @return ScrollTextLabel实例
 */
- (instancetype)initWithFrame:(CGRect)frame;
/**
 *  初始化ScrollTextLabel
 *
 *  @param frame           显示区域
 *  @param pixelsPerSecond 滚动速率
 *  @param fadeLength      平滑区域长度
 *  @param tailBlankLength 尾部空白区域长度
 *
 *  @return ScrollTextLabel实例
 */
- (instancetype)initWithFrame:(CGRect)frame rate:(CGFloat)pixelsPerSecond andFadeLength:(CGFloat)fadeLength andTailBlankLength:(CGFloat)tailBlankLength;

/**
 *  开始滚动
 */
- (void)startScroll;

/**
 *  停止滚动
 */
- (void)stopScroll;

@end
