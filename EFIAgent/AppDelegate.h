//
//  AppDelegate.h
//  EFI Agent
//
//  Created by Ben Baker on 6/19/15.
//  Copyright (c) 2015 Headsoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainViewController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
}

@property(strong, nonatomic) NSStatusItem *statusItem;
@property(strong, nonatomic) MainViewController *mainView;

@end

