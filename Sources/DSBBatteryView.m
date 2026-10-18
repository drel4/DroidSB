// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4; adapted from AOSP BatteryFrame/BatteryColors/UnifiedBattery.
// Copyright (C) 2025 The Android Open Source Project. See NOTICE and reference/.
#import "DSBBatteryView.h"
#import "DSBAssets.h"
#import "DSBPath.h"

static void Glyph(CGContextRef ctx, NSDictionary *g, CGFloat x, CGFloat y, UIColor *color) {
    CGPathRef p = DSBCreatePath(g[@"d"]);
    if (!p) return;
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, x, y);
    CGContextAddPath(ctx, p);
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);
    CGPathRelease(p);
}

@implementation DSBBatteryView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.isAccessibilityElement = YES;
        self.contentMode = UIViewContentModeRedraw;
        _level = -1;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat scale = MIN(self.bounds.size.height / 13, self.bounds.size.width / 31);
    CGContextTranslateCTM(ctx, 0, (self.bounds.size.height - 13 * scale) / 2);
    CGContextScaleCTM(ctx, scale, scale);
    UIColor *ink = self.lightContent ? UIColor.whiteColor : UIColor.blackColor;
    UIColor *fill = self.charging ? [UIColor colorWithRed:24/255.0 green:204/255.0 blue:71/255.0 alpha:1]
        : self.powerSave ? [UIColor colorWithRed:1 green:201/255.0 blue:23/255.0 alpha:1]
        : (self.level >= 0 && self.level <= 5) ? [UIColor colorWithRed:1 green:14/255.0 blue:1/255.0 alpha:1] : ink;
    NSDictionary *all = DSBBatteryGlyphs();
    NSMutableArray *digits = [NSMutableArray new];
    if (self.level < 0) {
        if (all[@"Question"]) [digits addObject:all[@"Question"]];
    } else if (self.showPercent) {
        NSArray *names = @[@"Zero", @"One", @"Two", @"Three", @"Four", @"Five", @"Six", @"Seven", @"Eight", @"Nine"];
        NSString *text = [@(MAX(0, MIN(100, self.level))) stringValue];
        for (NSUInteger i = 0; i < text.length; i++) {
            NSDictionary *g = all[names[[text characterAtIndex:i] - '0']];
            if (g) [digits addObject:g];
        }
    }
    CGFloat alpha = self.lightContent ? (digits.count ? .55 : .45) : (digits.count ? .55 : .20);
    if (!self.lightContent && (self.charging || self.powerSave)) alpha = .20;
    UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 24, 13) cornerRadius:4];
    [[ink colorWithAlphaComponent:alpha] setFill];
    [body fill];
    if (self.level > 0) {
        CGContextSaveGState(ctx);
        [body addClip];
        CGContextClipToRect(ctx, CGRectMake(0, 0, ceil(MIN(100, self.level) * .24), 13));
        [fill setFill];
        [body fill];
        CGContextRestoreGState(ctx);
    }
    UIColor *glyphColor = !self.lightContent && !self.charging && !self.powerSave
        ? [UIColor colorWithWhite:1 alpha:.9] : [UIColor colorWithWhite:0 alpha:.75];
    CGFloat width = 0;
    for (NSDictionary *g in digits) width += [g[@"w"] doubleValue];
    width += .8 * MAX(0, (NSInteger)digits.count - 1);
    CGFloat x = (24 - width) / 2;
    for (NSDictionary *g in digits) {
        Glyph(ctx, g, x, (13 - [g[@"h"] doubleValue]) / 2, glyphColor);
        x += [g[@"w"] doubleValue] + .8;
    }
    NSDictionary *attr = self.charging ? all[@"Bolt"] : self.powerSave ? all[@"Plus"] : nil;
    if (attr) {
        CGFloat gw = [attr[@"w"] doubleValue], gh = [attr[@"h"] doubleValue];
        CGPathRef p = DSBCreatePath(attr[@"d"]);
        if (p) {
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, 24 - .2 * gw, (13 - gh) / 2);
            CGContextSetBlendMode(ctx, kCGBlendModeClear);
            CGContextSetLineWidth(ctx, 2);
            CGContextAddPath(ctx, p);
            CGContextStrokePath(ctx);
            CGContextRestoreGState(ctx);
            CGPathRelease(p);
        }
        Glyph(ctx, attr, 24 - .2 * gw, (13 - gh) / 2, ink);
    } else {
        NSDictionary *cap = @{@"d": @"M0.3333,-0.0037L0,-0.0037L0,6.0234L0.3333,6.0234C0.9777,6.0234 1.5,5.5011 1.5,4.8567L1.5,1.163C1.5,0.5187 0.9777,-0.0037 0.3333,-0.0037Z"};
        Glyph(ctx, cap, 25, (13 - 6.03) / 2, [ink colorWithAlphaComponent:self.level >= 100 ? 1 : alpha]);
    }
}
@end
