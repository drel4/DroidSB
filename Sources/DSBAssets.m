// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4. Android vector geometry: The Android Open Source Project.
#import "DSBAssets.h"
#import "DSBPath.h"
#import <dlfcn.h>

NSString *DSBResourceRoot(void) {
    static NSString *root;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Resolve beside our actual loaded dylib; also handles relocated rootless
        // prefixes. Do not assume /var/jb is the jailbreak's physical directory.
        Dl_info info;
        if (dladdr((const void *)&DSBResourceRoot, &info) && info.dli_fname) {
            NSString *lib = [[NSString stringWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
            root = [[lib stringByAppendingPathComponent:@"../../Application Support/DroidSB"] stringByStandardizingPath];
        }
        if (![[NSFileManager defaultManager] fileExistsAtPath:[root stringByAppendingPathComponent:@"icons.json"]])
            root = @"/var/jb/Library/Application Support/DroidSB";
    });
    return root;
}

static NSDictionary *Load(NSString *name) {
    NSData *data = [NSData dataWithContentsOfFile:[DSBResourceRoot() stringByAppendingPathComponent:name]];
    id result = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    return [result isKindOfClass:NSDictionary.class] ? result : @{};
}

NSDictionary *DSBBatteryGlyphs(void) {
    static NSDictionary *glyphs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ glyphs = Load(@"battery-glyphs.json"); });
    return glyphs;
}

static void DrawNodes(CGContextRef ctx, NSArray *nodes) {
    for (NSDictionary *node in nodes) {
        if (node[@"group"]) {
            NSDictionary *t = node[@"transform"];
            CGFloat px = [t[@"pivotX"] doubleValue], py = [t[@"pivotY"] doubleValue];
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, [t[@"translateX"] doubleValue] + px, [t[@"translateY"] doubleValue] + py);
            CGContextRotateCTM(ctx, [t[@"rotation"] doubleValue] * M_PI / 180);
            CGContextScaleCTM(ctx, [t[@"scaleX"] doubleValue], [t[@"scaleY"] doubleValue]);
            CGContextTranslateCTM(ctx, -px, -py);
            DrawNodes(ctx, node[@"group"]);
            CGContextRestoreGState(ctx);
        } else {
            CGPathRef path = DSBCreatePath(node[@"clip"] ?: node[@"d"]);
            if (!path) continue;
            CGContextAddPath(ctx, path);
            CGPathRelease(path);
            if (node[@"clip"]) {
                CGContextClip(ctx);
            } else {
                CGContextSetGrayFillColor(ctx, 1, [node[@"alpha"] doubleValue]);
                if ([node[@"evenOdd"] boolValue]) CGContextEOFillPath(ctx);
                else CGContextFillPath(ctx);
            }
        }
    }
}

UIImage *DSBIcon(NSString *name, CGFloat height) {
    static NSDictionary *icons;
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ icons = Load(@"icons.json"); cache = [NSCache new]; });
    NSString *key = [NSString stringWithFormat:@"%@-%.2f-%.1f", name, height, UIScreen.mainScreen.scale];
    UIImage *cached = [cache objectForKey:key];
    if (cached) return cached;
    NSDictionary *icon = icons[name];
    CGFloat w = [icon[@"w"] doubleValue], h = [icon[@"h"] doubleValue];
    if (w <= 0 || h <= 0 || height <= 0) return nil;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(height * w / h, height), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(ctx, height / h, height / h);
    DrawNodes(ctx, icon[@"paths"]);
    UIImage *image = [UIGraphicsGetImageFromCurrentImageContext() imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIGraphicsEndImageContext();
    if (image) [cache setObject:image forKey:key];
    return image;
}
