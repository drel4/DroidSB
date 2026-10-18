// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4
#import "DSBTransientBar.h"
#import "DSBStatusBarView.h"
#import "DSBTransientGeometry.h"
#import "DSBTransientPolicy.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>

// The native grabber retains recognition and second-swipe routing.
// Presentation and the top grabber region are replaced; no global gesture
// recognizer/window is added.
static char TransientKey;
static char TouchKey;
static id latestData;
static __weak UIView *latestBar;
static NSHashTable *presentations;
static const char *FrameNotification = "dev.drel.droidsb/transient-frame";
static const char *OutsideNotification = "dev.drel.droidsb/transient-outside";
static int frameToken = -1, outsideToken = -1;
static uint64_t publishedFrame;
static uint16_t nextGeneration;
@class DSBTransientPresentation;
static __weak DSBTransientPresentation *activePresentation;
static void PublishTransientFrame(void);
static void CancelNativeAutoHide(id tongue) {
    SEL selector = NSSelectorFromString(@"_cancelPendingTongueDismissRequests");
    if ([tongue respondsToSelector:selector]) ((void (*)(id, SEL))objc_msgSend)(tongue, selector);
}

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
@end
@implementation DSBTransientTouch
@end

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
    context.fixedStart = [window convertPoint:[touch locationInView:window]
        toCoordinateSpace:window.screen.fixedCoordinateSpace];
    objc_setAssociatedObject(tongue, &TouchKey, context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void DSBCaptureTransientOrientation(id tongue, UIPanGestureRecognizer *gesture) {
    if (![gesture isKindOfClass:UIPanGestureRecognizer.class]
        || gesture.state != UIGestureRecognizerStateBegan || !DSBUsesWideTransientGrabber(tongue)) return;
    DSBTransientTouch *existing = objc_getAssociatedObject(tongue, &TouchKey);
    if (existing.gesture == gesture) return; // do not replace the true first touch
    UIView *host = DSBRead(tongue, @"containingView");
    if (![host isKindOfClass:UIView.class] || !host.window) return;
    CGPoint point = [gesture locationInView:host], delta = [gesture translationInView:host];
    DSBTransientTouch *context = [DSBTransientTouch new];
    context.screen = host.window.screen;
    context.gesture = gesture;
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
    return [self.renderer hitTest:[self convertPoint:point toView:self.renderer] withEvent:event];
}
@end

static void DSBLayoutTransientHost(DSBTransientHost *host, UIView *container, DSBTransientTouch *touch) {
    if (!host || !container.window) return;
    [container layoutIfNeeded];
    if (touch && touch.screen == container.window.screen) {
        // Resolve into the FINAL host coordinates, not the pre-presentation
        // coordinates captured at Began. This also works on the very first pull.
        UIWindow *window = container.window;
        CGPoint inWindow = [window convertPoint:touch.fixedStart fromCoordinateSpace:touch.screen.fixedCoordinateSpace];
        CGPoint point = [container convertPoint:inWindow fromView:window];
        CGPoint delta = [touch.gesture translationInView:container];
        CGRect b = container.bounds;
        unsigned edge = DSBPullEdge(point.x, point.y, delta.x, delta.y,
            b.origin.x, b.origin.y, b.size.width, b.size.height);
        BOOL portraitTop = edge == DSBEdgeTop && b.size.height > b.size.width;
        CGFloat height = portraitTop ? MIN(54, MAX(20, window.safeAreaInsets.top)) : 20;
        DSBTransientGeometry g = DSBGeometryForEdge(edge, b.origin.x, b.origin.y, b.size.width, b.size.height, height);
        host.bounds = CGRectMake(0, 0, g.width, g.height);
        host.center = CGPointMake(g.centerX, g.centerY);
        host.transform = CGAffineTransformMake(g.a, g.b, g.c, g.d, 0, 0);
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

@interface DSBTransientPresentation : NSObject
@property(nonatomic, weak) UIView *arrow;
@property(nonatomic) BOOL arrowWasHidden;
@property(nonatomic, strong) DSBTransientHost *host;
@property(nonatomic, strong) UIViewPropertyAnimator *animator;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) NSTimer *autoHideTimer;
@property(nonatomic, weak) id tongue;
@property(nonatomic, weak) UIPanGestureRecognizer *nativeGesture;
@property(nonatomic, strong) NSHashTable<UITouch *> *barTouches;
@property(nonatomic) uint16_t generation;
@property(nonatomic) BOOL outsideRequested;
@property(nonatomic) BOOL policyDismissing;
- (void)refresh;
- (void)dismiss:(BOOL)animated;
- (void)scheduleAutoHide;
- (void)requestOutsideHide;
- (void)expireAutoHide;
@end

@implementation DSBTransientPresentation
- (void)refresh {
    if (!DSBEnabled()) { [self expireAutoHide]; return; }
    self.host.currentAggregatedData = latestData;
    self.host.sourceBar = latestBar;
    self.host.renderer.actionBar = latestBar;
    [self.host.renderer refresh];
    [self.host.renderer layoutIfNeeded];
    // Also recover from a canceled/deallocated touch without an end callback.
    if (self.host && !self.autoHideTimer) [self scheduleAutoHide];
    if (activePresentation == self) PublishTransientFrame();
}
- (BOOL)isInteracting {
    UIGestureRecognizerState state = self.nativeGesture.state;
    return self.barTouches.allObjects.count > 0 || (self.nativeGesture
        && (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged));
}
- (void)scheduleAutoHide {
    [self.autoHideTimer invalidate]; self.autoHideTimer = nil;
    if (!self.host || [self isInteracting]) return;
    BOOL assistive = UIAccessibilityIsVoiceOverRunning() || UIAccessibilityIsSwitchControlRunning();
    __weak DSBTransientPresentation *weakSelf = self;
    self.autoHideTimer = [NSTimer timerWithTimeInterval:DSBTransientTimeout(self.outsideRequested, assistive)
        repeats:NO block:^(__unused NSTimer *timer) {
        DSBTransientPresentation *view = weakSelf;
        if (!view.host) return;
        if ([view isInteracting]) { [view scheduleAutoHide]; return; }
        // Use the native timer-dismiss entry point rather than guessing a style
        // enum or leaving SpringBoard's tongueVisible/second-swipe state behind.
        [view expireAutoHide];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.autoHideTimer forMode:NSRunLoopCommonModes];
}
- (void)expireAutoHide {
    if (!self.host) return;
    self.policyDismissing = YES;
    @try {
        SEL selector = NSSelectorFromString(@"_dismissTongue:");
        id tongue = self.tongue;
        if ([tongue respondsToSelector:selector]) ((void (*)(id, SEL, id))objc_msgSend)(tongue, selector, nil);
        if (self.host) [self dismiss:YES];
    } @finally { self.policyDismissing = NO; }
}
- (void)requestOutsideHide {
    if (!self.host || self.outsideRequested) return; // repeated touches don't postpone it
    self.outsideRequested = YES;
    [self scheduleAutoHide];
}
- (void)dismiss:(BOOL)animated {
    [self.autoHideTimer invalidate]; self.autoHideTimer = nil;
    [self.barTouches removeAllObjects];
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
    if (activePresentation == self) { activePresentation = nil; PublishTransientFrame(); }
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
- (void)dealloc { [self.timer invalidate]; [self.autoHideTimer invalidate]; }
@end

static void PublishTransientFrame(void) {
    DSBTransientPresentation *presentation = activePresentation;
    DSBTransientHost *host = presentation.host;
    publishedFrame = 0;
    if (host.window.screen == UIScreen.mainScreen) {
        UIWindow *window = host.window;
        id<UICoordinateSpace> space = window.screen.fixedCoordinateSpace;
        CGRect rect = [window convertRect:[host convertRect:host.bounds toView:window] toCoordinateSpace:space];
        CGRect bounds = space.bounds;
        if (bounds.size.width > 0 && bounds.size.height > 0) {
            publishedFrame = DSBTransientFrame(presentation.generation,
                (CGRectGetMinX(rect)-bounds.origin.x)/bounds.size.width,
                (CGRectGetMinY(rect)-bounds.origin.y)/bounds.size.height,
                (CGRectGetMaxX(rect)-bounds.origin.x)/bounds.size.width,
                (CGRectGetMaxY(rect)-bounds.origin.y)/bounds.size.height);
        }
    }
    if (frameToken >= 0) { notify_set_state(frameToken, publishedFrame); notify_post(FrameNotification); }
}

void DSBInitializeTransientAutoHide(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (notify_register_check(FrameNotification, &frameToken) != NOTIFY_STATUS_OK) frameToken = -1;
        if ([NSProcessInfo.processInfo.processName isEqualToString:@"SpringBoard"]) {
            nextGeneration = (uint16_t)arc4random_uniform(UINT16_MAX);
            PublishTransientFrame(); // clear stale state after a respring
            if (notify_register_dispatch(OutsideNotification, &outsideToken, dispatch_get_main_queue(), ^(int token) {
                uint64_t generation = 0;
                if (notify_get_state(token, &generation) == NOTIFY_STATUS_OK
                    && DSBTransientGenerationMatches(publishedFrame, generation)) [activePresentation requestOutsideHide];
            }) != NOTIFY_STATUS_OK) outsideToken = -1;
            for (NSString *name in @[UIAccessibilityVoiceOverStatusDidChangeNotification, UIAccessibilitySwitchControlStatusDidChangeNotification]) {
                [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                    usingBlock:^(__unused NSNotification *note) { [activePresentation scheduleAutoHide]; }];
            }
        } else if (notify_register_check(OutsideNotification, &outsideToken) != NOTIFY_STATUS_OK) outsideToken = -1;
    });
}

void DSBObserveTransientEvent(UIEvent *event) {
    if (event.type != UIEventTypeTouches || frameToken < 0) return;
    // register_check uses shared memory. Hidden bars must not cause a notifyd
    // round trip on every app touch/move; read state only after publication.
    static uint64_t observedFrame;
    int changed = 0;
    if (notify_check(frameToken, &changed) != NOTIFY_STATUS_OK) return;
    if (changed && notify_get_state(frameToken, &observedFrame) != NOTIFY_STATUS_OK) observedFrame = 0;
    uint64_t frame = observedFrame;
    if (!(frame >> 48)) return;
    DSBTransientPresentation *presentation = activePresentation;
    BOOL changedBarTouch = NO;
    for (UITouch *touch in event.allTouches) {
        if (touch.window.screen != UIScreen.mainScreen) continue;
        if (touch.phase == UITouchPhaseBegan) {
            UIWindow *window = touch.window;
            id<UICoordinateSpace> space = window.screen.fixedCoordinateSpace;
            CGPoint point = [window convertPoint:[touch locationInView:window] toCoordinateSpace:space];
            CGRect bounds = space.bounds;
            if (bounds.size.width <= 0 || bounds.size.height <= 0) continue;
            BOOL inside = DSBTransientContains(frame, (point.x-bounds.origin.x)/bounds.size.width,
                (point.y-bounds.origin.y)/bounds.size.height);
            if (inside && presentation.host) {
                [presentation.barTouches addObject:touch];
                presentation.outsideRequested = NO;
                changedBarTouch = YES;
            } else if (!inside) {
                if (presentation.host) [presentation requestOutsideHide];
                else if (outsideToken >= 0) {
                    notify_set_state(outsideToken, frame >> 48);
                    notify_post(OutsideNotification);
                }
            }
        } else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
            if ([presentation.barTouches containsObject:touch]) {
                [presentation.barTouches removeObject:touch]; changedBarTouch = YES;
            }
        }
    }
    if (changedBarTouch) [presentation scheduleAutoHide];
}

BOOL DSBReplacesNativeTransientDismiss(id tongue) {
    DSBTransientPresentation *view = objc_getAssociatedObject(tongue, &TransientKey);
    return view.host && !view.policyDismissing;
}

void DSBUpdateTransientGesture(id tongue, UIPanGestureRecognizer *gesture) {
    DSBTransientPresentation *view = objc_getAssociatedObject(tongue, &TransientKey);
    if (!view.host || ![gesture isKindOfClass:UIPanGestureRecognizer.class]) return;
    view.nativeGesture = gesture;
    CancelNativeAutoHide(tongue);
    [view scheduleAutoHide];
}

void DSBObserveNativeBar(UIView *bar) {
    // This runs in the owning process. SpringBoard supplies the fullscreen row;
    // app-process bar data stays local. Only outside-touch dismissal uses IPC.
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
        old.outsideRequested = NO;
        old.nativeGesture = touch.gesture;
        CancelNativeAutoHide(tongue);
        PublishTransientFrame();
        [old scheduleAutoHide];
        [old refresh];
        return;
    }
    // Finish a pending dismissal before reusing the native arrow's hidden state.
    if (old.animator.state == UIViewAnimatingStateActive) [old.animator stopAnimation:NO];
    if (old.animator.state == UIViewAnimatingStateStopped) [old.animator finishAnimationAtPosition:UIViewAnimatingPositionEnd];

    DSBTransientPresentation *presentation = [DSBTransientPresentation new];
    presentation.tongue = tongue;
    presentation.nativeGesture = touch.gesture;
    presentation.barTouches = [NSHashTable weakObjectsHashTable];
    if (++nextGeneration == 0) ++nextGeneration;
    presentation.generation = nextGeneration;
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
    activePresentation = presentation;
    CancelNativeAutoHide(tongue);
    PublishTransientFrame();
    if (!presentations) presentations = [NSHashTable weakObjectsHashTable];
    [presentations addObject:presentation];
    __weak DSBTransientPresentation *weakPresentation = presentation;
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
        PublishTransientFrame();
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
