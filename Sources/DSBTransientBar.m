// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4
#import "DSBTransientBar.h"
#import "DSBStatusBarView.h"
#import <objc/runtime.h>

// The native grabber retains recognition, second-swipe routing and auto-dismiss.
// Only its presentation is replaced; no global gesture recognizer/window is added.
static char TransientKey;
static id latestData;
static __weak UIView *latestBar;
static NSHashTable *presentations;

@interface DSBTransientHost : UIView
@property(nonatomic, strong) id currentAggregatedData;
@property(nonatomic, strong) UIView *foregroundView;
@property(nonatomic, strong) UIColor *foregroundColor;
@property(nonatomic, weak) UIView *sourceBar;
@property(nonatomic, strong) DSBStatusBarView *renderer;
@end
@implementation DSBTransientHost
- (id)items { return DSBRead(self.sourceBar, @"items"); }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return [self.renderer hitTest:[self convertPoint:point toView:self.renderer] withEvent:event];
}
@end

@interface DSBTransientPresentation : NSObject
@property(nonatomic, weak) UIView *arrow;
@property(nonatomic) BOOL arrowWasHidden;
@property(nonatomic, strong) DSBTransientHost *host;
@property(nonatomic, strong) UIViewPropertyAnimator *animator;
@property(nonatomic, strong) NSTimer *timer;
- (void)refresh;
- (void)dismiss:(BOOL)animated;
@end

@implementation DSBTransientPresentation
- (void)refresh {
    if (!DSBEnabled()) { [self dismiss:NO]; return; }
    self.host.currentAggregatedData = latestData;
    self.host.sourceBar = latestBar;
    self.host.renderer.actionBar = latestBar;
    [self.host.renderer refresh];
    [self.host.renderer layoutIfNeeded];
}
- (void)dismiss:(BOOL)animated {
    [self.timer invalidate]; self.timer = nil;
    if (!self.host) {
        if (!animated && self.animator.state == UIViewAnimatingStateActive) {
            [self.animator stopAnimation:NO];
            [self.animator finishAnimationAtPosition:UIViewAnimatingPositionEnd];
        }
        return;
    }
    [self.animator stopAnimation:YES];
    DSBTransientHost *host = self.host;
    UIView *arrow = self.arrow;
    BOOL hidden = self.arrowWasHidden;
    self.host = nil;
    // InsetsController's transient MOVE_OUT duration and material easing.
    UICubicTimingParameters *timing = [[UICubicTimingParameters alloc]
        initWithControlPoint1:CGPointMake(.4, 0) controlPoint2:CGPointMake(.2, 1)];
    self.animator = [[UIViewPropertyAnimator alloc] initWithDuration:
        animated && !UIAccessibilityIsReduceMotionEnabled() ? .340 : 0 timingParameters:timing];
    [self.animator addAnimations:^{ host.renderer.transform = CGAffineTransformMakeTranslation(0, -host.bounds.size.height); host.backgroundColor = UIColor.clearColor; }];
    [self.animator addCompletion:^(__unused UIViewAnimatingPosition position) {
        [host removeFromSuperview];
        arrow.hidden = hidden;
    }];
    [self.animator startAnimation];
}
- (void)dealloc { [self.timer invalidate]; }
@end

void DSBObserveNativeBar(UIView *bar) {
    // This runs in the owning process. SpringBoard supplies the fullscreen row;
    // app-process bars stay local and do not require cross-process messaging.
    id data = DSBRead(bar, @"currentAggregatedData") ?: DSBRead(bar, @"currentData");
    if (!data) return;
    latestBar = bar;
    latestData = data;
    for (DSBTransientPresentation *presentation in presentations) [presentation refresh];
}

void DSBDismissTransientBar(id tongue, BOOL animated) {
    DSBTransientPresentation *presentation = objc_getAssociatedObject(tongue, &TransientKey);
    [presentation dismiss:animated];
    // Keep the controller alive through dismissal; a subsequent presentation
    // completes its old cleanup before attaching a new row.
}

void DSBPresentTransientBar(id tongue, BOOL animated) {
    if (!DSBEnabled() || !latestData) return;
    id delegate = DSBRead(tongue, @"delegate");
    Class coverSheet = NSClassFromString(@"SBCoverSheetPrimarySlidingViewController");
    // Do not replace the bottom Control Center/home-indicator grabber.
    BOOL top = coverSheet && [delegate isKindOfClass:coverSheet];
    NSNumber *edge = DSBRead(tongue, @"screenEdge") ?: DSBRead(tongue, @"edge");
    top = top || (edge && edge.unsignedIntegerValue == UIRectEdgeTop);
    UIView *container = DSBRead(tongue, @"containingView");
    UIView *arrow = DSBRead(tongue, @"tongueContainer");
    if (!top || ![container isKindOfClass:UIView.class] || !container.window
        || ![arrow isKindOfClass:UIView.class]) return;

    DSBTransientPresentation *old = objc_getAssociatedObject(tongue, &TransientKey);
    if (old.host) { [old refresh]; return; }
    // Finish a pending dismissal before reusing the native arrow's hidden state.
    if (old.animator.state == UIViewAnimatingStateActive) [old.animator stopAnimation:NO];
    if (old.animator.state == UIViewAnimatingStateStopped) [old.animator finishAnimationAtPosition:UIViewAnimatingPositionEnd];

    DSBTransientPresentation *presentation = [DSBTransientPresentation new];
    presentation.arrow = arrow;
    presentation.arrowWasHidden = arrow.hidden;
    DSBTransientHost *host = [DSBTransientHost new];
    host.clipsToBounds = YES;
    host.foregroundView = [UIView new]; // renderer suppresses only this placeholder
    host.foregroundColor = UIColor.whiteColor;
    presentation.host = host;
    [container addSubview:host];
    // Convert a scene-oriented top row into SpringBoard's host coordinates.
    // This also covers portrait-aligned hosts while the foreground app rotates.
    id<UICoordinateSpace> space = container.window.windowScene.coordinateSpace ?: container.window;
    CGRect screen = space.bounds;
    CGFloat height = MAX(20, container.window.safeAreaInsets.top);
    height = MIN(54, height);
    CGPoint p0 = [container convertPoint:screen.origin fromCoordinateSpace:space];
    CGPoint px = [container convertPoint:CGPointMake(screen.origin.x + 1, screen.origin.y) fromCoordinateSpace:space];
    CGPoint py = [container convertPoint:CGPointMake(screen.origin.x, screen.origin.y + 1) fromCoordinateSpace:space];
    host.bounds = CGRectMake(0, 0, screen.size.width, height);
    host.center = [container convertPoint:CGPointMake(CGRectGetMidX(screen), CGRectGetMinY(screen) + height/2) fromCoordinateSpace:space];
    host.transform = CGAffineTransformMake(px.x-p0.x, px.y-p0.y, py.x-p0.x, py.y-p0.y, 0, 0);
    host.renderer = [[DSBStatusBarView alloc] initWithFrame:host.bounds];
    host.renderer.nativeBar = host;
    host.renderer.transientPresentation = YES;
    [host addSubview:host.renderer];
    [presentation refresh];
    if (host.renderer.hidden) { [host removeFromSuperview]; return; }
    arrow.hidden = YES;
    objc_setAssociatedObject(tongue, &TransientKey, presentation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!presentations) presentations = [NSHashTable weakObjectsHashTable];
    [presentations addObject:presentation];
    __weak DSBTransientPresentation *weakPresentation = presentation;
    presentation.timer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(__unused NSTimer *timer) { [weakPresentation refresh]; }];
    [NSRunLoop.mainRunLoop addTimer:presentation.timer forMode:NSRunLoopCommonModes];

    host.renderer.transform = CGAffineTransformMakeTranslation(0, -height);
    UICubicTimingParameters *timing = [[UICubicTimingParameters alloc]
        initWithControlPoint1:CGPointMake(.4, 0) controlPoint2:CGPointMake(.2, 1)];
    presentation.animator = [[UIViewPropertyAnimator alloc] initWithDuration:
        animated && !UIAccessibilityIsReduceMotionEnabled() ? .275 : 0 timingParameters:timing];
    [presentation.animator addAnimations:^{ host.renderer.transform = CGAffineTransformIdentity; host.backgroundColor = [UIColor colorWithWhite:0 alpha:.6]; }];
    [presentation.animator startAnimation];
}
