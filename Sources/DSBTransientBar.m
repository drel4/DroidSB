// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4
#import "DSBTransientBar.h"
#import "DSBStatusBarView.h"
#import "DSBTransientGeometry.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

// The native grabber retains recognition, second-swipe routing and auto-dismiss.
// Presentation and the top grabber region are replaced; no global gesture
// recognizer/window is added.
static char TransientKey;
static char TouchKey;
static id latestData;
static __weak UIView *latestBar;
static NSHashTable *presentations;

static BOOL DSBIsTopTongue(id tongue) {
    id delegate = DSBRead(tongue, @"delegate");
    Class coverSheet = NSClassFromString(@"SBCoverSheetPrimarySlidingViewController");
    NSNumber *edge = DSBRead(tongue, @"screenEdge") ?: DSBRead(tongue, @"edge");
    return (coverSheet && [delegate isKindOfClass:coverSheet])
        || (edge && edge.unsignedIntegerValue == UIRectEdgeTop);
}

BOOL DSBUsesWideTransientGrabber(id tongue) {
    return DSBEnabled() && DSBIsTopTongue(tongue);
}

@interface DSBTransientTouch : NSObject
@property(nonatomic, strong) UIScreen *screen;
@property(nonatomic) CGPoint fixedStart;
@property(nonatomic, weak) UIPanGestureRecognizer *gesture;
@property(nonatomic) UIInterfaceOrientation orientation;
@end
@implementation DSBTransientTouch
@end

static UIInterfaceOrientation PullOrientation(UIPanGestureRecognizer *gesture, UIInterfaceOrientation fallback) {
    SEL selector = NSSelectorFromString(@"_touchInterfaceOrientation");
    if ([gesture respondsToSelector:selector]) {
        UIInterfaceOrientation value = ((UIInterfaceOrientation (*)(id, SEL))objc_msgSend)(gesture, selector);
        if (value >= UIInterfaceOrientationPortrait && value <= UIInterfaceOrientationLandscapeRight) return value;
    }
    return fallback;
}

// Extends LineageQS's original-start-edge approach (Apache-2.0,
// Copyright 2026 makr). Keep the actual touch in rotation-independent screen
// space: the first presentation may orient/create its host AFTER recognition.
void DSBCaptureTransientTouch(id tongue, UIGestureRecognizer *gesture, UITouch *touch) {
    if (![gesture isKindOfClass:UIPanGestureRecognizer.class] || !DSBUsesWideTransientGrabber(tongue)) return;
    objc_setAssociatedObject(tongue, &TouchKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIWindow *window = touch.window;
    if (!window) return;
    DSBTransientTouch *context = [DSBTransientTouch new];
    context.screen = window.screen;
    context.gesture = (UIPanGestureRecognizer *)gesture;
    context.orientation = PullOrientation(context.gesture, window.windowScene.interfaceOrientation);
    context.fixedStart = [window convertPoint:[touch locationInView:window]
        toCoordinateSpace:window.screen.fixedCoordinateSpace];
    objc_setAssociatedObject(tongue, &TouchKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void DSBCaptureTransientOrientation(id tongue, UIPanGestureRecognizer *gesture) {
    if (![gesture isKindOfClass:UIPanGestureRecognizer.class]
        || gesture.state != UIGestureRecognizerStateBegan || !DSBUsesWideTransientGrabber(tongue)) return;
    DSBTransientTouch *existing = objc_getAssociatedObject(tongue, &TouchKey);
    if (existing.gesture == gesture) {
        existing.orientation = PullOrientation(gesture, existing.orientation);
        return; // retain the true first touch, update orientation at recognition
    }
    UIView *host = DSBRead(tongue, @"containingView");
    if (![host isKindOfClass:UIView.class] || !host.window) return;
    CGPoint point = [gesture locationInView:host], delta = [gesture translationInView:host];
    DSBTransientTouch *context = [DSBTransientTouch new];
    context.screen = host.window.screen;
    context.gesture = gesture;
    context.orientation = PullOrientation(gesture, host.window.windowScene.interfaceOrientation);
    CGPoint start = CGPointMake(point.x - delta.x, point.y - delta.y);
    context.fixedStart = [host.window convertPoint:[host convertPoint:start toView:host.window]
        toCoordinateSpace:context.screen.fixedCoordinateSpace];
    objc_setAssociatedObject(tongue, &TouchKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

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
    if (self.hidden || self.alpha <= .01 || !self.userInteractionEnabled || ![self pointInside:point withEvent:event]) return nil;
    return [self.renderer hitTest:[self convertPoint:point toView:self.renderer] withEvent:event] ?: self;
}
@end

static void DSBLayoutTransientHost(DSBTransientHost *host, UIView *container, DSBTransientTouch *touch) {
    if (!host || !container.window) return;
    [container layoutIfNeeded];
    if (touch && touch.screen == container.window.screen) {
        // Resolve into the FINAL host coordinates, not the pre-presentation
        // coordinates captured at Began. This also works on the very first pull.
        UIWindow *window = container.window;
        id<UICoordinateSpace> fixed = touch.screen.fixedCoordinateSpace;
        CGRect b = fixed.bounds;
        UIInterfaceOrientation orientation = PullOrientation(touch.gesture, touch.orientation);
        BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
        unsigned edge = DSBDisplayTopEdge(landscape, orientation == UIInterfaceOrientationPortraitUpsideDown,
            touch.fixedStart.x, CGRectGetMidX(b));
        CGFloat height = landscape ? 20 : MIN(54, MAX(20, window.safeAreaInsets.top));
        DSBTransientGeometry g = DSBGeometryForEdge(edge, b.origin.x, b.origin.y, b.size.width, b.size.height, height);
        // Form the row in fixed screen space, then transform its basis into the
        // actual host. Neither its nearest boundary nor pan direction chooses top.
        CGPoint center = [container convertPoint:[window convertPoint:CGPointMake(g.centerX, g.centerY)
            fromCoordinateSpace:fixed] fromView:window];
        CGPoint px = [container convertPoint:[window convertPoint:CGPointMake(g.centerX+g.a, g.centerY+g.b)
            fromCoordinateSpace:fixed] fromView:window];
        CGPoint py = [container convertPoint:[window convertPoint:CGPointMake(g.centerX+g.c, g.centerY+g.d)
            fromCoordinateSpace:fixed] fromView:window];
        host.bounds = CGRectMake(0, 0, g.width, g.height);
        host.center = center;
        host.transform = CGAffineTransformMake(px.x-center.x, px.y-center.y, py.x-center.x, py.y-center.y, 0, 0);
    } else {
        // Programmatic presentation without a touch: use the current scene.
        id<UICoordinateSpace> space = container.window.windowScene.coordinateSpace ?: container.window;
        CGRect screen = space.bounds;
        CGFloat height = MIN(54, MAX(20, container.window.safeAreaInsets.top));
        CGPoint p0 = [container convertPoint:screen.origin fromCoordinateSpace:space];
        CGPoint px = [container convertPoint:CGPointMake(screen.origin.x + 1, screen.origin.y) fromCoordinateSpace:space];
        CGPoint py = [container convertPoint:CGPointMake(screen.origin.x, screen.origin.y + 1) fromCoordinateSpace:space];
        host.bounds = CGRectMake(0, 0, screen.size.width, height);
        host.center = [container convertPoint:CGPointMake(CGRectGetMidX(screen), CGRectGetMinY(screen) + height/2) fromCoordinateSpace:space];
        host.transform = CGAffineTransformMake(px.x-p0.x, px.y-p0.y, py.x-p0.x, py.y-p0.y, 0, 0);
    }
}

// A non-recognizing observer attached ONLY to the bar's bounds. It cannot
// prevent another recognizer, delay controls, or observe underlying app touches.
@interface DSBBarTouchObserver : UIGestureRecognizer
@property(nonatomic, copy) void (^interactionChanged)(BOOL active);
@end
@implementation DSBBarTouchObserver {
    NSUInteger _touchCount;
    BOOL _active;
}
- (void)publish:(BOOL)active {
    if (_active == active) return;
    _active = active;
    if (self.interactionChanged) self.interactionChanged(active);
}
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)other { return NO; }
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)other { return NO; }
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    _touchCount += touches.count;
    [self publish:YES];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    _touchCount -= MIN(_touchCount, touches.count);
    if (!_touchCount) {
        [self publish:NO];
        if (self.state == UIGestureRecognizerStatePossible) self.state = UIGestureRecognizerStateFailed;
    }
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}
- (void)reset { [super reset]; _touchCount = 0; [self publish:NO]; }
@end

@interface DSBTransientPresentation : NSObject
@property(nonatomic, weak) UIView *arrow;
@property(nonatomic) BOOL arrowWasHidden;
@property(nonatomic, strong) DSBTransientHost *host;
@property(nonatomic, strong) UIViewPropertyAnimator *animator;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, weak) id tongue;
@property(nonatomic, weak) UIPanGestureRecognizer *pullGesture;
@property(nonatomic) BOOL barInteracting;
@property(nonatomic) BOOL ownsAutoHide;
- (void)refresh;
- (void)dismiss:(BOOL)animated;
- (void)configureAutoHide:(BOOL)requested;
- (void)resetAutoHide;
@end

@implementation DSBTransientPresentation
- (void)refresh {
    if (!DSBEnabled()) {
        // Clear native tongue visibility as well if we replaced its deadline.
        id tongue = self.tongue;
        SEL selector = NSSelectorFromString(@"_dismissTongue:");
        if (self.ownsAutoHide && [tongue respondsToSelector:selector])
            ((void (*)(id, SEL, id))objc_msgSend)(tongue, selector, nil);
        [self dismiss:NO];
        return;
    }
    self.host.currentAggregatedData = latestData;
    self.host.sourceBar = latestBar;
    self.host.renderer.actionBar = latestBar;
    [self.host.renderer refresh];
    [self.host.renderer layoutIfNeeded];
}
- (void)configureAutoHide:(BOOL)requested {
    if (self.ownsAutoHide && self.tongue) [NSObject cancelPreviousPerformRequestsWithTarget:self.tongue
        selector:NSSelectorFromString(@"_dismissTongue:") object:nil];
    self.ownsAutoHide = requested && [self.tongue respondsToSelector:NSSelectorFromString(@"_dismissTongue:")]
        && [self.tongue respondsToSelector:NSSelectorFromString(@"_cancelPendingTongueDismissRequests")];
    [self resetAutoHide];
}
- (void)resetAutoHide {
    if (!self.host || !self.ownsAutoHide) return;
    id tongue = self.tongue;
    if (!tongue) { self.ownsAutoHide = NO; return; }
    ((void (*)(id, SEL))objc_msgSend)(tongue, NSSelectorFromString(@"_cancelPendingTongueDismissRequests"));
    SEL dismiss = NSSelectorFromString(@"_dismissTongue:");
    [NSObject cancelPreviousPerformRequestsWithTarget:tongue selector:dismiss object:nil];
    UIGestureRecognizerState state = self.pullGesture.state;
    BOOL pulling = self.pullGesture && (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged);
    if (!self.barInteracting && !pulling) {
        // Reuse native dismissal/state cleanup. No timer callback hooks, app
        // event hooks, notification IPC or startup initialization are involved.
        [tongue performSelector:dismiss withObject:nil afterDelay:2.25 inModes:@[NSRunLoopCommonModes]];
    }
}
- (void)dismiss:(BOOL)animated {
    if (self.ownsAutoHide && self.tongue) [NSObject cancelPreviousPerformRequestsWithTarget:self.tongue
        selector:NSSelectorFromString(@"_dismissTongue:") object:nil];
    self.ownsAutoHide = NO;
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

void DSBUpdateTransientBarInteraction(id tongue, UIPanGestureRecognizer *gesture) {
    if (![gesture isKindOfClass:UIPanGestureRecognizer.class]) return;
    DSBTransientPresentation *presentation = objc_getAssociatedObject(tongue, &TransientKey);
    presentation.pullGesture = gesture;
    [presentation resetAutoHide];
}

void DSBPresentTransientBar(id tongue, BOOL animated, BOOL autoDismiss) {
    if (!DSBEnabled() || !latestData) return;
    // Do not replace the bottom Control Center/home-indicator grabber.
    UIView *container = DSBRead(tongue, @"containingView");
    UIView *arrow = DSBRead(tongue, @"tongueContainer");
    if (!DSBIsTopTongue(tongue) || ![container isKindOfClass:UIView.class] || !container.window
        || ![arrow isKindOfClass:UIView.class]) return;

    DSBTransientTouch *touch = objc_getAssociatedObject(tongue, &TouchKey);
    objc_setAssociatedObject(tongue, &TouchKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    DSBTransientPresentation *old = objc_getAssociatedObject(tongue, &TransientKey);
    if (old.host) {
        if (touch) DSBLayoutTransientHost(old.host, container, touch);
        old.pullGesture = touch.gesture;
        [old configureAutoHide:autoDismiss];
        [old refresh];
        return;
    }
    // Finish a pending dismissal before reusing the native arrow's hidden state.
    if (old.animator.state == UIViewAnimatingStateActive) [old.animator stopAnimation:NO];
    if (old.animator.state == UIViewAnimatingStateStopped) [old.animator finishAnimationAtPosition:UIViewAnimatingPositionEnd];

    DSBTransientPresentation *presentation = [DSBTransientPresentation new];
    presentation.tongue = tongue;
    presentation.pullGesture = touch.gesture;
    presentation.arrow = arrow;
    presentation.arrowWasHidden = arrow.hidden;
    DSBTransientHost *host = [DSBTransientHost new];
    host.clipsToBounds = YES;
    host.foregroundView = [UIView new]; // renderer suppresses only this placeholder
    host.foregroundColor = UIColor.whiteColor;
    presentation.host = host;
    [container addSubview:host];
    DSBLayoutTransientHost(host, container, touch);
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
    DSBBarTouchObserver *observer = [[DSBBarTouchObserver alloc] initWithTarget:nil action:NULL];
    observer.cancelsTouchesInView = NO;
    observer.delaysTouchesBegan = NO;
    observer.delaysTouchesEnded = NO;
    observer.interactionChanged = ^(BOOL active) {
        DSBTransientPresentation *current = weakPresentation;
        current.barInteracting = active;
        [current resetAutoHide];
    };
    [host addGestureRecognizer:observer];
    [presentation configureAutoHide:autoDismiss];
    presentation.timer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(__unused NSTimer *timer) { [weakPresentation refresh]; }];
    [NSRunLoop.mainRunLoop addTimer:presentation.timer forMode:NSRunLoopCommonModes];

    // Native first-use host setup can finish later in the same main-queue turn.
    // Reproject the SAME fixed start, without measuring an already-moved finger.
    __weak UIView *weakContainer = container;
    dispatch_async(dispatch_get_main_queue(), ^{
        DSBTransientPresentation *current = weakPresentation;
        UIView *parent = weakContainer;
        if (current.host != host || host.superview != parent) return;
        DSBLayoutTransientHost(host, parent, touch);
        [current refresh];
    });
    host.renderer.transform = CGAffineTransformMakeTranslation(0, -host.bounds.size.height);
    UICubicTimingParameters *timing = [[UICubicTimingParameters alloc]
        initWithControlPoint1:CGPointMake(.4, 0) controlPoint2:CGPointMake(.2, 1)];
    presentation.animator = [[UIViewPropertyAnimator alloc] initWithDuration:
        animated && !UIAccessibilityIsReduceMotionEnabled() ? .275 : 0 timingParameters:timing];
    [presentation.animator addAnimations:^{ host.renderer.transform = CGAffineTransformIdentity; host.backgroundColor = [UIColor colorWithWhite:0 alpha:.6]; }];
    [presentation.animator startAnimation];
}
