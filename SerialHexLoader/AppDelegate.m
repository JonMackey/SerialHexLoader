//
/*******************************************************************************
	License
	****************************************************************************
	This program is free software; you can redistribute it
	and/or modify it under the terms of the GNU General
	Public License as published by the Free Software
	Foundation; either version 3 of the License, or
	(at your option) any later version.
 
	This program is distributed in the hope that it will
	be useful, but WITHOUT ANY WARRANTY; without even the
	implied warranty of MERCHANTABILITY or FITNESS FOR A
	PARTICULAR PURPOSE. See the GNU General Public
	License for more details.
 
	Licence can be viewed at
	http://www.gnu.org/licenses/gpl-3.0.txt

	Please maintain this license information along with authorship
	and copyright notices in any redistribution of this code
*******************************************************************************/
/*
*	AppDelegate
*	
*	Created by Jon Mackey on 5/9/19.
*	Copyright © 2019 Jon Mackey. All rights reserved.
*/


#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

/*********************** applicationDidFinishLaunching ************************/
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSDictionary*	defaults = [NSDictionary dictionaryWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"defaults" withExtension:@"plist"]];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

	self.preferencesWindowController = [PreferencesWindowController alloc];
	[self.preferencesWindowController initWithWindowNibName:@"PreferencesWindowController"];

	self.serialHexWindowController = [SerialHexWindowController alloc];
	[[self.serialHexWindowController initWithWindowNibName:@"SerialHexWindowController"].window makeKeyAndOrderFront:nil];
}

/********************************** openURLs **********************************/
- (void)application:(NSApplication *)inApplication openURLs:(NSArray<NSURL *> *)inUrls
{
	if (inUrls.count == 1)
	{
		[_serialHexWindowController doOpen:inUrls[0]];
	}
}


/************************** applicationWillTerminate **************************/
- (void)applicationWillTerminate:(NSNotification *)aNotification
{

}

/****************************** showPreferences *******************************/
- (IBAction)showPreferences:(id)sender
{
	[self.preferencesWindowController.window makeKeyAndOrderFront: sender];
}

@end
