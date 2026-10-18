// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4. Layout follows AOSP SystemUI, adapted for iOS geometry.
#import "DSBStatusBarView.h"
#import "DSBBatteryView.h"
#import "DSBAssets.h"
#import "DSBFont.h"
#import "DSBRecordingChip.h"
#import "DSBRecordingLayout.h"
#import <CoreFoundation/CoreFoundation.h>

static NSString *const Domain = @"dev.drel.droidsb";
static NSDictionary *settings;
static NSHashTable *views;

id DSBRead(id object, NSString *key) {
    if (!object) return nil;
    @try { return [object valueForKey:key]; }
    @catch (__unused NSException *e) { return nil; }
}
static BOOL Flag(NSString *key, BOOL fallback) {
    id value = settings[key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}
BOOL DSBEnabled(void) { return Flag(@"Enabled", YES); }
static BOOL EnabledEntry(id data, NSString *key) { return [DSBRead(DSBRead(data, key), @"enabled") boolValue]; }

static void Reload(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{
        CFPreferencesAppSynchronize((__bridge CFStringRef)Domain);
        CFArrayRef keys = CFPreferencesCopyKeyList((__bridge CFStringRef)Domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        settings = keys ? CFBridgingRelease(CFPreferencesCopyMultiple(keys, (__bridge CFStringRef)Domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)) : @{};
        if (keys) CFRelease(keys);
        for (DSBStatusBarView *view in views) {
            [view refresh];
            [view.nativeBar setNeedsLayout];
        }
    });
}

@implementation DSBStatusBarView {
    UILabel *_clock;
    NSMutableArray<UIImageView *> *_icons;
    DSBBatteryView *_battery;
    NSDateFormatter *_formatter;
    __weak UIView *_suppressed;
    CGFloat _savedAlpha;
    UILabel *_network;
    DSBRecordingChip *_recordingChip;
    NSTimer *_recordingTimer;
    BOOL _recoveryQueued;
    NSUInteger _recoveryAttempts;
}
+ (void)initialize {
    if (self != DSBStatusBarView.class) return;
    views = [NSHashTable weakObjectsHashTable];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, Reload,
        CFSTR("dev.drel.droidsb/preferences-changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    Reload(NULL, NULL, NULL, NULL, NULL);
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.userInteractionEnabled = YES; // hitTest below passes through outside the chip
        self.clipsToBounds = YES;
        _clock = [UILabel new];
        _clock.font = DSBSansFont(13, 500);
        _clock.isAccessibilityElement = YES;
        [self addSubview:_clock];
        _network = [UILabel new];
        _network.font = DSBSansFont(9, 700);
        [self addSubview:_network];
        _icons = [NSMutableArray new];
        for (NSInteger i = 0; i < 10; i++) {
            UIImageView *icon = [UIImageView new];
            icon.contentMode = UIViewContentModeScaleAspectFit;
            [self addSubview:icon];
            [_icons addObject:icon];
        }
        _battery = [DSBBatteryView new];
        [self addSubview:_battery];
        _recordingChip = [DSBRecordingChip new];
        _recordingChip.hidden = YES;
        [_recordingChip addTarget:self action:@selector(recordingTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_recordingChip];
        _formatter = [NSDateFormatter new];
        UIDevice.currentDevice.batteryMonitoringEnabled = YES;
        [views addObject:self];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(captureChanged:)
            name:UIScreenCapturedDidChangeNotification object:nil];
    }
    return self;
}
- (void)restoreNative {
    if (_suppressed) _suppressed.alpha = _savedAlpha;
    _suppressed = nil;
    self.hidden = YES;
    _recordingChip.hidden = YES;
    [_recordingTimer invalidate];
    _recordingTimer = nil;
}
- (void)captureChanged:(NSNotification *)notification {
    __weak DSBStatusBarView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf refresh]; });
}
- (BOOL)recordingChipContainsPoint:(CGPoint)point {
    return !self.hidden && !_recordingChip.hidden && self.alpha > .01
        && CGRectContainsPoint(_recordingChip.frame, point);
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (![self recordingChipContainsPoint:point]) return nil;
    return [_recordingChip hitTest:[self convertPoint:point toView:_recordingChip] withEvent:event];
}
- (void)recordingTapped:(id)sender {
    if (_recordingChip.hidden) return;
    if (DSBPerformRecordingAction(self.nativeBar)) return;
    // If this iOS build doesn't expose the recording item's native action,
    // explain the supported route instead of showing a nonfunctional Stop button.
    UIViewController *presenter = self.window.rootViewController;
    if (!presenter) {
        // A dedicated status-bar window may not have a presenter. Use a visible
        // window in the SAME scene, not an unrelated app/window on another screen.
        for (UIWindow *window in self.window.windowScene.windows) {
            if (window.hidden || window.alpha <= .01 || !window.rootViewController) continue;
            presenter = window.rootViewController;
            if (window.isKeyWindow) break;
        }
    }
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    if (!presenter || [presenter isKindOfClass:UIAlertController.class]) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Screen recording"
        message:@"Stop this recording using the screen recording control in Control Center."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}
- (void)scheduleRecovery {
    if (_recoveryQueued || _recoveryAttempts >= 8 || !self.window) return;
    _recoveryQueued = YES;
    _recoveryAttempts++;
    __weak DSBStatusBarView *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        DSBStatusBarView *view = weakSelf;
        if (!view) return;
        view->_recoveryQueued = NO;
        if (view.window) [view refresh];
    });
}
- (BOOL)refresh {
    UIView *bar = self.nativeBar;
    id data = DSBRead(bar, @"currentAggregatedData") ?: DSBRead(bar, @"currentData");
    UIView *foreground = DSBRead(bar, @"foregroundView");
    BOOL recording = DSBIsScreenRecording(bar, data);
    BOOL assetsReady = DSBIcon(@"ic_wifi_3", 12) && DSBBatteryGlyphs().count;
    // Status entries never switch the bar back to iOS. The network spinner
    // and other unported entries are omitted, not treated as renderer failure.
    if (!DSBEnabled() || !bar || !data || ![foreground isKindOfClass:UIView.class] || !assetsReady) {
        [self restoreNative];
        if (DSBEnabled() && bar && (!data || ![foreground isKindOfClass:UIView.class] || !assetsReady)) [self scheduleRecovery];
        return NO;
    }
    if (_suppressed != foreground) {
        [self restoreNative];
        _suppressed = foreground;
        _savedAlpha = foreground.alpha;
    }
    foreground.alpha = 0; // leave native layout/data and status-bar gestures intact
    self.hidden = NO;
    _recoveryAttempts = 0;
    _clock.font = DSBSansFont(13, 500);
    _network.font = DSBSansFont(9, 700);
    self.frame = bar.bounds;
    if (bar.subviews.lastObject != self) [bar bringSubviewToFront:self];

    UIColor *ink = DSBRead(bar, @"foregroundColor") ?: DSBRead(DSBRead(bar, @"styleAttributes"), @"textColor");
    if (![ink isKindOfClass:UIColor.class]) ink = UIColor.labelColor;
    self.tintColor = ink;
    _clock.textColor = ink;
    _network.textColor = ink;
    CGFloat white = 1, alpha = 1;
    if (![ink getWhite:&white alpha:&alpha]) {
        CGFloat r, g, b;
        if ([ink getRed:&r green:&g blue:&b alpha:&alpha]) white = .2126*r + .7152*g + .0722*b;
    }
    _battery.lightContent = white > .5;
    _formatter.locale = NSLocale.currentLocale;
    _formatter.timeZone = NSTimeZone.localTimeZone;
    if (Flag(@"Use24HourClock", NO)) _formatter.dateFormat = @"HH:mm";
    else [_formatter setLocalizedDateFormatFromTemplate:@"j:mm"];
    // Use the native clock when available: same system update cadence, locale,
    // and accessibility. A user-selected 24h override uses the system date.
    BOOL timeVisible = EnabledEntry(data, @"timeEntry") || EnabledEntry(data, @"shortTimeEntry");
    NSString *nativeTime = DSBRead(DSBRead(data, @"timeEntry"), @"string");
    if (timeVisible) {
        _clock.text = !Flag(@"Use24HourClock", NO) && nativeTime.length ? nativeTime : [_formatter stringFromDate:NSDate.date];
    } else {
        // Cover Sheet suppresses the small native clock because it already has
        // a large clock. Retain its carrier/device label rather than duplicating
        // the time or treating the lock entry as an unsupported activity.
        NSString *carrier = DSBRead(DSBRead(data, @"cellularEntry"), @"string");
        NSString *device = DSBRead(DSBRead(data, @"deviceNameEntry"), @"string");
        _clock.text = carrier.length ? carrier : device;
    }
    _clock.accessibilityLabel = _clock.text;
    _recordingChip.hidden = !recording;
    if (recording) {
        [_recordingChip updateFromEntry:DSBRead(data, @"backgroundActivityEntry")];
        if (!_recordingTimer && self.window) {
            __weak DSBStatusBarView *weakSelf = self;
            _recordingTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(__unused NSTimer *timer) {
                [weakSelf refresh];
            }];
            [NSRunLoop.mainRunLoop addTimer:_recordingTimer forMode:NSRunLoopCommonModes];
        }
    } else {
        [_recordingTimer invalidate];
        _recordingTimer = nil;
    }

    id battery = DSBRead(data, @"mainBatteryEntry");
    NSNumber *capacity = DSBRead(battery, @"capacity");
    _battery.level = capacity ? MAX(0, MIN(100, capacity.integerValue)) : -1;
    // The private entry's state enum is not ABI-stable; use the public device
    // state instead of mistaking an unplugged/unknown battery for charging.
    UIDeviceBatteryState state = UIDevice.currentDevice.batteryState;
    _battery.charging = state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull;
    _battery.powerSave = [DSBRead(battery, @"saverModeActive") boolValue];
    _battery.showPercent = Flag(@"ShowBatteryPercent", YES);
    _battery.accessibilityLabel = _battery.level < 0 ? @"Battery level unknown" : [NSString stringWithFormat:@"Battery %ld percent%@%@", (long)_battery.level, _battery.charging ? @", charging" : @"", _battery.powerSave ? @", low power mode" : @""];
    [_battery setNeedsDisplay];
    _battery.hidden = !EnabledEntry(data, @"mainBatteryEntry");

    NSMutableArray *names = [NSMutableArray new];
    // Android right-side ordering: policy icons, airplane/mobile, Wi-Fi, battery.
    if (EnabledEntry(data, @"lockEntry")) [names addObject:@"ic_device_lock_on"];
    // Android config_statusBarIconsToExclude hides status_bar_rotate by default.
    // No status-entry fallback exists; rotation lock is simply not drawn.
    if (EnabledEntry(data, @"alarmEntry")) [names addObject:@"ic_alarm"];
    if (EnabledEntry(data, @"quietModeEntry")) [names addObject:@"ic_qs_dnd"];
    if (EnabledEntry(data, @"locationEntry")) [names addObject:@"ic_location"];
    if (EnabledEntry(data, @"vpnEntry")) [names addObject:@"stat_sys_vpn_ic"];
    if (EnabledEntry(data, @"bluetoothEntry")) [names addObject:@"ic_bluetooth_connected"];
    BOOL airplane = EnabledEntry(data, @"airplaneModeEntry");
    BOOL wifi = EnabledEntry(data, @"wifiEntry");
    BOOL cellular = !airplane && EnabledEntry(data, @"cellularEntry");
    if (airplane) [names addObject:@"stat_sys_airplane_mode"];
    if (cellular) {
        NSInteger bars = [DSBRead(DSBRead(data, @"cellularEntry"), @"displayValue") integerValue];
        [names addObject:[NSString stringWithFormat:@"ic_mobile_%ld_4_bar", (long)MAX(0, MIN(4, bars))]];
    }
    if (wifi) {
        NSInteger bars = [DSBRead(DSBRead(data, @"wifiEntry"), @"displayValue") integerValue];
        [names addObject:[NSString stringWithFormat:@"ic_wifi_%ld", (long)MAX(0, MIN(3, bars))]];
    }
    for (NSUInteger i = 0; i < _icons.count; i++) {
        _icons[i].hidden = i >= names.count;
        // StatusBarSignalPolicy selects stat_sys_vpn_ic (17dp intrinsic).
        // StatusBarIconView scales its FULL viewport to 15dp, not its path
        // bounds. Updated connectivity icons keep their separate 12sp size.
        CGFloat iconHeight = i < names.count && [names[i] isEqualToString:@"stat_sys_vpn_ic"] ? 15 : 12;
        _icons[i].image = i < names.count ? DSBIcon(names[i], iconHeight) : nil;
        _icons[i].isAccessibilityElement = NO;
        _icons[i].accessibilityLabel = nil;
        if (i < names.count && [names[i] isEqualToString:@"ic_bluetooth_connected"]) {
            // AirPods accessory capacity is nested in bluetoothEntry, not the
            // phone battery. Handle it without overwriting the phone gauge or
            // depending on Apple's private Bluetooth state enum.
            id accessory = DSBRead(DSBRead(data, @"bluetoothEntry"), @"batteryEntry");
            NSNumber *level = DSBRead(accessory, @"capacity");
            BOOL known = [DSBRead(accessory, @"enabled") boolValue] && level && level.integerValue >= 0 && level.integerValue <= 100;
            _icons[i].isAccessibilityElement = YES;
            _icons[i].accessibilityLabel = known
                ? [NSString stringWithFormat:@"Bluetooth, accessory battery %ld percent", (long)level.integerValue]
                : @"Bluetooth";
        }
    }
    // Do not guess Apple's numeric RAT enum. Native string/badge may contain
    // actual carrier text; display only explicitly recognizable technology.
    NSString *badge = DSBRead(DSBRead(data, @"cellularEntry"), @"badgeString");
    NSSet *types = [NSSet setWithArray:@[@"G", @"E", @"3G", @"4G", @"LTE", @"5G", @"5G+", @"5G E"]];
    _network.text = cellular && !wifi && [types containsObject:badge ?: @""] ? badge : @"";
    [self setNeedsLayout];
    return YES;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width, height = self.bounds.size.height;
    if (height < 1 || width < 1) return;
    // On the SE this is 20pt. On notched phones, keep clear of the central
    // cutout and use the native safe-area side insets in landscape.
    UIEdgeInsets safe = self.nativeBar.window.safeAreaInsets;
    CGFloat left = MAX(7, safe.left), right = width - MAX(7, safe.right);
    CGFloat center = height > 24 ? height - 14 : height / 2;
    if (!_battery.hidden) {
        CGFloat bw = _battery.charging || _battery.powerSave ? 31 : 27;
        _battery.frame = CGRectMake(right - bw, center - 6.5, 31, 13);
        right -= bw + 5;
    }
    for (UIImageView *icon in _icons.reverseObjectEnumerator) {
        if (icon.hidden) continue;
        CGFloat iw = icon.image.size.width;
        CGFloat ih = icon.image.size.height;
        icon.frame = CGRectMake(right - iw, center - ih / 2, iw, ih);
        right -= iw + 4;
    }
    CGSize ns = [_network sizeThatFits:CGSizeMake(40, 14)];
    _network.frame = CGRectMake(right - ns.width, center - 6, ns.width, 12);
    if (_network.text.length) right -= ns.width + 3;
    CGFloat maxClock = width > 350 && height > 24 ? width * .35 - left : right - left - 12;
    _clock.frame = CGRectMake(left, center - 8, MAX(0, MIN(100, maxClock)), 16);
    if (!_recordingChip.hidden) {
        CGFloat h = MIN(24, MAX(0, height - 2));
        CGSize desired = [_recordingChip sizeThatFits:CGSizeMake(100, h)];
        CGFloat room = MAX(0, right - left - 5);
        DSBRecordingLayout layout = DSBLayoutRecording(room,
            [_clock sizeThatFits:CGSizeMake(100, 16)].width, desired.width,
            [_recordingChip minimumWidthForHeight:h]);
        CGFloat chipWidth = layout.chipWidth, clockWidth = layout.clockWidth;
        _clock.frame = CGRectMake(left, center - 8, clockWidth, 16);
        CGFloat chipX = left + clockWidth + (clockWidth > 0 ? 5 : 0);
        _recordingChip.frame = CGRectMake(chipX, center - h/2, chipWidth, h);
    }
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) [self restoreNative];
}
- (void)dealloc {
    [_recordingTimer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
@end
