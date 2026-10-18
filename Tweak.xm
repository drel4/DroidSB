// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DSBStatusBarView.h"
#import "DSBTransientBar.h"

@interface _UIStatusBar : UIView
@end
@interface SBGrabberTongue : NSObject
@end

static char ViewKey;
static char UpdatingKey;
static void Update(UIView *bar) {
    DSBObserveNativeBar(bar);
    if ([objc_getAssociatedObject(bar, &UpdatingKey) boolValue]) return;
    objc_setAssociatedObject(bar, &UpdatingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        DSBStatusBarView *view = objc_getAssociatedObject(bar, &ViewKey);
        if (!view) {
            view = [[DSBStatusBarView alloc] initWithFrame:bar.bounds];
            view.nativeBar = bar;
            objc_setAssociatedObject(bar, &ViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        // UIKit may remove/rebuild subviews without destroying the associated
        // replacement. Reattach it instead of refreshing a permanently orphaned view.
        if (view.superview != bar) [bar addSubview:view];
        [view refresh];
    } @finally {
        objc_setAssociatedObject(bar, &UpdatingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%hook _UIStatusBar
- (void)layoutSubviews {
    %orig;
    Update(self);
}
- (void)_updateWithAggregatedData:(id)data {
    %orig;
    Update(self);
}
- (void)setForegroundColor:(UIColor *)color {
    %orig;
    Update(self);
}
- (void)didMoveToWindow {
    %orig;
    if (self.window) Update(self);
    else [(DSBStatusBarView *)objc_getAssociatedObject(self, &ViewKey) restoreNative];
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    DSBStatusBarView *view = objc_getAssociatedObject(self, &ViewKey);
    if (view && recognizer == DSBRead(self, @"actionGestureRecognizer")
        && [view recordingChipContainsPoint:[recognizer locationInView:view]]) return NO;
    return %orig;
}
%end

%group Fullscreen
%hook SBGrabberTongue
- (BOOL)isEdgeLocationInGrabberRegion:(double)location {
    if (DSBUsesWideTransientGrabber(self)) return YES;
    return %orig;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    DSBCaptureTransientTouch(self, gesture, touch);
    return %orig;
}
- (void)_handlePullGesture:(UIPanGestureRecognizer *)gesture {
    DSBCaptureTransientOrientation(self, gesture);
    %orig;
    DSBUpdateTransientBarInteraction(self, gesture);
}
- (void)_presentTongueAnimated:(BOOL)animated autoDismiss:(BOOL)autoDismiss {
    %orig;
    DSBPresentTransientBar(self, animated, autoDismiss);
}
- (void)_dismissTongueWithStyle:(NSInteger)style animated:(BOOL)animated {
    DSBDismissTransientBar(self, animated);
    %orig;
}
- (void)_willDismiss {
    DSBDismissTransientBar(self, YES);
    %orig;
}
- (void)_didDismiss {
    DSBDismissTransientBar(self, NO);
    %orig;
}
- (void)uninstall {
    DSBDismissTransientBar(self, NO);
    %orig;
}
- (void)invalidate {
    DSBDismissTransientBar(self, NO);
    %orig;
}
%end
%end

%ctor {
    @autoreleasepool {
        // UIKit bundle filtering covers SpringBoard and app-owned status bars;
        // The ordinary row stays native-hosted. Fullscreen grabbers are hooked
        // separately only where SpringBoard provides their owning class.
        if (@available(iOS 15.0, *)) {
            if (NSClassFromString(@"_UIStatusBar")) { %init; }
            if (NSClassFromString(@"SBGrabberTongue")) { %init(Fullscreen); }
        }
    }
}
