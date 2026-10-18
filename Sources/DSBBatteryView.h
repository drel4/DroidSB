// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface DSBBatteryView : UIView
@property(nonatomic) NSInteger level; // -1 = genuinely unknown, not a fake 0/100
@property(nonatomic) BOOL charging;
@property(nonatomic) BOOL powerSave;
@property(nonatomic) BOOL showPercent;
@property(nonatomic) BOOL lightContent;
@end
