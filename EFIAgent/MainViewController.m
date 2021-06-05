//
//  MainViewController.m
//  EFI Agent
//
//  Created by Ben Baker on 6/19/15.
//  Copyright (c) 2015 Headsoft. All rights reserved.
//

#import "MainViewController.h"
#import "IORegTools.h"
#import "NVRAMXmlParser.h"
#import "DiskUtilities.h"
#import "Disk.h"
#import "MiscTools.h"
#import "LaunchOnStartup.h"
#import "BarTableRowView.h"
extern "C" {
#include "efidevp.h"
}

@implementation MainViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	_splitView.autosaveName = @"SplitView";
	
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
	
	[self getBootLog];
	
	//[self resetDefaults];
	[self setDefaults];
	[self loadSettings];
	
	[self getEfiBootDevice];
	
	self.disksArray = [NSMutableArray array];
	
	registerDiskCallbacks(self);
}

- (void)dealloc
{
	if (_popover != nil)
		[_popover release];
	
	[_bootLog release];
	[_efiBootDeviceUUID release];
	[_disksArray release];
	[_cloverDeviceUUID release];
	[_cloverDirPath release];
	
	[super dealloc];
}

- (NSApplicationTerminateReply)applicationWillTerminate:(NSApplication *)sender
{
	[self saveSettings];
	
	return NSTerminateNow;
}

- (void) toggleWindow:(id)sender
{
	if(!self.popover.shown)
		[self showPopover:sender];
	else
		[self closePopover];
}

- (void) showPopover:(id)sender
{
	NSRect aRect = [sender bounds];
	[self.popover showRelativeToRect:aRect ofView:sender preferredEdge:NSMaxYEdge];
}

- (void) closePopover
{
	[self.popover performClose:self];
}

- (NSPopover *) popover
{
	if (_popover == nil)
	{
		_popover = [[NSPopover alloc] init];
		_popover.contentViewController = self;
		_popover.behavior = NSPopoverBehaviorTransient;
		_popover.animates = YES;
	}
	
	return _popover;
}

- (void)refreshDisks
{
	[_efiPartitionsTableView reloadData];
	[_partitionSchemeTableView reloadData];
}

- (bool)getEfiBootDevice
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSString *efiBootDeviceUUID = [defaults objectForKey:@"EFIBootDeviceUUID"];
	
	if (efiBootDeviceUUID)
	{
		[self setEfiBootDeviceUUID:efiBootDeviceUUID];
		
		return true;
	}
	
	if (_bootLog != nil)
	{
		// 0:100  0:000  SelfDevicePath=PciRoot(0x0)\Pci(0x1F,0x2)\Sata(0x0,0xFFFF,0x0)\HD(1,GPT,0FBD5BD2-AE6A-4F30-BDD6-F8ABABD7E795,0x28,0x64000) @B259DB98
		// 0:100  0:000  SelfDirPath = \EFI\BOOT
		
		NSArray *bootArray = [_bootLog componentsSeparatedByString:@"\r"];
		
		for (NSString *bootLine in bootArray)
		{
			NSRange selfDevicePathRange = [bootLine rangeOfString:@"SelfDevicePath="];
			NSRange selfDirPathRange = [bootLine rangeOfString:@"SelfDirPath = "];
			
			if (selfDevicePathRange.location != NSNotFound)
			{
				NSMutableArray *itemArray = nil;
				
				if (getRegExArray(@"HD\\((.*),(.*),(.*),(.*),(.*)\\)", bootLine, 5, &itemArray))
				{
					NSString *uuid = itemArray[2];
					
					_cloverDeviceUUID = [uuid retain];
					
					[self setEfiBootDeviceUUID:uuid];
				}
			}
			
			if (selfDirPathRange.location != NSNotFound)
				_cloverDirPath = [[[bootLine substringFromIndex:selfDirPathRange.location + selfDirPathRange.length] stringByReplacingOccurrencesOfString:@"\\" withString:@"/"] retain];
		}
	}
	
	NSMutableDictionary *nvramDictionary;
	
	if (getIORegProperties(@"IODeviceTree:/options", &nvramDictionary))
	{
		id efiBootDevice = [nvramDictionary objectForKey:@"efi-boot-device"];
		
		if (efiBootDevice != nil)
		{
			NSString *efiBootDeviceString = ([efiBootDevice isKindOfClass:[NSData class]] ? [NSString stringWithCString:(const char *)[efiBootDevice bytes] encoding:NSASCIIStringEncoding] : efiBootDevice);
			NVRAMXmlParser *nvramXmlParser = [NVRAMXmlParser initWithString:efiBootDeviceString encoding:NSASCIIStringEncoding];
			NSString *uuid = [nvramXmlParser getValue:@[@0, @"IOMatch", @"IOPropertyMatch", @"UUID"]];
			[self setEfiBootDeviceUUID:uuid];
			
			return true;
		}
	}

	NSMutableDictionary *chosenDictionary;
	
	if (getIORegProperties(@"IODeviceTree:/chosen", &chosenDictionary))
	{
		NSData *bootDevicePathData = [chosenDictionary objectForKey:@"boot-device-path"];
		
		if (bootDevicePathData != nil)
		{
			const unsigned char *bootDeviceBytes = (const unsigned char *)bootDevicePathData.bytes;
			CHAR8 *devicePath = ConvertHDDDevicePathToText((const EFI_DEVICE_PATH *)bootDeviceBytes);
			NSString *devicePathString = [NSString stringWithUTF8String:devicePath];
			[self setEfiBootDeviceUUID:devicePathString];
			
			return true;
		}
	}
	
	return false;
}

- (NSString *)getToolTip:(NSTableView *)tableView tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if (tableView == _efiPartitionsTableView)
	{
		NSMutableArray *efiPartitionsArray = getEfiPartitionsArray(_disksArray);
		Disk *disk = efiPartitionsArray[row];
		
		if([[tableColumn identifier] isEqualToString:@"Mount"])
			return (disk.isMounted ? @"Unmount" : @"Mount");
		else if([[tableColumn identifier] isEqualToString:@"Open"])
			return (disk.isMounted ? @"Open" : nil);
	}
	else if (tableView == _partitionSchemeTableView)
	{
	}
	
	return nil;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	if (tableView == _efiPartitionsTableView)
	{
	}
	else if (tableView == _partitionSchemeTableView)
	{
		Disk *disk = _disksArray[row];
		NSNumber *blockSize, *totalSize, *volumeTotalSize, *volumeFreeSpace;
		
		if ([disk sizeInfo:&blockSize totalSize:&totalSize volumeTotalSize:&volumeTotalSize volumeFreeSpace:&volumeFreeSpace])
		//if ([disk sizeInfo:&volumeTotalSize freeSize:&volumeFreeSpace])
		{
			if (volumeTotalSize != nil && volumeFreeSpace != nil)
			{
				double percent = 1.0 - ([volumeFreeSpace doubleValue] / [volumeTotalSize doubleValue]);
				NSColor *color = [NSColor colorWithRed:(50.0 / 255.0) green:(175.0 / 255.0) blue:(246.0 / 255.0) alpha:(102.0 / 255.0)];
				BarTableRowView *barTableRowView = [[BarTableRowView alloc] initWithPercent:percent column:3 color:color inset:NSMakeSize(0, 0) radius:0 stroke:NO];
				[barTableRowView autorelease];
				return barTableRowView;
			}
		}
	}
	
	return nil;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
	
	if (tableView == _efiPartitionsTableView)
	{
		NSMutableArray *efiPartitionsArray = getEfiPartitionsArray(_disksArray);
		Disk *disk = efiPartitionsArray[row];
		
		if([[tableColumn identifier] isEqualToString:@"Icon"])
			[((NSImageView *)result) setImage:disk.icon];
		else if([[tableColumn identifier] isEqualToString:@"DeviceName"])
			result.textField.stringValue = getDeviceName(_disksArray, disk.disk);
		else if([[tableColumn identifier] isEqualToString:@"VolumeName"])
			result.textField.stringValue = (disk.volumeName != nil ? disk.volumeName : @"");
		else if([[tableColumn identifier] isEqualToString:@"BSDName"])
			result.textField.stringValue = (disk.mediaBSDName != nil ? disk.mediaBSDName : @"");
		else if([[tableColumn identifier] isEqualToString:@"MountPoint"])
			result.textField.stringValue = (disk.volumePath != nil ? [disk.volumePath path] : @"");
		else if([[tableColumn identifier] isEqualToString:@"Mount"])
			((NSButton *)result).image = [NSImage imageNamed:(disk.isMounted ? @"IconUnmount" : @"IconMount")];
		else if([[tableColumn identifier] isEqualToString:@"Open"])
			((NSButton *)result).enabled = disk.isMounted;
	}
	else if (tableView == _partitionSchemeTableView)
	{
		Disk *disk = _disksArray[row];
		
		if([[tableColumn identifier] isEqualToString:@"Icon"])
			((NSImageView *)result).image = disk.icon;
		else if([[tableColumn identifier] isEqualToString:@"VolumeName"])
		{
			if (disk.isAPFS || disk.isAPFSContainer)
				result.textField.stringValue = [NSString stringWithFormat:@"🔗 %@", disk.apfsBSDNameLink];
			else if (disk.isDisk)
				result.textField.stringValue = getDeviceName(_disksArray, disk.disk);
			else
				result.textField.stringValue = (disk.volumeName != nil ? disk.volumeName : @"");
		}
		else if([[tableColumn identifier] isEqualToString:@"BSDName"])
			result.textField.stringValue = (disk.mediaBSDName != nil ? disk.mediaBSDName : @"");
		else if([[tableColumn identifier] isEqualToString:@"MountPoint"])
			result.textField.stringValue = (disk.volumePath != nil ? [disk.volumePath path] : @"");
		else if([[tableColumn identifier] isEqualToString:@"DiskType"])
			result.textField.stringValue = disk.type;
	}
	
	NSString *toolTip = [self getToolTip:tableView tableColumn:tableColumn row:row];
	
	if (toolTip != nil)
		[result setToolTip:toolTip];
	else if ([result isKindOfClass:[NSTableCellView class]])
		[result setToolTip:result.textField.stringValue];
	
	return result;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	if (tableView == _efiPartitionsTableView)
	{
		NSMutableArray *efiPartitionsArray = getEfiPartitionsArray(_disksArray);
		Disk *disk = efiPartitionsArray[row];
		
		[rowView setBackgroundColor:disk.isBootableEFI ? getColorAlpha([NSColor systemGreenColor], 0.3f) : getColorAlpha([NSColor controlBackgroundColor], 0.0f)];
	}
	else if (tableView == _partitionSchemeTableView)
	{
		Disk *disk = _disksArray[row];
		
		[rowView setBackgroundColor:[disk color:0.3f]];
	}
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell1 forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if (tableView == _efiPartitionsTableView)
	{
		NSMutableArray *efiPartitionsArray = getEfiPartitionsArray(_disksArray);
		Disk *disk = efiPartitionsArray[row];
		
		[cell1 setBackgroundColor:disk.isBootableEFI ? getColorAlpha([NSColor systemGreenColor], 0.3f) : getColorAlpha([NSColor controlBackgroundColor], 0.0f)];
	}
	else if (tableView == _partitionSchemeTableView)
	{
		Disk *disk = _disksArray[row];
		
		[cell1 setBackgroundColor:[disk color:0.3f]];
	}
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if (tableView == _efiPartitionsTableView)
	{
		NSMutableArray *efiPartitionsArray = getEfiPartitionsArray(_disksArray);
		
		return [efiPartitionsArray count];
	}
	else if (tableView == _partitionSchemeTableView)
	{
		return [_disksArray count];
	}
	
	return 0;
}

- (IBAction)diskMountButtonClicked:(id)sender
{
	NSButton *button = (NSButton *)sender;
	NSInteger row = [_efiPartitionsTableView rowForView:button];
	
	if (row == -1)
		return;
	
	NSMutableArray *efiPartitionsArray = getEfiPartitionsArray(_disksArray);
	Disk *disk = efiPartitionsArray[row];
	NSString *stdoutString = nil, *stderrString = nil;
	
	if (disk.isMounted)
	{
		if ([disk unmount:&stdoutString stderrString:&stderrString])
			sendNotificationTitle(self, [NSString stringWithFormat:@"Unmount %@", disk.mediaBSDName], trimNewLine(![stderrString isEqualToString:@""] ? stderrString : stdoutString), nil, nil, nil, NO);
	}
	else
	{
		if ([disk mount:&stdoutString stderrString:&stderrString])
			sendNotificationTitle(self, [NSString stringWithFormat:@"Mount %@", disk.mediaBSDName], trimNewLine(![stderrString isEqualToString:@""] ? stderrString : stdoutString), nil, nil, nil, NO);
	}
}

- (IBAction)diskOpenButtonClicked:(id)sender
{
	NSButton *button = (NSButton *)sender;
	NSInteger row = [_efiPartitionsTableView rowForView:button];
	
	if (row == -1)
		return;
	
	NSMutableArray *efiPartitionsArray = getEfiPartitionsArray(_disksArray);
	Disk *disk = efiPartitionsArray[row];

	[self open:disk];
}

- (IBAction)toggleLaunchAtLogin:(id)sender
{
	NSMenuItem *menuItem = (NSMenuItem *)sender;
	
	[menuItem setState:!menuItem.state];
	
	[LaunchOnStartup addAppToStartup:menuItem.state];
}

- (IBAction)mountMenuClicked:(id)sender
{
	NSMenuItem *menuItem = (NSMenuItem *)sender;
	NSInteger row = _partitionSchemeTableView.clickedRow;
	
	if (row == -1)
		return;

	if ([menuItem.identifier isEqualToString:@"Mount"])
	{
		Disk *disk = _disksArray[row];
		NSString *stdoutString = nil, *stderrString = nil;
		
		if (disk.isMounted)
		{
			if ([disk unmount:&stdoutString stderrString:&stderrString])
				sendNotificationTitle(self, [NSString stringWithFormat:@"Unmount %@", disk.mediaBSDName], trimNewLine(![stderrString isEqualToString:@""] ? stderrString : stdoutString), nil, nil, nil, NO);
		}
		else
		{
			if ([disk mount:&stdoutString stderrString:&stderrString])
				sendNotificationTitle(self, [NSString stringWithFormat:@"Mount %@", disk.mediaBSDName], trimNewLine(![stderrString isEqualToString:@""] ? stderrString : stdoutString), nil, nil, nil, NO);
		}
	}
	else if ([menuItem.identifier isEqualToString:@"Eject"])
	{
		Disk *disk = _disksArray[row];
		NSString *stdoutString = nil, *stderrString = nil;
		
		if ([disk eject:&stdoutString stderrString:&stderrString])
			sendNotificationTitle(self, [NSString stringWithFormat:@"Eject %@", disk.mediaBSDName], trimNewLine(![stderrString isEqualToString:@""] ? stderrString : stdoutString), nil, nil, nil, NO);
	}
	else if ([menuItem.identifier isEqualToString:@"Open"])
	{
		Disk *disk = _disksArray[row];
		
		[self open:disk];
	}
	else if ([menuItem.identifier isEqualToString:@"DeleteAPFSContainer"])
	{
		Disk *disk = _disksArray[row];
		NSString *stdoutString = nil, *stderrString = nil;
		
		if ([disk deleteAPFSContainer:&stdoutString stderrString:&stderrString])
			sendNotificationTitle(self, [NSString stringWithFormat:@"Delete APFS Container (%@)", disk.mediaBSDName], trimNewLine(![stderrString isEqualToString:@""] ? stderrString : stdoutString), nil, nil, nil, NO);
	}
	else if ([menuItem.identifier isEqualToString:@"ConvertToAPFS"])
	{
		Disk *disk = _disksArray[row];
		NSString *stdoutString = nil, *stderrString = nil;
		
		if ([disk convertToAPFS:&stdoutString stderrString:&stderrString])
			sendNotificationTitle(self, [NSString stringWithFormat:@"Convert to APFS (%@)", disk.mediaBSDName], trimNewLine(![stderrString isEqualToString:@""] ? stderrString : stdoutString), nil, nil, nil, NO);
	}
	else if ([menuItem.identifier isEqualToString:@"VolumeUUID"])
	{
		Disk *disk = _disksArray[row];
		
		[[NSPasteboard generalPasteboard] clearContents];
		[[NSPasteboard generalPasteboard] setString:disk.volumeUUID forType:NSStringPboardType];
	}
	else if ([menuItem.identifier isEqualToString:@"VolumePath"])
	{
		Disk *disk = _disksArray[row];
		
		[[NSPasteboard generalPasteboard] clearContents];
		[[NSPasteboard generalPasteboard] setString:(disk.volumePath != nil ? [disk.volumePath path] : @"") forType:NSStringPboardType];
	}
	else if ([menuItem.identifier isEqualToString:@"MediaUUID"])
	{
		Disk *disk = _disksArray[row];
		
		[[NSPasteboard generalPasteboard] clearContents];
		[[NSPasteboard generalPasteboard] setString:disk.mediaUUID forType:NSStringPboardType];
	}
	else if ([menuItem.identifier isEqualToString:@"BootEFI"])
	{
		Disk *disk = _disksArray[row];
		
		menuItem.state = !menuItem.state;
		
		if (menuItem.state)
			[self setBootEFI:disk.mediaUUID];
		else
			[self unsetBootEFI];
		
		[self getEfiBootDevice];
		
		updateDiskList(_disksArray, _efiBootDeviceUUID);
		
		[self refreshDisks];
	}
}

- (void)setBootEFI:(NSString *)mediaUUID
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setObject:mediaUUID forKey:@"EFIBootDeviceUUID"];
	
	[defaults synchronize];
}

- (void)unsetBootEFI
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults removeObjectForKey:@"EFIBootDeviceUUID"];
	
	[defaults synchronize];
}

- (void)resetDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *dictionary = [defaults dictionaryRepresentation];
	
	for (id key in dictionary)
		[defaults removeObjectForKey:key];
	
	[defaults synchronize];
}

- (void)setDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *defaultsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
										@NO, @"LaunchAtLogin",
										nil];
	
	[defaults registerDefaults:defaultsDictionary];
	[defaults synchronize];
}

- (void)loadSettings
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	_launchAtLoginMenuItem.state = [defaults boolForKey:@"LaunchAtLogin"];
}

- (void)saveSettings
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setBool:_launchAtLoginMenuItem.state forKey:@"LaunchAtLogin"];
	
	[defaults synchronize];
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
	if ([menu.identifier isEqualToString:@"Mount"])
		return 6;
	else if ([menu.identifier isEqualToString:@"Tools"])
		return 2;
	else if ([menu.identifier isEqualToString:@"CopyToClipboard"])
		return 3;
	
	return 0;
}

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
	NSInteger row = _partitionSchemeTableView.clickedRow;
	
	if (row == -1)
	{
		[menu cancelTrackingWithoutAnimation];
		
		return NO;
	}
	
	Disk *disk = _disksArray[row];
	
	if ([menu.identifier isEqualToString:@"Mount"])
	{
		if ([item.identifier isEqualToString:@"Mount"])
			item.title = (disk.isMounted ? @"Unmount" : @"Mount");
		else if ([item.identifier isEqualToString:@"Eject"])
			item.enabled = (disk.isEjectable && !disk.isInternal);
		else if ([item.identifier isEqualToString:@"Open"])
			item.enabled = disk.isMounted;
		else if ([item.identifier isEqualToString:@"BootEFI"])
		{
			item.enabled = disk.isEFI;
			item.state = disk.isBootableEFI;
		}
	}
	else if ([menu.identifier isEqualToString:@"Tools"])
	{
		if ([item.identifier isEqualToString:@"DeleteAPFSContainer"])
			item.enabled = disk.isAPFSContainer;
		else if ([item.identifier isEqualToString:@"ConvertToAPFS"])
			item.enabled = disk.isHFS;
	}
	
	return YES;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
	return 80.0;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return 512.0;
}

- (void)open:(Disk *)disk
{
	if (disk.volumePath == nil)
		return;
	
	NSArray *fileURLs = [NSArray arrayWithObjects:disk.volumePath, nil];
	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}

- (void)getBootLog
{
	CFTypeRef property = nil;
	
	// IOService:/boot-log
	// IODeviceTree:/efi/platform
	
	if (!getIORegProperty(@"IOService:/", @"boot-log", &property))
		if (!getIORegProperty(@"IODeviceTree:/efi/platform", @"boot-log", &property))
			return;
	
	NSData *valueData = (__bridge NSData *)property;
	_bootLog = [[NSString alloc] initWithData:valueData encoding:NSASCIIStringEncoding];
	
	if (property != nil)
		CFRelease(property);
}

@end
