//
//  LaunchOnStartup.m
//  EFI Agent
//
//  Created by Ben Baker on 10/12/12.
//
//

#import "LaunchOnStartup.h"

@implementation LaunchOnStartup

+ (CFURLRef)appUrl
{
    return (CFURLRef) [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
}

+ (BOOL)isAppLaunchOnStartup
{
	CFURLRef appUrl = [LaunchOnStartup appUrl];
	LSSharedFileListRef loginItemsRefs = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	
	bool isInList = [LaunchOnStartup isLaunchOnStartup:loginItemsRefs forPath:appUrl];

	if (loginItemsRefs != nil)
	{
		CFRelease(loginItemsRefs);
	}
	
	return isInList;
}

+ (BOOL)isLaunchOnStartup:(LSSharedFileListRef)loginItemsRefs forPath:(CFURLRef)path
{
	LSSharedFileListItemRef itemRef = [LaunchOnStartup sharedFileListItemRef:loginItemsRefs forPath:path];
    BOOL isInList = (itemRef != nil);

    if (itemRef != nil)
	{
		CFRelease(itemRef);
	}
	
    return isInList;
}

+ (void)addAppToStartup:(BOOL)addApp
{
	CFURLRef url = [LaunchOnStartup appUrl];
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	
	if (loginItems != nil)
	{
		if (addApp)
			[LaunchOnStartup addToStartup:loginItems forPath:url];
		else
			[LaunchOnStartup removeFromStartup:loginItems forPath:url];
		
		CFRelease(loginItems);
	}
}

+ (void)addToStartup:(LSSharedFileListRef)loginItemsRefs forPath:(CFURLRef)path
{
	LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItemsRefs, kLSSharedFileListItemLast, NULL, NULL, path, NULL, NULL);
	
	if (item != nil)
	{
		CFRelease(item);
	}
}

+ (void)removeFromStartup:(LSSharedFileListRef)loginItemsRefs forPath:(CFURLRef)path
{
	LSSharedFileListItemRef itemRef = [LaunchOnStartup sharedFileListItemRef:loginItemsRefs forPath:path];
	
    if (itemRef != nil)
	{
		LSSharedFileListItemRemove(loginItemsRefs, itemRef);
		
		CFRelease(itemRef);
	}
}

+ (LSSharedFileListItemRef)sharedFileListItemRef:(LSSharedFileListRef)loginItemsRef forPath:(CFURLRef)path
{
	LSSharedFileListItemRef itemRef = nil;
	CFURLRef itemUrl = nil;

    if (loginItemsRef == nil)
		return nil;

    NSArray *loginItems = (NSArray *)LSSharedFileListCopySnapshot(loginItemsRef, nil);

	for (id loginItem in loginItems)
	{
		LSSharedFileListItemRef loginItemRef = (LSSharedFileListItemRef)loginItem;
		
        if (LSSharedFileListItemResolve(loginItemRef, 0, &itemUrl, NULL) == noErr)
		{
            if ([(NSURL *)itemUrl isEqual:(NSURL *)path])
			{
                itemRef = loginItemRef;
            }
        }
    }
	
    if (itemRef != nil)
	{
		CFRetain(itemRef);
	}

    [loginItems release];
	
    return itemRef;
}

@end
