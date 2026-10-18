// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
FOUNDATION_EXPORT void DSBObserveNativeBar(UIView *bar);
FOUNDATION_EXPORT void DSBCaptureTransientOrientation(id tongue, UIPanGestureRecognizer *gesture);
FOUNDATION_EXPORT void DSBCaptureTransientTouch(id tongue, UIGestureRecognizer *gesture, UITouch *touch);
FOUNDATION_EXPORT BOOL DSBUsesWideTransientGrabber(id tongue);
FOUNDATION_EXPORT void DSBPresentTransientBar(id tongue, BOOL animated);
FOUNDATION_EXPORT void DSBDismissTransientBar(id tongue, BOOL animated);
