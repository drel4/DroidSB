// SPDX-License-Identifier: Apache-2.0
#import "DSBFrameAnimator.h"
#import <QuartzCore/QuartzCore.h>
@interface DSBFrameAnimator (Tick)
- (void)tick:(CADisplayLink *)link;
@end
@interface DSBFrameProxy : NSObject
@property(nonatomic, weak) DSBFrameAnimator *owner;
- (void)tick:(CADisplayLink *)link;
@end
@implementation DSBFrameProxy
- (void)tick:(CADisplayLink *)link { [self.owner tick:link]; }
@end

@implementation DSBFrameAnimator {
    CADisplayLink *_link;
    NSTimeInterval _duration, _start;
    void (^_update)(double);
    void (^_completion)(UIViewAnimatingPosition);
    UIViewAnimatingState _state;
}
- (instancetype)initWithDuration:(NSTimeInterval)duration update:(void (^)(double))update
    completion:(void (^)(UIViewAnimatingPosition))completion {
    if ((self = [super init])) { _duration = duration; _update = [update copy]; _completion = [completion copy]; }
    return self;
}
- (UIViewAnimatingState)state { return _state; }
- (void)apply:(double)fraction {
    // Never inherit the native grabber's UIView transaction or its easing.
    void (^update)(double) = _update;
    [UIView performWithoutAnimation:^{ if (update) update(fraction); }];
}
- (void)startAnimation {
    if (_state != UIViewAnimatingStateInactive) return;
    _state = UIViewAnimatingStateActive;
    if (_duration <= 0) { [self finishAnimationAtPosition:UIViewAnimatingPositionEnd]; return; }
    [self apply:0];
    _start = CACurrentMediaTime();
    DSBFrameProxy *proxy = [DSBFrameProxy new]; proxy.owner = self;
    _link = [CADisplayLink displayLinkWithTarget:proxy selector:@selector(tick:)];
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}
- (void)tick:(CADisplayLink *)link {
    double fraction = MIN(1, MAX(0, (link.targetTimestamp - _start)/_duration));
    if (fraction >= 1) [self finishAnimationAtPosition:UIViewAnimatingPositionEnd];
    else [self apply:fraction];
}
- (void)stopAnimation:(BOOL)withoutFinishing {
    [_link invalidate]; _link = nil;
    _state = withoutFinishing ? UIViewAnimatingStateInactive : UIViewAnimatingStateStopped;
    if (withoutFinishing) { _update = nil; _completion = nil; }
}
- (void)finishAnimationAtPosition:(UIViewAnimatingPosition)position {
    [_link invalidate]; _link = nil;
    if (position != UIViewAnimatingPositionCurrent) [self apply:position == UIViewAnimatingPositionEnd ? 1 : 0];
    _state = UIViewAnimatingStateInactive;
    void (^completion)(UIViewAnimatingPosition) = _completion;
    _completion = nil; _update = nil;
    if (completion) completion(position);
}
- (void)dealloc { [_link invalidate]; }
@end
