// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface DSBFrameAnimator : NSObject
@property(nonatomic, readonly) UIViewAnimatingState state;
- (instancetype)initWithDuration:(NSTimeInterval)duration update:(void (^)(double fraction))update
    completion:(void (^)(UIViewAnimatingPosition position))completion;
- (void)startAnimation;
- (void)stopAnimation:(BOOL)withoutFinishing;
- (void)finishAnimationAtPosition:(UIViewAnimatingPosition)position;
@end
