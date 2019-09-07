//
//  StatusItemView.m
//  EFI Agent
//
//  Created by Ben Baker on 6/19/15.
//  Copyright (c) 2015 Headsoft. All rights reserved.
//


#import "StatusItemView.h"

@implementation StatusItemView

- (instancetype) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];

	if(self)
	{
		NSImageView *imageView = [[NSImageView alloc] initWithFrame:frameRect];
		[self addSubview:imageView];
		self.imageView = imageView;
		[imageView release];
	}

	return self;
}

- (void)dealloc
{
	[_image release];
	
	[super dealloc];
}

- (void) setImage:(NSImage*)image
{
	self.imageView.image = image;
}

- (void) mouseDown:(NSEvent*)theEvent
{
	if(self.target != nil && self.action != nil)
	{
		[self.target performSelector:self.action withObject:self];
	}
}

@end
