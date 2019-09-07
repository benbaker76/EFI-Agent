//
//  AppDelegate.m
//  EFI Agent
//
//  Created by Ben Baker on 6/19/15.
//  Copyright (c) 2015 Headsoft. All rights reserved.
//


#import "AppDelegate.h"
#import "StatusItemView.h"

@implementation AppDelegate

- (void) applicationDidFinishLaunching:(NSNotification*)aNotification
{
	// Create the NSStatusItem.
	CGFloat width = 24.0;
	CGFloat height = [NSStatusBar systemStatusBar].thickness;
	NSRect viewFrame = NSMakeRect(0, 0, width, height);
	self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	StatusItemView *statusItemView = [[StatusItemView alloc] initWithFrame:viewFrame];
	[self.statusItem setView:statusItemView];
	NSImage *image = [NSImage imageNamed:@"IconStatusBar"];
	[image setTemplate:YES];
	[((StatusItemView *)self.statusItem.view) setImage:image];
	
	// Create our main view.
	_mainView = [[MainViewController alloc] initWithNibName:@"MainView" bundle:nil];
	
	// Hook up status item to main view.
	[statusItemView setTarget:_mainView];
	[statusItemView setAction:@selector(toggleWindow:)];
}

- (void)dealloc
{
	[_mainView release];
	[_statusItem release];
	
	[super dealloc];
}

@end
