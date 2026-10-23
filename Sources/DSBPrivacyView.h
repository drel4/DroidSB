// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
FOUNDATION_EXPORT NSString *const DSBPrivacyChangedNotification;
FOUNDATION_EXPORT NSUInteger DSBPrivacyMaskForBar(UIView *bar, id data);
FOUNDATION_EXPORT void DSBPrivacyManagerUpdated(id manager, id attributions);
@interface DSBPrivacyView : UIView
@property(nonatomic, readonly) double chromeAlpha;
@property(nonatomic, readonly) double chromeShift;
@property(nonatomic, readonly) CGFloat reservedWidth;
@property(nonatomic, copy) void (^frameChanged)(void);
- (void)setActivityMask:(NSUInteger)mask;
- (void)reset;
@end
