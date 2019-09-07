//
//  MainViewController.h
//  EFI Agent
//
//  Created by Ben Baker on 6/19/15.
//  Copyright (c) 2015 Headsoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MainViewController : NSViewController <NSTableViewDataSource, NSMenuDelegate>
{
	NSString *_bootLog;
	
	NSString *_cloverDeviceUUID;
	NSString *_cloverDirPath;
}

@property(strong, nonatomic) NSPopover *popover;
@property(strong, nonatomic) NSMutableArray *disksArray;
@property(retain) NSString *efiBootDeviceUUID;
@property(assign) IBOutlet NSSplitView *splitView;
@property(assign) IBOutlet NSTableView *efiPartitionsTableView;
@property(assign) IBOutlet NSTableView *partitionSchemeTableView;
@property(assign) IBOutlet NSMenuItem *launchAtLoginMenuItem;
@property(assign) IBOutlet NSMenu *mountMenu;

- (void)refreshDisks;
- (void)toggleWindow:(id)sender;
- (IBAction)diskMountButtonClicked:(id)sender;
- (IBAction)diskOpenButtonClicked:(id)sender;
- (IBAction)toggleLaunchAtLogin:(id)sender;
- (IBAction)mountMenuClicked:(id)sender;

@end
