//
//  ScrollTextLabel.m
//  TestMarQueeLabel
//
//  Created by hzzhanyawei on 15/9/22.
//  Copyright © 2015年 Netease. All rights reserved.
//

#import "ScrollTextLabel.h"
#import <QuartzCore/QuartzCore.h>


typedef void(^STLAnimationCompletionBlock)(BOOL finished);

/**
 *  用于获取ScorllTextLabel的第一个响应的ViewController。在Navigation模式下可以通过判断是否是当前导航的ViewController来启动或者关闭滚动。（也可以通过代理实现获取ViewController）
 */
@interface UIView (ScrollTextLabelHelper)
- (id)firstResponseViewController;
- (id)traverseResponderChainForFirstViewController;

@end

@interface CAMediaTimingFunction (ScrollTextLabelHelper)
- (NSArray *)controlPoints;
- (CGFloat)durationPercentageForPositionPercentage:(CGFloat)positionPercentage withDuration:(NSTimeInterval)duration;
@end



@interface ScrollTextLabel()

@property (nonatomic, retain)UILabel* subLabel;
@property (nonatomic, assign)NSTimeInterval animationDuration;
@property (nonatomic, assign)CGRect homeLabelFrame;
@property (nonatomic, assign)CGFloat awayOffset;

@end

@implementation ScrollTextLabel

#pragma mark - 初始化函数
- (instancetype)initWithFrame:(CGRect)frame{
    return [self initWithFrame:frame rate:0.0 andFadeLength:0.0 andTailBlankLength:0.0];
}

- (instancetype)initWithFrame:(CGRect)frame rate:(CGFloat)pixelsPerSecond andFadeLength:(CGFloat)fadeLength andTailBlankLength:(CGFloat)tailBlankLength{
    
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLabel];
        
        _rate = pixelsPerSecond;
        _fadeLength = MIN(fadeLength, frame.size.width/2);
        _tailBlankLength = tailBlankLength;
    }
    return self;
}

- (void)setupLabel{
    //复写UILabel属性
    self.clipsToBounds = YES;
    self.numberOfLines = 1;
    
    //创建subLabel
    UILabel* label = [[UILabel alloc] initWithFrame:self.bounds];
    label.layer.anchorPoint = CGPointMake(0.0f, 0.0f);
    self.subLabel = label;
    [label autorelease];
    
    [self addSubview:self.subLabel];

    //设置属性默认值
    _fadeLength = 0.0;
    _animationDelay = 1.0;//滚动一圈后的停顿时间
    _animationDuration = 0.0;
    _tailBlankLength = 0.0;
    
    //注册消息响应函数
    //注册Navigationcontroller消息响应
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observedViewControllerChange:) name:@"UINavigationControllerDidShowViewControllerNotification" object:nil];
    //注册app启动和后台消息响应
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startScroll) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopScroll) name:UIApplicationDidEnterBackgroundNotification object:nil];
    

}
/**
 *  Navigationcontroller消息处理
 *
 *  @param notification
 */
- (void)observedViewControllerChange:(NSNotification*)notification{
    NSDictionary *userInfo = [notification userInfo];
    id fromController = [userInfo objectForKey:@"UINavigationControllerLastVisibleViewController"];
    id toController = [userInfo objectForKey:@"UINavigationControllerNextVisibleViewController"];
    
    id ownController = [self firstResponseViewController];
    if ([fromController isEqual:ownController]) {
        [self stopScroll];
    }
    else if ([toController isEqual:ownController]) {
        [self startScroll];
    }
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupLabel];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self forwardPropertiesToSubLabel];
}

+ (Class)layerClass {
    return [CAReplicatorLayer class];
}
/**
 *  将设置给ScrollTextLabel的Label属性设置到subLabel上。
 */
- (void)forwardPropertiesToSubLabel {
    // Since we're a UILabel, we actually do implement all of UILabel's properties.
    // We don't care about these values, we just want to forward them on to our sublabel.
    NSArray *properties = @[@"baselineAdjustment", @"enabled", @"highlighted", @"highlightedTextColor",
                            @"minimumFontSize", @"shadowOffset", @"textAlignment",
                            @"userInteractionEnabled", @"adjustsFontSizeToFitWidth",
                            @"lineBreakMode", @"numberOfLines"];
    
    self.subLabel.text = super.text;
    self.subLabel.font = super.font;
    self.subLabel.textColor = super.textColor;
    self.subLabel.backgroundColor = (super.backgroundColor == nil ? [UIColor clearColor] : super.backgroundColor);
    self.subLabel.shadowColor = super.shadowColor;
    for (NSString *property in properties) {
        id val = [super valueForKey:property];
        [self.subLabel setValue:val forKey:property];
    }
    
    super.attributedText = nil;
}



- (void)minimizeLabelFrameWithMaximumSize:(CGSize)maxSize adjustHeight:(BOOL)adjustHeight {
    if (self.subLabel.text != nil) {
        // Calculate text size
        if (CGSizeEqualToSize(maxSize, CGSizeZero)) {
            maxSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
        }
        CGSize minimumLabelSize = [self subLabelSize];
        
        // Adjust for fade length
        CGSize minimumSize = CGSizeMake(minimumLabelSize.width + (self.fadeLength * 2), minimumLabelSize.height);
        
        // Find minimum size of options
        minimumSize = CGSizeMake(MIN(minimumSize.width, maxSize.width), MIN(minimumSize.height, maxSize.height));
        
        // Apply to frame
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, minimumSize.width, (adjustHeight ? minimumSize.height : self.frame.size.height));
    }
}

-(void)didMoveToSuperview {
    [self updateSublabelAndLocations];
}

/**
 *  计算sublabel期望的size
 *
 *  @return size
 */
- (CGSize)subLabelSize {
    CGSize expectedLabelSize = CGSizeZero;
    CGSize maximumLabelSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
    
    
    expectedLabelSize = [self.subLabel sizeThatFits:maximumLabelSize];
    
    expectedLabelSize.width = ceil(MIN(expectedLabelSize.width, 8192.0f));
    expectedLabelSize.height = self.bounds.size.height;
    
    return expectedLabelSize;
}

/**
 *  通过给定的size返回最好的自适应size，并不会从新设置view的size，默认返回view的size
 *
 *  @param size 给定的size
 *
 *  @return 自使用的size
 */
- (CGSize)sizeThatFits:(CGSize)size {
    CGSize fitSize = [self.subLabel sizeThatFits:size];
    fitSize.width += 2.0f * self.fadeLength;
    return fitSize;
}

/**
 *  停止滚动
 */
- (void)returnLabelToOriginImmediately {
    [self.layer.mask removeAllAnimations];

    [self.subLabel.layer removeAllAnimations];
}

/**
 *  判断是否需要scorll，当字符串的长度超出边界事返回YES
 *
 *  @return YES/NO
 */
- (BOOL)labelShouldScroll {
    BOOL stringLength = ([self.subLabel.text length] > 0);
    if (!stringLength) {
        return NO;
    }
    
    BOOL labelTooLarge = ([self subLabelSize].width > self.bounds.size.width);
    return labelTooLarge;
}

/**
 *  设置左右渐变梯度
 *
 *  @param fadeLength 渐变的长度
 *  @param animated   是否动画
 */
- (void)applyGradientMaskForFadeLength:(CGFloat)fadeLength animated:(BOOL)animated {
    if (fadeLength <= 0.0f) {
        self.layer.mask = nil;
        return;
    }
    
    CAGradientLayer *gradientMask = (CAGradientLayer *)self.layer.mask;
    
    [gradientMask removeAllAnimations];
    
    if (!gradientMask) {
        gradientMask = [CAGradientLayer layer];
    }
    
    // Set up colors
    NSObject *transparent = (NSObject *)[[UIColor clearColor] CGColor];
    NSObject *opaque = (NSObject *)[[UIColor blackColor] CGColor];
    
    gradientMask.bounds = self.layer.bounds;
    gradientMask.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    gradientMask.shouldRasterize = YES;
    gradientMask.rasterizationScale = [UIScreen mainScreen].scale;
    gradientMask.startPoint = CGPointMake(0.0f, 0.5f);
    gradientMask.endPoint = CGPointMake(1.0f, 0.5f);
    // Start with "no fade" colors and locations
    gradientMask.colors = @[opaque, opaque, opaque, opaque];
    gradientMask.locations = @[@(0.0f), @(0.0f), @(1.0f), @(1.0f)];
    
    // Set mask
    self.layer.mask = gradientMask;
    
    CGFloat leftFadeStop = fadeLength/self.bounds.size.width;
    CGFloat rightFadeStop = fadeLength/self.bounds.size.width;
    
    // Adjust stops based on fade length
    NSArray *adjustedLocations = @[@(0.0), @(leftFadeStop), @(1.0 - rightFadeStop), @(1.0)];
    
    
    NSArray *adjustedColors;
    BOOL trailingFadeNeeded = self.labelShouldScroll;
    switch (self.type) {
        case STL_Backward:
        case STL_RightToLeft:
            adjustedColors = @[(trailingFadeNeeded ? transparent : opaque),
                               opaque,
                               opaque,
                               opaque];
            break;
            
        default:
            //STL_Forward
            adjustedColors = @[opaque,
                               opaque,
                               opaque,
                               (trailingFadeNeeded ? transparent : opaque)];
            break;
    }
    
    if (animated) {
        //为位置改变创建动画
        CABasicAnimation *locationAnimation = [CABasicAnimation animationWithKeyPath:@"locations"];
        locationAnimation.fromValue = gradientMask.locations;
        locationAnimation.toValue = adjustedLocations;
        locationAnimation.duration = 0.25;
        
        //为颜色改变创建动画
        CABasicAnimation *colorAnimation = [CABasicAnimation animationWithKeyPath:@"colors"];
        colorAnimation.fromValue = gradientMask.colors;
        colorAnimation.toValue = adjustedColors;
        colorAnimation.duration = 0.25;
        
        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.duration = 0.25;
        group.animations = @[locationAnimation, colorAnimation];
        
        [gradientMask addAnimation:group forKey:colorAnimation.keyPath];
        gradientMask.locations = adjustedLocations;
        gradientMask.colors = adjustedColors;
    } else {
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        gradientMask.locations = adjustedLocations;
        gradientMask.colors = adjustedColors;
        [CATransaction commit];
    }
}

/**
 *  产生一系列子视图的复制
 *
 *  @return 一系列子视图
 */
- (CAReplicatorLayer *)repliLayer {
    return (CAReplicatorLayer *)self.layer;
}


- (void)updateSublabelAndLocations{
    if (!self.subLabel.text || !self.superview) {
        return;
    }
    
    
    CGSize expectedLabelSize = [self subLabelSize];
    
    [self invalidateIntrinsicContentSize];
    
    [self returnLabelToOriginImmediately];
    
    [self applyGradientMaskForFadeLength:self.fadeLength animated:YES];
    
    if (!self.labelShouldScroll) {
        // 设置text的对齐方式和行截断方式，默认显示。
        self.subLabel.textAlignment = [super textAlignment];
        self.subLabel.lineBreakMode = [super lineBreakMode];
        
        CGRect labelFrame, unusedFrame;
        switch (self.type) {
            case STL_RightToLeft:
                CGRectDivide(self.bounds, &unusedFrame, &labelFrame, 0.0, CGRectMaxXEdge);
                labelFrame = CGRectIntegral(labelFrame);
                break;
                
            default:
                labelFrame = CGRectIntegral(CGRectMake(0.0f, 0.0f, self.bounds.size.width, self.bounds.size.height));
                break;
        }
        
        self.homeLabelFrame = labelFrame;
        self.awayOffset = 0.0f;
        
        // 设置子视图复制个数为1（不复制）
        self.repliLayer.instanceCount = 1;
        
        self.subLabel.frame = labelFrame;
        
        return;
    }
    
    //需要滚动的情况。
    [self.subLabel setLineBreakMode:NSLineBreakByClipping];
    
    // 第一个和第二个子视图（label）的间距必须大于尾部间距和渐变间距。
    CGFloat minTrailing = MAX(self.tailBlankLength, self.fadeLength);
    
    switch (self.type) {
        case STL_Forward:
        case STL_Backward:
        {
            if (self.type == STL_Forward) {
                self.homeLabelFrame = CGRectIntegral(CGRectMake(0.0f, 0.0f, expectedLabelSize.width, self.bounds.size.height));
                self.awayOffset = -(self.homeLabelFrame.size.width + minTrailing);
            } else {
                self.homeLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width - (expectedLabelSize.width ), 0.0f, expectedLabelSize.width, self.bounds.size.height));
                self.awayOffset = (self.homeLabelFrame.size.width + minTrailing);
            }
            
            self.subLabel.frame = self.homeLabelFrame;
            
            // 配置子视图的重复个数。
            self.repliLayer.instanceCount = 2;
            self.repliLayer.instanceTransform = CATransform3DMakeTranslation(-self.awayOffset, 0.0, 0.0);
            
            // 从新计算滚动持续时间。
            self.animationDuration = (self.rate != 0) ? ((NSTimeInterval) fabs(self.awayOffset) / self.rate) : 0.0;
            
            break;
        }
        
        case STL_LeftToRight:
        case STL_RightToLeft:
        {
            self.homeLabelFrame = CGRectIntegral(CGRectMake(self.bounds.size.width - (expectedLabelSize.width), 0.0f, expectedLabelSize.width, self.bounds.size.height));
            self.awayOffset = (expectedLabelSize.width + self.tailBlankLength) - self.bounds.size.width;
            
            self.animationDuration = (self.rate != 0) ? (NSTimeInterval)fabs(self.awayOffset / self.rate) : 0.0;
            
            // 设置视图帧
            self.subLabel.frame = self.homeLabelFrame;
            
            // 移除子视图拷贝
            self.repliLayer.instanceCount = 1;
            
            // 设置text右对齐
            self.subLabel.textAlignment = NSTextAlignmentRight;
            
            break;
        }
            
        default:
        {
            //处理特殊情况
            self.homeLabelFrame = CGRectZero;
            self.awayOffset = 0.0f;
            
            return;
            break;
        }
            
    }
     [self startScroll];
}

#pragma mark - 重定义UIlabel方法

- (UIView *)viewForBaselineLayout {
    // Use subLabel view for handling baseline layouts
    return self.subLabel;
}

- (NSString *)text{
    return self.subLabel.text;
}

- (void)setText:(NSString *)text{
    if ([text isEqualToString:self.subLabel.text]) {
        return;
    }
    _subLabel.text = text;
    [self updateSublabelAndLocations];
}

- (NSAttributedString *)attributedText {
    return self.subLabel.attributedText;
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if ([attributedText isEqualToAttributedString:self.subLabel.attributedText]) {
        return;
    }
    self.subLabel.attributedText = attributedText;
    [self updateSublabelAndLocations];
}

- (UIFont *)font {
    return self.subLabel.font;
}

- (void)setFont:(UIFont *)font {
    if ([font isEqual:self.subLabel.font]) {
        return;
    }
    self.subLabel.font = font;
    super.font = font;
    [self updateSublabelAndLocations];
}

- (UIColor *)textColor {
    return self.subLabel.textColor;
}

- (void)setTextColor:(UIColor *)textColor {
    self.subLabel.textColor = textColor;
    super.textColor = textColor;
}

- (UIColor *)backgroundColor {
    return self.subLabel.backgroundColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    self.subLabel.backgroundColor = backgroundColor;
    super.backgroundColor = backgroundColor;
}

- (UIColor *)shadowColor {
    return self.subLabel.shadowColor;
}

- (void)setShadowColor:(UIColor *)shadowColor {
    self.subLabel.shadowColor = shadowColor;
    super.shadowColor = shadowColor;
}

- (CGSize)shadowOffset {
    return self.subLabel.shadowOffset;
}

- (void)setShadowOffset:(CGSize)shadowOffset {
    self.subLabel.shadowOffset = shadowOffset;
    super.shadowOffset = shadowOffset;
}

- (UIColor *)highlightedTextColor {
    return self.subLabel.highlightedTextColor;
}

- (void)setHighlightedTextColor:(UIColor *)highlightedTextColor {
    self.subLabel.highlightedTextColor = highlightedTextColor;
    super.highlightedTextColor = highlightedTextColor;
}

- (BOOL)isHighlighted {
    return self.subLabel.isHighlighted;
}

- (void)setHighlighted:(BOOL)highlighted {
    self.subLabel.highlighted = highlighted;
    super.highlighted = highlighted;
}

- (BOOL)isEnabled {
    return self.subLabel.isEnabled;
}

- (void)setEnabled:(BOOL)enabled {
    self.subLabel.enabled = enabled;
    super.enabled = enabled;
}

- (void)setNumberOfLines:(NSInteger)numberOfLines {
    // By the nature of MarqueeLabel, this is 1
    [super setNumberOfLines:1];
}

- (void)setAdjustsFontSizeToFitWidth:(BOOL)adjustsFontSizeToFitWidth {
    // By the nature of MarqueeLabel, this is NO
    [super setAdjustsFontSizeToFitWidth:NO];
}

- (void)setMinimumFontSize:(CGFloat)minimumFontSize {
    [super setMinimumFontSize:0.0];
}

- (UIBaselineAdjustment)baselineAdjustment {
    return self.subLabel.baselineAdjustment;
}

- (void)setBaselineAdjustment:(UIBaselineAdjustment)baselineAdjustment {
    self.subLabel.baselineAdjustment = baselineAdjustment;
    super.baselineAdjustment = baselineAdjustment;
}

- (CGSize)intrinsicContentSize {
    return self.subLabel.intrinsicContentSize;
}

- (void)setAdjustsLetterSpacingToFitWidth:(BOOL)adjustsLetterSpacingToFitWidth {
    // By the nature of MarqueeLabel, this is NO
    [super setAdjustsLetterSpacingToFitWidth:NO];
}

- (void)setMinimumScaleFactor:(CGFloat)minimumScaleFactor {
    [super setMinimumScaleFactor:0.0f];
}


#pragma mark - 滚动控制函数

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self updateSublabelAndLocations];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (!newWindow) {
        [self stopScroll];
    }
}

- (void)didMoveToWindow {
    if (self.window) {
        [self updateSublabelAndLocations];
        [self startScroll];
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    [self againToScroll:flag];
}

/**
 *  检查是否滚动的条件是否完备。
 *
 *  @return YES/NO
 */
- (BOOL)labelReadyForScroll {
    if (!self.superview) {
        return NO;
    }
    
    if (!self.window) {
        return NO;
    }
    
    // 检查ViewController
    UIViewController *viewController = [self firstResponseViewController];
    if (!viewController.isViewLoaded) {
        return NO;
    }
    
    return YES;
}

- (CAMediaTimingFunction *)timingFunctionForAnimationOptions:(UIViewAnimationOptions)animationOptions {
    NSString *timingFunction;
    switch (animationOptions) {
        case UIViewAnimationOptionCurveEaseIn:
            timingFunction = kCAMediaTimingFunctionEaseIn;
            break;
            
        case UIViewAnimationOptionCurveEaseInOut:
            timingFunction = kCAMediaTimingFunctionEaseInEaseOut;
            break;
            
        case UIViewAnimationOptionCurveEaseOut:
            timingFunction = kCAMediaTimingFunctionEaseOut;
            break;
            
        default:
            timingFunction = kCAMediaTimingFunctionLinear;
            break;
    }
    
    return [CAMediaTimingFunction functionWithName:timingFunction];
}

//创建边缘渐变动画
- (CAKeyframeAnimation *)keyFrameAnimationForGradientFadeLength:(CGFloat)fadeLength
                                                       interval:(NSTimeInterval)interval
                                                          delay:(NSTimeInterval)delayAmount
{
    // Setup
    NSArray *values = nil;
    NSArray *keyTimes = nil;
    NSTimeInterval totalDuration;
    NSObject *transp = (NSObject *)[[UIColor clearColor] CGColor];
    NSObject *opaque = (NSObject *)[[UIColor blackColor] CGColor];
    
    // Create new animation
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"colors"];
    
    // Get timing function
    CAMediaTimingFunction *timingFunction = [self timingFunctionForAnimationOptions:UIViewAnimationOptionCurveLinear];
    
    // Define keyTimes
    switch (self.type) {
        case STL_LeftToRight:
        case STL_RightToLeft:
            // Calculate total animation duration
            totalDuration = 2.0 * (delayAmount + interval);
            keyTimes = @[
                         @(0.0),                                                        // 1) Initial gradient
                         @(delayAmount/totalDuration),                                  // 2) Begin of LE fade-in, just as scroll away starts
                         @((delayAmount + 0.4)/totalDuration),                          // 3) End of LE fade in [LE fully faded]
                         @((delayAmount + interval - 0.4)/totalDuration),               // 4) Begin of TE fade out, just before scroll away finishes
                         @((delayAmount + interval)/totalDuration),                     // 5) End of TE fade out [TE fade removed]
                         @((delayAmount + interval + delayAmount)/totalDuration),       // 6) Begin of TE fade back in, just as scroll home starts
                         @((delayAmount + interval + delayAmount + 0.4)/totalDuration), // 7) End of TE fade back in [TE fully faded]
                         @((totalDuration - 0.4)/totalDuration),                        // 8) Begin of LE fade out, just before scroll home finishes
                         @(1.0)];                                                       // 9) End of LE fade out, just as scroll home finishes
            break;
            
        case STL_Backward:
        default:
            // Calculate total animation duration
            totalDuration = delayAmount + interval;
            
            // Find when the lead label will be totally offscreen
            CGFloat startFadeFraction = fabs((self.subLabel.bounds.size.width) / self.awayOffset);
            // Find when the animation will hit that point
            CGFloat startFadeTimeFraction = [timingFunction durationPercentageForPositionPercentage:startFadeFraction withDuration:totalDuration];
            NSTimeInterval startFadeTime = delayAmount + startFadeTimeFraction * interval;
            
            keyTimes = @[
                         @(0.0),                                            // Initial gradient
                         @(delayAmount/totalDuration),                      // Begin of fade in
                         @((delayAmount + 0.2)/totalDuration),              // End of fade in, just as scroll away starts
                         @((startFadeTime)/totalDuration),                  // Begin of fade out, just before scroll home completes
                         @((startFadeTime + 0.1)/totalDuration),            // End of fade out, as scroll home completes
                         @(1.0)                                             // Buffer final value (used on continuous types)
                         ];
            break;
    }
    
    // Define gradient values
    switch (self.type) {
        case STL_Backward:
            values = @[
                       @[transp, opaque, opaque, opaque],           // Initial gradient
                       @[transp, opaque, opaque, opaque],           // Begin of fade in
                       @[transp, opaque, opaque, transp],           // End of fade in, just as scroll away starts
                       @[transp, opaque, opaque, transp],           // Begin of fade out, just before scroll home completes
                       @[transp, opaque, opaque, opaque],           // End of fade out, as scroll home completes
                       @[transp, opaque, opaque, opaque]            // Final "home" value
                       ];
            break;
            
        case STL_RightToLeft:
            values = @[
                       @[transp, opaque, opaque, opaque],           // 1)
                       @[transp, opaque, opaque, opaque],           // 2)
                       @[transp, opaque, opaque, transp],           // 3)
                       @[transp, opaque, opaque, transp],           // 4)
                       @[opaque, opaque, opaque, transp],           // 5)
                       @[opaque, opaque, opaque, transp],           // 6)
                       @[transp, opaque, opaque, transp],           // 7)
                       @[transp, opaque, opaque, transp],           // 8)
                       @[transp, opaque, opaque, opaque]            // 9)
                       ];
            break;
            
        case STL_Forward:
            values = @[
                       @[opaque, opaque, opaque, transp],           // Initial gradient
                       @[opaque, opaque, opaque, transp],           // Begin of fade in
                       @[transp, opaque, opaque, transp],           // End of fade in, just as scroll away starts
                       @[transp, opaque, opaque, transp],           // Begin of fade out, just before scroll home completes
                       @[opaque, opaque, opaque, transp],           // End of fade out, as scroll home completes
                       @[opaque, opaque, opaque, transp]            // Final "home" value
                       ];
            break;
            
        case STL_LeftToRight:
        default:
            values = @[
                       @[opaque, opaque, opaque, transp],           // 1)
                       @[opaque, opaque, opaque, transp],           // 2)
                       @[transp, opaque, opaque, transp],           // 3)
                       @[transp, opaque, opaque, transp],           // 4)
                       @[transp, opaque, opaque, opaque],           // 5)
                       @[transp, opaque, opaque, opaque],           // 6)
                       @[transp, opaque, opaque, transp],           // 7)
                       @[transp, opaque, opaque, transp],           // 8)
                       @[opaque, opaque, opaque, transp]            // 9)
                       ];
            break;
    }
    
    animation.values = values;
    animation.keyTimes = keyTimes;
    animation.timingFunctions = @[timingFunction, timingFunction, timingFunction, timingFunction];
    
    return animation;
}

CGPoint STLOffsetCGPoint(CGPoint point, CGFloat offset) {
    return CGPointMake(point.x + offset, point.y);
}

- (CAKeyframeAnimation *)keyFrameAnimationForProperty:(NSString *)property
                                               values:(NSArray *)values
                                             interval:(NSTimeInterval)interval
                                                delay:(NSTimeInterval)delayAmount
{
    // Create new animation
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:property];
    
    // Get timing function
    CAMediaTimingFunction *timingFunction = [self timingFunctionForAnimationOptions:UIViewAnimationOptionCurveLinear];
    
    // Calculate times based on marqueeType
    NSTimeInterval totalDuration;
    switch (self.type) {
        case STL_LeftToRight:
        case STL_RightToLeft:
            NSAssert(values.count == 5, @"Incorrect number of values passed for STLLeftRight-type animation");
            totalDuration = 2.0 * (delayAmount + interval);
            // Set up keyTimes
            animation.keyTimes = @[@(0.0),                                                   // Initial location, home
                                   @(delayAmount/totalDuration),                             // Initial delay, at home
                                   @((delayAmount + interval)/totalDuration),                // Animation to away
                                   @((delayAmount + interval + delayAmount)/totalDuration),  // Delay at away
                                   @(1.0)];                                                  // Animation to home
            
            animation.timingFunctions = @[timingFunction,
                                          timingFunction,
                                          timingFunction,
                                          timingFunction];
            
            break;
            
        default:
            NSAssert(values.count == 3, @"Incorrect number of values passed for STLContinous-type animation");
            totalDuration = delayAmount + interval;
            // Set up keyTimes
            animation.keyTimes = @[@(0.0),                              // Initial location, home
                                   @(delayAmount/totalDuration),        // Initial delay, at home
                                   @(1.0)];                             // Animation to away
            
            animation.timingFunctions = @[timingFunction,
                                          timingFunction];
            
            break;
    }
    
    // Set values
    animation.values = values;
    animation.delegate = self;
    
    return animation;
}

/**
 *  滚动显示文字
 *
 *  @param interval    滚动间隔
 *  @param delayAmount 停顿时间
 */
- (void)scrollContinuousWithInterval:(NSTimeInterval)interval after:(NSTimeInterval)delayAmount {

    if (![self labelReadyForScroll]) {
        return;
    }
    
    //取消现有的所有动画状态
    [self returnLabelToOriginImmediately];
    
    //动画开始
    [CATransaction begin];
    
    // Set Duration
    [CATransaction setAnimationDuration:(delayAmount + interval)];
    
    // 为边缘渐变创建动画
    if (self.fadeLength != 0.0f) {
        CAKeyframeAnimation *gradAnim = [self keyFrameAnimationForGradientFadeLength:self.fadeLength
                                                                            interval:interval
                                                                               delay:delayAmount];
        [self.layer.mask addAnimation:gradAnim forKey:@"gradient"];
    }
    
    // Create animation for sublabel positions
    CGPoint homeOrigin = self.homeLabelFrame.origin;
    CGPoint awayOrigin = STLOffsetCGPoint(self.homeLabelFrame.origin, self.awayOffset);
    NSArray *values = @[[NSValue valueWithCGPoint:homeOrigin],      // Initial location, home
                        [NSValue valueWithCGPoint:homeOrigin],      // Initial delay, at home
                        [NSValue valueWithCGPoint:awayOrigin]];     // Animation to home
    
    CAKeyframeAnimation *awayAnim = [self keyFrameAnimationForProperty:@"position"
                                                                values:values
                                                              interval:interval
                                                                 delay:delayAmount];
    
    // Add animation
    [self.subLabel.layer addAnimation:awayAnim forKey:@"position"];
    
    [CATransaction commit];
}

/**
 *  继续滚动显示
 *
 *  @param contune 继续标志
 */
- (void)againToScroll:(BOOL)contune{
    if (!contune) {
        return;
    }
    if (self.window && ![self.subLabel.layer animationForKey:@"position"]) {
        switch (self.type) {
            case STL_Forward:
            case STL_Backward:
                [self scrollContinuousWithInterval:self.animationDuration after:self.animationDelay];
                break;
            default:
                [self scrollAwayWithInterval:self.animationDuration];
                break;
        }
    }
    
}


- (void)scrollAwayWithInterval:(NSTimeInterval)interval{
    [self scrollAwayWithInterval:interval delayAmount:self.animationDelay];
}

- (void)scrollAwayWithInterval:(NSTimeInterval)interval delayAmount:(NSTimeInterval)delayAmount {
    // Check for conditions which would prevent scrolling
    if (![self labelReadyForScroll]) {
        return;
    }
    
    // Return labels to home (cancel any animations)
    [self returnLabelToOriginImmediately];
    
    
    // Animate
    [CATransaction begin];
    
    // Set Duration
    [CATransaction setAnimationDuration:(2.0 * (delayAmount + interval))];
    
    // Create animation for gradient, if needed
    if (self.fadeLength != 0.0f) {
        CAKeyframeAnimation *gradAnim = [self keyFrameAnimationForGradientFadeLength:self.fadeLength
                                                                            interval:interval
                                                                               delay:delayAmount];
        [self.layer.mask addAnimation:gradAnim forKey:@"gradient"];
    }
    
    // Create animation for position
    CGPoint homeOrigin = self.homeLabelFrame.origin;
    CGPoint awayOrigin = STLOffsetCGPoint(self.homeLabelFrame.origin, self.awayOffset);
    NSArray *values = @[[NSValue valueWithCGPoint:homeOrigin],      // Initial location, home
                        [NSValue valueWithCGPoint:homeOrigin],      // Initial delay, at home
                        [NSValue valueWithCGPoint:awayOrigin],      // Animation to away
                        [NSValue valueWithCGPoint:awayOrigin],      // Delay at away
                        [NSValue valueWithCGPoint:homeOrigin]];     // Animation to home
    
    CAKeyframeAnimation *awayAnim = [self keyFrameAnimationForProperty:@"position"
                                                                values:values
                                                              interval:interval
                                                                 delay:delayAmount];
    
    // Add animation
    [self.subLabel.layer addAnimation:awayAnim forKey:@"position"];
    
    [CATransaction commit];
}


- (void)beginScrollWithDelay:(BOOL)delay {
    switch (self.type) {
        case STL_Forward:
        case STL_Backward:
            [self scrollContinuousWithInterval:self.animationDuration after:(delay ? self.animationDelay : 0.0)];
            break;
        default:
            [self scrollAwayWithInterval:self.animationDuration];
            break;
    }
}

- (void)startScroll{
    
    if (self.labelShouldScroll) {
        [self beginScrollWithDelay:YES];
    }

    
}

- (void)stopScroll{
    [self returnLabelToOriginImmediately];
}

- (void)dealloc{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_subLabel release];
    [super dealloc];
}

#pragma mark - 定制Setter方法
- (void)setRate:(CGFloat)rate{
    if (_rate == rate) {
        return;
    }
    _rate = rate;
    [self updateSublabelAndLocations];
}

- (void)setTailBlankLength:(CGFloat)tailBlankLength{
    if (_tailBlankLength == tailBlankLength) {
        return;
    }
    _tailBlankLength = tailBlankLength;
    [self updateSublabelAndLocations];
}

- (void)setFadeLength:(CGFloat)fadeLength{
    if (_fadeLength == fadeLength) {
        return;
    }
    
    _fadeLength = fadeLength;
    
    [self updateSublabelAndLocations];
}

- (void)setType:(ScrollTextLabelType)type{
    if (_type == type) {
        return;
    }
    
    _type = type;
    [self updateSublabelAndLocations];
}

@end

#pragma mark - UIView 扩展类别

/**
 *  用于获取包含本控件的ViewController
 */
@implementation UIView (ScrollTextLabelHelper)

- (id)firstResponseViewController
{
   return [self traverseResponderChainForFirstViewController];
}

- (id)traverseResponderChainForFirstViewController
{
    id nextResponder = [self nextResponder];
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        return nextResponder;
    } else if ([nextResponder isKindOfClass:[UIView class]]) {
        return [nextResponder traverseResponderChainForFirstViewController];
    } else {
        return nil;
    }
}
@end

#pragma mark - CAMediaTimingFunction 扩展类别
@implementation CAMediaTimingFunction (ScrollTextLabelHelper)

- (CGFloat)durationPercentageForPositionPercentage:(CGFloat)positionPercentage withDuration:(NSTimeInterval)duration
{
    // Finds the animation duration percentage that corresponds with the given animation "position" percentage.
    // Utilizes Newton's Method to solve for the parametric Bezier curve that is used by CAMediaAnimation.
    
    NSArray *controlPoints = [self controlPoints];
    CGFloat epsilon = 1.0f / (100.0f * duration);
    
    // Find the t value that gives the position percentage we want
    CGFloat t_found = [self solveTForY:positionPercentage
                           withEpsilon:epsilon
                         controlPoints:controlPoints];
    
    // With that t, find the corresponding animation percentage
    CGFloat durationPercentage = [self XforCurveAt:t_found withControlPoints:controlPoints];
    
    return durationPercentage;
}
- (CGFloat)solveTForY:(CGFloat)y_0 withEpsilon:(CGFloat)epsilon controlPoints:(NSArray *)controlPoints
{
    // Use Newton's Method: http://en.wikipedia.org/wiki/Newton's_method
    // For first guess, use t = y (i.e. if curve were linear)
    CGFloat t0 = y_0;
    CGFloat t1 = y_0;
    CGFloat f0, df0;
    
    for (int i = 0; i < 15; i++) {
        // Base this iteration of t1 calculated from last iteration
        t0 = t1;
        // Calculate f(t0)
        f0 = [self YforCurveAt:t0 withControlPoints:controlPoints] - y_0;
        // Check if this is close (enough)
        if (fabs(f0) < epsilon) {
            // Done!
            return t0;
        }
        // Else continue Newton's Method
        df0 = [self derivativeYValueForCurveAt:t0 withControlPoints:controlPoints];
        // Check if derivative is small or zero ( http://en.wikipedia.org/wiki/Newton's_method#Failure_analysis )
        if (fabs(df0) < 1e-6) {
            break;
        }
        // Else recalculate t1
        t1 = t0 - f0/df0;
    }
    
    NSLog(@"ScrollTextLabel: Failed to find t for Y input!");
    return t0;
}

- (CGFloat)YforCurveAt:(CGFloat)t withControlPoints:(NSArray *)controlPoints
{
    CGPoint P0 = [controlPoints[0] CGPointValue];
    CGPoint P1 = [controlPoints[1] CGPointValue];
    CGPoint P2 = [controlPoints[2] CGPointValue];
    CGPoint P3 = [controlPoints[3] CGPointValue];
    
    // Per http://en.wikipedia.org/wiki/Bezier_curve#Cubic_B.C3.A9zier_curves
    return  powf((1 - t),3) * P0.y +
    3.0f * powf(1 - t, 2) * t * P1.y +
    3.0f * (1 - t) * powf(t, 2) * P2.y +
    powf(t, 3) * P3.y;
    
}

- (CGFloat)XforCurveAt:(CGFloat)t withControlPoints:(NSArray *)controlPoints
{
    CGPoint P0 = [controlPoints[0] CGPointValue];
    CGPoint P1 = [controlPoints[1] CGPointValue];
    CGPoint P2 = [controlPoints[2] CGPointValue];
    CGPoint P3 = [controlPoints[3] CGPointValue];
    
    // Per http://en.wikipedia.org/wiki/Bezier_curve#Cubic_B.C3.A9zier_curves
    return  powf((1 - t),3) * P0.x +
    3.0f * powf(1 - t, 2) * t * P1.x +
    3.0f * (1 - t) * powf(t, 2) * P2.x +
    powf(t, 3) * P3.x;
    
}

- (CGFloat)derivativeYValueForCurveAt:(CGFloat)t withControlPoints:(NSArray *)controlPoints
{
    CGPoint P0 = [controlPoints[0] CGPointValue];
    CGPoint P1 = [controlPoints[1] CGPointValue];
    CGPoint P2 = [controlPoints[2] CGPointValue];
    CGPoint P3 = [controlPoints[3] CGPointValue];
    
    return  powf(t, 2) * (-3.0f * P0.y - 9.0f * P1.y - 9.0f * P2.y + 3.0f * P3.y) +
    t * (6.0f * P0.y + 6.0f * P2.y) +
    (-3.0f * P0.y + 3.0f * P1.y);
}

- (NSArray *)controlPoints
{
    float point[2];
    NSMutableArray *pointArray = [NSMutableArray array];
    for (int i = 0; i <= 3; i++) {
        [self getControlPointAtIndex:i values:point];
        [pointArray addObject:[NSValue valueWithCGPoint:CGPointMake(point[0], point[1])]];
    }
    
    return [NSArray arrayWithArray:pointArray];
}

@end
