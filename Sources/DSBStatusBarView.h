// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface DSBStatusBarView : UIView
@property(nonatomic, weak) UIView *nativeBar;
- (BOOL)refresh;
- (void)restoreNative;
- (BOOL)recordingChipContainsPoint:(CGPoint)point;
@end
FOUNDATION_EXPORT id DSBRead(id object, NSString *key);
FOUNDATION_EXPORT BOOL DSBEnabled(void);
