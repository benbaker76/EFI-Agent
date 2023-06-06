//
//  AppDelegate.m
//  EFI Agent
//
//  Created by Ben Baker on 6/19/15.
//  Copyright (c) 2015 Headsoft. All rights reserved.
//


#import "AppDelegate.h"

@implementation AppDelegate

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification
{
	// Create our main view.
	_mainView = [[MainViewController alloc] initWithNibName:@"MainView" bundle:nil];
	
	NSStatusBar *systemStatusBar = [NSStatusBar systemStatusBar];
	
	// Create the NSStatusItem.
	self.statusItem = [systemStatusBar statusItemWithLength:NSSquareStatusItemLength];

	NSImage *image = [NSImage imageNamed:@"IconStatusBar"];
	[image setTemplate:YES];
	[image setSize:NSMakeSize(systemStatusBar.thickness, systemStatusBar.thickness)];
	[self.statusItem setImage:image];
	[self.statusItem setTarget:_mainView];
	[self.statusItem setAction:@selector(toggleWindow:)];
}

- (void)dealloc
{
	[_mainView release];
	[_statusItem release];
	
	[super dealloc];
}

@end
