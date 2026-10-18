// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface DSBRootListController : PSListController
@end
@implementation DSBRootListController
- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}
@end
