// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4; CoreText variable-font approach adapted from LineageQS,
// Copyright 2026 makr. The bundled font itself is SIL OFL 1.1, not Apache-2.0.
#import "DSBFont.h"
#import "DSBAssets.h"
#import <CoreText/CoreText.h>

UIFont *DSBSansFont(CGFloat size, CGFloat weight) {
    static NSString *postScriptName;
    static NSMutableDictionary<NSString *, UIFont *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSMutableDictionary new];
        NSURL *url = [NSURL fileURLWithPath:[DSBResourceRoot() stringByAppendingPathComponent:@"fonts/GoogleSansFlex.ttf"]];
        NSArray *descriptors = CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url));
        if (descriptors.count) {
            postScriptName = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)descriptors.firstObject, kCTFontNameAttribute));
            CFErrorRef error = NULL;
            // LineageQS may have registered this same font already. In that
            // case registration can return AlreadyRegistered; the name remains
            // usable. Never unregister a font shared by another tweak.
            CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, &error);
            if (error) CFRelease(error);
        }
    });
    NSString *key = [NSString stringWithFormat:@"%.2f/%.0f", size, weight];
    @synchronized (cache) {
        UIFont *font = cache[key];
        if (font) return font;
        if (postScriptName.length) {
            // As in LineageQS: UIFont descriptors may drop variable axes. Use
            // CoreText for wght and optical size, then bridge the resulting font.
            NSDictionary *axes = @{@(0x77676874): @(weight), @(0x6F70737A): @(MAX(6, MIN(144, size)))};
            CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)@{
                (__bridge NSString *)kCTFontNameAttribute: postScriptName,
                (__bridge NSString *)kCTFontVariationAttribute: axes,
            });
            font = CFBridgingRelease(CTFontCreateWithFontDescriptor(descriptor, size, NULL));
            CFRelease(descriptor);
        }
        if (!font) font = [UIFont systemFontOfSize:size weight:weight >= 700 ? UIFontWeightBold : weight >= 500 ? UIFontWeightMedium : UIFontWeightRegular];
        cache[key] = font;
        return font;
    }
}
