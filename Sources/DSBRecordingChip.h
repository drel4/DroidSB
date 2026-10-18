// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
BOOL DSBIsScreenRecording(UIView *bar, id data);
BOOL DSBPerformRecordingAction(UIView *bar);
@interface DSBRecordingChip : UIControl
- (void)updateFromEntry:(id)entry;
- (CGFloat)minimumWidthForHeight:(CGFloat)height;
@end
