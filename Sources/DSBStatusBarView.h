// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface DSBStatusBarView : UIView
@property(nonatomic, weak) UIView *nativeBar;
- (BOOL)refresh;
- (void)restoreNative;
@end
id DSBRead(id object, NSString *key);
BOOL DSBEnabled(void);
