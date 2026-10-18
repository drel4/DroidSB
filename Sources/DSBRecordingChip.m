// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4. Chip styling adapted from AOSP ScreenRecordChipViewModel,
// ColorsModel.Red and OngoingActivityChip. Copyright (C) 2024 The Android Open Source Project.
#import "DSBRecordingChip.h"
#import "DSBStatusBarView.h"
#import "DSBAssets.h"
#import "DSBFont.h"
#import "DSBRecordingState.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface DSBRecordingSession : NSObject
@property(nonatomic) DSBRecordingEvidence evidence;
@end
@implementation DSBRecordingSession
@end
static char RecordingSessionKey;

static id ActivityValue(id item, NSString *method, NSInteger type) {
    SEL selector = NSSelectorFromString(method);
    if (![item respondsToSelector:selector]) return nil;
    @try { return ((id (*)(id, SEL, NSInteger))objc_msgSend)(item, selector, type); }
    @catch (__unused NSException *e) { return nil; }
}

BOOL DSBIsScreenRecording(UIView *bar, id data) {
    if (!bar) return NO;
    // The fullscreen renderer has a lightweight host; retain evidence on its
    // real native source so it agrees with the ordinary status-bar renderer.
    UIView *source = DSBRead(bar, @"sourceBar");
    if (![source isKindOfClass:UIView.class]) source = bar;
    DSBRecordingSession *session = objc_getAssociatedObject(source, &RecordingSessionKey);
    if (!session) {
        session = [DSBRecordingSession new];
        objc_setAssociatedObject(source, &RecordingSessionKey, session, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    id entry = DSBRead(data, @"backgroundActivityEntry");
    BOOL enabled = [DSBRead(entry, @"enabled") boolValue];
    UIScreen *screen = bar.window.screen ?: UIScreen.mainScreen;
    // Capture alone also includes AirPlay/mirroring. Never infer recording
    // from capture without native symbol/red evidence, or guess type enums.
    id items = DSBRead(bar, @"items");
    NSInteger type = [DSBRead(entry, @"type") integerValue];
    BOOL recordingSymbol = NO, redActivity = NO;
    for (id item in [items isKindOfClass:NSDictionary.class] ? [items allValues] : @[]) {
        if (![DSBRead(item, @"indicatorEntryKey") isEqual:@"backgroundActivityEntry"]) continue;
        for (NSString *method in @[@"_systemImageNameForActivityType:", @"_imageNameForActivityType:"]) {
            id name = ActivityValue(item, method, type);
            if ([name isKindOfClass:NSString.class] && [[name lowercaseString] containsString:@"record"]) recordingSymbol = YES;
        }
        id color = ActivityValue(item, @"_backgroundColorForActivityType:", type);
        CGFloat r = 0, g = 0, b = 0, a = 0;
        if ([color isKindOfClass:UIColor.class] && [color getRed:&r green:&g blue:&b alpha:&a]
            && r > .55 && g < .45 && b < .45 && a > .5) redActivity = YES;
    }
    DSBRecordingEvidence evidence = session.evidence;
    BOOL recording = DSBUpdateRecordingEvidence(&evidence, enabled, recordingSymbol, redActivity, screen.isCaptured, type);
    session.evidence = evidence;
    return recording;
}

BOOL DSBPerformRecordingAction(UIView *bar) {
    id data = DSBRead(bar, @"currentAggregatedData") ?: DSBRead(bar, @"currentData");
    if (!DSBIsScreenRecording(bar, data)) return NO;
    id items = DSBRead(bar, @"items");
    if (![items isKindOfClass:NSDictionary.class]) return NO;
    for (id item in [items allValues]) {
        if (![DSBRead(item, @"indicatorEntryKey") isEqual:@"backgroundActivityEntry"]) continue;
        id displays = DSBRead(item, @"displayItems");
        if (![displays isKindOfClass:NSDictionary.class]) continue;
        for (id display in [displays allValues]) {
            id action = DSBRead(display, @"action");
            SEL perform = NSSelectorFromString(@"performWithStatusBar:completionHandler:");
            if (![DSBRead(action, @"enabled") boolValue] || ![action respondsToSelector:perform]) continue;
            // Reuse only this recording item's native action. UIKit owns the
            // confirmation and saving lifecycle; do not stop arbitrary ReplayKit
            // clients, synthesize taps, or call the unrelated global bar action.
            @try {
                void (^completion)(void) = ^{};
                ((void (*)(id, SEL, id, id))objc_msgSend)(action, perform, bar, completion);
                return YES;
            } @catch (__unused NSException *e) { return NO; }
        }
    }
    return NO;
}

@implementation DSBRecordingChip {
    UIImageView *_icon;
    UILabel *_timer;
    BOOL _recordingVisible;
    UIViewPropertyAnimator *_visibilityAnimator;
    NSUInteger _visibilityVersion;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = YES;
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
        self.accessibilityHint = @"Open screen recording controls";
        self.clipsToBounds = YES;
        self.hidden = YES;
        self.alpha = 0;
        // ColorsModel.Red -> GM2_red_700, white text; no continuous pulse in
        // the pinned Android chip. 24sp source height is fitted to the SE bar.
        self.backgroundColor = [UIColor colorWithRed:197/255.0 green:34/255.0 blue:31/255.0 alpha:1];
        _icon = [[UIImageView alloc] initWithImage:DSBIcon(@"ic_screenrecord", 16)];
        _icon.tintColor = UIColor.whiteColor;
        _icon.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_icon];
        _timer = [UILabel new];
        _timer.font = DSBSansFont(11, 500);
        _timer.textColor = UIColor.whiteColor;
        [self addSubview:_timer];
    }
    return self;
}
- (BOOL)recordingVisible { return _recordingVisible; }
- (void)setRecordingVisible:(BOOL)visible animated:(BOOL)animated {
    if (_recordingVisible == visible && animated) return;
    NSUInteger version = ++_visibilityVersion;
    if (_visibilityAnimator.state == UIViewAnimatingStateActive) {
        [_visibilityAnimator stopAnimation:NO];
        [_visibilityAnimator finishAnimationAtPosition:UIViewAnimatingPositionCurrent];
    }
    _visibilityAnimator = nil;
    _recordingVisible = visible;
    self.userInteractionEnabled = visible;
    animated = animated && self.window && !UIAccessibilityIsReduceMotionEnabled();
    if (!animated) {
        self.alpha = visible ? 1 : 0;
        self.hidden = !visible;
        [self.superview setNeedsLayout];
        return;
    }
    if (self.hidden) self.alpha = 0;
    self.hidden = NO;
    [self.superview setNeedsLayout];
    __weak DSBRecordingChip *weakSelf = self;
    // OngoingActivityChips uses fadeIn/fadeOut. UIKit duration is an adaptation;
    // no continuous pulse, scale loop or popup morph is imposed on native UI.
    _visibilityAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:.3 curve:UIViewAnimationCurveEaseInOut animations:^{
        weakSelf.alpha = visible ? 1 : 0;
    }];
    [_visibilityAnimator addCompletion:^(__unused UIViewAnimatingPosition position) {
        DSBRecordingChip *chip = weakSelf;
        if (!chip || chip->_visibilityVersion != version) return;
        chip.hidden = !visible;
        chip->_visibilityAnimator = nil;
        [chip.superview setNeedsLayout];
    }];
    [_visibilityAnimator startAnimation];
}
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    UIColor *color = highlighted
        ? [UIColor colorWithRed:208/255.0 green:62/255.0 blue:59/255.0 alpha:1]
        : [UIColor colorWithRed:197/255.0 green:34/255.0 blue:31/255.0 alpha:1];
    [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled() ? 0 : .12 delay:0
        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
        animations:^{ self.backgroundColor = color; } completion:nil];
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) [self setRecordingVisible:NO animated:NO];
}
- (void)dealloc {
    if (_visibilityAnimator.state == UIViewAnimatingStateActive) [_visibilityAnimator stopAnimation:YES];
}
- (void)updateFromEntry:(id)entry {
    _icon.image = DSBIcon(@"ic_screenrecord", 16);
    // Preserve the native start time across view recreation/resprings. Accept
    // either NSDate's reference epoch or Unix only when plausibly in the last
    // 24h. With no usable native timestamp, show REC rather than a fake timer.
    double raw = [DSBRead(entry, @"displayStartDate") doubleValue];
    double now = NSDate.date.timeIntervalSinceReferenceDate;
    double elapsed = now - raw;
    if (elapsed < 0 || elapsed > 86400) elapsed = NSDate.date.timeIntervalSince1970 - raw;
    if (raw > 0 && elapsed >= 0 && elapsed <= 86400) {
        NSInteger seconds = (NSInteger)elapsed;
        _timer.text = seconds >= 3600
            ? [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)(seconds/3600), (long)(seconds/60%60), (long)(seconds%60)]
            : [NSString stringWithFormat:@"%ld:%02ld", (long)(seconds/60), (long)(seconds%60)];
    } else _timer.text = @"REC";
    self.accessibilityLabel = [@"Screen recording, " stringByAppendingString:_timer.text];
    [self setNeedsLayout];
}
- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat h = MAX(0, MIN(24, size.height));
    return CGSizeMake([self minimumWidthForHeight:h] + 4 + ceil([_timer sizeThatFits:CGSizeMake(100, h)].width), h);
}
- (CGFloat)minimumWidthForHeight:(CGFloat)height {
    return 12 + MIN(16, MAX(0, height - 4));
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.bounds.size.height;
    self.layer.cornerRadius = h / 2;
    CGFloat side = MIN(16, MAX(0, h - 4));
    BOOL textFits = self.bounds.size.width >= 6 + side + 4 + [_timer sizeThatFits:CGSizeMake(100, h)].width + 6;
    _timer.hidden = !textFits;
    _icon.frame = CGRectMake(textFits ? 6 : (self.bounds.size.width - side)/2, (h-side)/2, side, side);
    _timer.frame = CGRectMake(6 + side + 4, 0, MAX(0, self.bounds.size.width - 6 - side - 4 - 6), h);
}
@end
