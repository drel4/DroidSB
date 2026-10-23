// SPDX-License-Identifier: Apache-2.0
#import "DSBPrivacyView.h"
#import "DSBPrivacyMotion.h"
#import "DSBFrameAnimator.h"
#import "DSBStatusBarView.h"
#import "DSBAssets.h"
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>

NSString *const DSBPrivacyChangedNotification = @"DSBPrivacyChanged";
static NSUInteger managerMask;
static NSUInteger MaskForColor(id color) {
    if (![color isKindOfClass:UIColor.class]) return 0;
    CGFloat r=0,g=0,b=0,a=0;
    if (![color getRed:&r green:&g blue:&b alpha:&a] || a < .5) return 0;
    if (g > .45 && g > r*1.15 && g > b*1.15) return DSBPrivacyCamera;
    if (r > .65 && g > .2 && g < r*.85 && b < .4) return DSBPrivacyMicrophone;
    return 0;
}
void DSBPrivacyManagerUpdated(id manager, id attributions) {
    if (!attributions) attributions = [NSSet set];
    if (![attributions respondsToSelector:@selector(allObjects)]) return;
    NSUInteger mask = 0;
    for (id attribution in [attributions allObjects]) {
        NSInteger sensor = [DSBRead(attribution,@"sensor") integerValue];
        SEL identifier = NSSelectorFromString(@"_indicatorIdentifierForSensorType:");
        SEL color = NSSelectorFromString(@"_indicatorColorForSensorType:");
        // Pass the real type back to Apple's semantic helpers, never map an
        // undocumented sensor enum to camera/microphone ourselves.
        @try {
            NSString *name = [manager respondsToSelector:identifier]
                ? [((id (*)(id,SEL,NSInteger))objc_msgSend)(manager,identifier,sensor) description].lowercaseString : nil;
            if ([name containsString:@"camera"]) mask |= DSBPrivacyCamera;
            else if ([name containsString:@"microphone"] || [name containsString:@"mic"]) mask |= DSBPrivacyMicrophone;
            else if ([manager respondsToSelector:color]) mask |= MaskForColor(((id (*)(id,SEL,NSInteger))objc_msgSend)(manager,color,sensor));
        } @catch (__unused NSException *e) { }
    }
    if (mask == managerMask) return;
    managerMask = mask;
    [NSNotificationCenter.defaultCenter postNotificationName:DSBPrivacyChangedNotification object:nil];
}
static NSUInteger MaskInNativeView(id object, int depth) {
    if (!object || depth > 4) return 0;
    NSUInteger mask = MaskForColor(DSBRead(object,@"indicatorColor"));
    if (![object isKindOfClass:UIView.class]) return mask;
    UIView *view = object;
    if (view.hidden || view.alpha <= .01) return mask;
    mask |= MaskForColor(view.backgroundColor);
    for (UIView *child in view.subviews) mask |= MaskInNativeView(child,depth+1);
    return mask;
}
NSUInteger DSBPrivacyMaskForBar(UIView *bar, id data) {
    if (managerMask) return managerMask; // SpringBoard, including both sensors
    if (![DSBRead(DSBRead(data,@"sensorActivityEntry"),@"enabled") boolValue]) return 0;
    UIScreen *screen = bar.window.screen;
    Class cls = NSClassFromString(@"_UIStatusBar");
    SEL get = NSSelectorFromString(@"sensorActivityIndicatorForScreen:");
    NSUInteger mask = 0;
    if (screen && [cls respondsToSelector:get]) {
        @try { mask = MaskInNativeView(((id (*)(id,SEL,id))objc_msgSend)(cls,get,screen),0); }
        @catch (__unused NSException *e) { }
    }
    // An opaque native portal may not expose the sensor kind in app processes.
    // Preserve an active generic privacy dot rather than inventing an icon.
    return mask ?: DSBPrivacyUnknown;
}

@implementation DSBPrivacyView {
    UIView *_bubble;
    UIImageView *_camera, *_mic;
    DSBFrameAnimator *_animator;
    NSUInteger _mask;
    double _time;
    BOOL _collapsingOff;
    double _offAlpha;
    CFTimeInterval _holdUntil;
    NSUInteger _holdGeneration;
    BOOL _pendingOff;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.isAccessibilityElement = YES;
        self.hidden = YES;
        _bubble = [UIView new]; _bubble.clipsToBounds = YES;
        _bubble.backgroundColor = [UIColor colorWithRed:61/255.0 green:220/255.0 blue:132/255.0 alpha:1];
        [self addSubview:_bubble];
        _camera = [[UIImageView alloc] initWithImage:DSBIcon(@"ic_privacy_camera",16)];
        _mic = [[UIImageView alloc] initWithImage:DSBIcon(@"ic_privacy_mic",16)];
        _camera.tintColor = _mic.tintColor = UIColor.blackColor;
        _camera.contentMode = _mic.contentMode = UIViewContentModeScaleAspectFit;
        [_bubble addSubview:_camera]; [_bubble addSubview:_mic];
    }
    return self;
}
- (void)reset {
    [_animator stopAnimation:YES]; _animator = nil;
    _mask = 0; _time = 0; _collapsingOff = NO;
    ++_holdGeneration;
    _pendingOff = NO;
    self.hidden = YES;
}
- (void)setActivityMask:(NSUInteger)mask {
    if (_mask == mask && !_collapsingOff) {
        if (mask) {
            if (_pendingOff) _holdUntil = CACurrentMediaTime()+5;
            _pendingOff = NO; ++_holdGeneration;
        }
        return;
    }
    if (!mask && !_mask) return;
    // PrivacyItemController holds camera/mic indications for at least 5 s.
    if (!mask && _mask && CACurrentMediaTime() < _holdUntil) {
        if (_pendingOff) return;
        _pendingOff = YES;
        NSUInteger generation = ++_holdGeneration;
        __weak DSBPrivacyView *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((_holdUntil-CACurrentMediaTime())*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            DSBPrivacyView *view = weakSelf;
            if (view && view->_holdGeneration == generation) { view->_pendingOff = NO; [view setActivityMask:0]; }
        });
        return;
    }
    ++_holdGeneration;
    _pendingOff = NO;
    [_animator stopAnimation:YES]; _animator = nil;
    BOOL had = _mask != 0;
    _mask = mask;
    if (!mask) {
        _collapsingOff = YES; _offAlpha = _bubble.alpha;
        if (!had || !self.window || UIAccessibilityIsReduceMotionEnabled()) { [self reset]; if(self.frameChanged) self.frameChanged(); return; }
        __weak DSBPrivacyView *weakSelf = self;
        // PrivacyDotViewController fades the persistent dot; no pulsing.
        _animator = [[DSBFrameAnimator alloc] initWithDuration:.16 update:^(double f) {
            DSBPrivacyView *view = weakSelf;
            if (!view) return;
            view->_bubble.alpha = view->_offAlpha*(1-DSBBezier(f,0,0,.8,1));
        } completion:^(__unused UIViewAnimatingPosition p) {
            DSBPrivacyView *view = weakSelf;
            [view reset]; if(view.frameChanged) view.frameChanged();
        }];
        [_animator startAnimation]; return;
    }
    _collapsingOff = NO; self.hidden = NO; _time = 0;
    _holdUntil = CACurrentMediaTime()+5;
    _camera.hidden = !(mask & DSBPrivacyCamera); _mic.hidden = !(mask & DSBPrivacyMicrophone);
    self.accessibilityLabel = mask == DSBPrivacyUnknown ? @"Sensor activity" :
        (mask & DSBPrivacyCamera) && (mask & DSBPrivacyMicrophone) ? @"Camera and microphone in use" :
        mask & DSBPrivacyCamera ? @"Camera in use" : @"Microphone in use";
    if (mask == DSBPrivacyUnknown || UIAccessibilityIsReduceMotionEnabled()) {
        _time = DSB_PRIVACY_TIMELINE_SECONDS;
        [self setNeedsLayout]; if(self.frameChanged) self.frameChanged(); return;
    }
    __weak DSBPrivacyView *weakSelf = self;
    _animator = [[DSBFrameAnimator alloc] initWithDuration:DSB_PRIVACY_TIMELINE_SECONDS update:^(double f) {
        DSBPrivacyView *view = weakSelf;
        if (!view) return;
        view->_time = f*DSB_PRIVACY_TIMELINE_SECONDS;
        [view setNeedsLayout]; [view layoutIfNeeded];
        if(view.frameChanged) view.frameChanged();
    } completion:nil];
    [_animator startAnimation];
}
- (DSBPrivacyFrame)sample {
    CGFloat height = MIN(24, MAX(0,self.bounds.size.height-2));
    return DSBPrivacyAt(_time,56*height/24,height);
}
- (double)chromeAlpha { return self.hidden || _collapsingOff ? 1 : [self sample].chromeAlpha; }
- (double)chromeShift { return self.hidden || _collapsingOff ? 0 : [self sample].chromeShift; }
- (CGFloat)reservedWidth { return !self.hidden ? 10 : 0; }
- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.hidden || _collapsingOff) return;
    DSBPrivacyFrame f = [self sample];
    CGFloat right = self.bounds.size.width - 6 + f.shift;
    _bubble.frame = CGRectMake(right-f.width,(self.bounds.size.height-f.height)/2,f.width,f.height);
    _bubble.alpha = f.alpha; _bubble.layer.cornerRadius = f.height/2;
    CGFloat side = MIN(16,MAX(0,self.bounds.size.height-6));
    NSInteger count = !_camera.hidden + !_mic.hidden;
    CGFloat total = count*side + MAX(0,count-1)*3;
    CGFloat full = 56*MIN(24,MAX(0,self.bounds.size.height-2))/24;
    // Keep content anchored at its original position while the background
    // contracts from the right. Re-centering would paint a black icon IN the dot.
    CGFloat x = (full-total)/2 - (full-f.width);
    for (UIImageView *icon in @[_camera,_mic]) {
        if (icon.hidden) continue;
        icon.frame = CGRectMake(x,(f.height-side)/2,side,side);
        icon.alpha = f.contentAlpha; x += side+3;
    }
}
- (void)didMoveToWindow { [super didMoveToWindow]; if(!self.window) [self reset]; }
- (void)dealloc { [_animator stopAnimation:YES]; }
@end
