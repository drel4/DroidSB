// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "DSBStatusBarView.h"

@interface _UIStatusBar : UIView
@end

static char ViewKey;
static void Update(UIView *bar) {
    DSBStatusBarView *view = objc_getAssociatedObject(bar, &ViewKey);
    if (!view) {
        view = [[DSBStatusBarView alloc] initWithFrame:bar.bounds];
        view.nativeBar = bar;
        objc_setAssociatedObject(bar, &ViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [bar addSubview:view];
    }
    [view refresh];
}

%hook _UIStatusBar
- (void)layoutSubviews {
    %orig;
    Update(self);
}
- (void)_updateWithAggregatedData:(id)data {
    %orig;
    Update(self);
}
- (void)setForegroundColor:(UIColor *)color {
    %orig;
    Update(self);
}
%end

%ctor {
    @autoreleasepool {
        // UIKit bundle filtering covers SpringBoard and app-owned status bars;
        // do not inject custom windows or rely on SpringBoard-only telemetry.
        if (@available(iOS 15.0, *)) {
            if (NSClassFromString(@"_UIStatusBar")) { %init; }
        }
    }
}
