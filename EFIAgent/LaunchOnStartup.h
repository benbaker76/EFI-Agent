//
//  LaunchOnStartup.h
//  EFI Agent
//
//  Created by Ben Baker on 10/12/12.
//
//

#import <Foundation/Foundation.h>

@interface LaunchOnStartup : NSObject

+ (CFURLRef)appUrl;
+ (BOOL)isAppLaunchOnStartup;
+ (BOOL)isLaunchOnStartup:(LSSharedFileListRef)loginItemsRefs forPath:(CFURLRef)path;
+ (void)addAppToStartup:(BOOL)addApp;
+ (void)addToStartup:(LSSharedFileListRef)loginItemsRefs forPath:(CFURLRef)path;
+ (void)removeFromStartup:(LSSharedFileListRef)loginItemsRefs forPath:(CFURLRef)path;
+ (LSSharedFileListItemRef)sharedFileListItemRef:(LSSharedFileListRef)loginItemsRef forPath:(CFURLRef)path;

@end
