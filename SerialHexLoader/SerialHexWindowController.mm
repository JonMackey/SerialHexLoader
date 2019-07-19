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
*	SerialHexWindowController
*	
*	Created by Jon Mackey on 5/9/19.
*	Copyright © 2019 Jon Mackey. All rights reserved.
*/


#import "SerialHexWindowController.h"


@interface SerialHexWindowController ()

@end

@implementation SerialHexWindowController
// SANDBOX_ENABLED is defined in GCC_PREPROCESSOR_DEFINITIONS
#if SANDBOX_ENABLED
NSString *const kBinaryURLBMKey = @"binaryURLBM";
#else
NSString *const kBinaryPathKey = @"binaryPath";
#endif

struct SMenuItemDesc
{
	NSInteger	mainMenuTag;
	NSInteger	subMenuTag;
    SEL action;
};

SMenuItemDesc	menuItems[] = {
	{1,10, @selector(open:)},
	{1,15, @selector(exportBinary:)}
};

/******************************* windowDidLoad ********************************/
- (void)windowDidLoad
{
	[super windowDidLoad];
	{
		const SMenuItemDesc*	miDesc = menuItems;
		const SMenuItemDesc*	miDescEnd = &menuItems[sizeof(menuItems)/sizeof(SMenuItemDesc)];
		for (; miDesc < miDescEnd; miDesc++)
		{
			NSMenuItem *menuItem = [[[NSApplication sharedApplication].mainMenu itemWithTag:miDesc->mainMenuTag].submenu itemWithTag:miDesc->subMenuTag];
			if (menuItem)
			{
				// Assign this object as the target.
				menuItem.target = self;
				menuItem.action = miDesc->action;
			}
		}
	}
	
	if (self.serialHexViewController == nil)
	{
		_serialHexViewController = [[SerialHexViewController alloc] initWithNibName:@"SerialHexViewController" bundle:nil];
		// embed the current view to our host view
		[serialView addSubview:[self.serialHexViewController view]];
		
		// make sure we automatically resize the controller's view to the current window size
		[[self.serialHexViewController view] setFrame:[serialView bounds]];
	}
}

/****************************** validateMenuItem ******************************/
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	BOOL	isValid = YES;
	switch (menuItem.tag)
	{
		case 15:	// Export…
		{
			isValid = [_serialHexViewController binaryPathIsValid];
			break;
		}
	}
	return(isValid);
}

/********************************** open **************************************/
- (IBAction)open:(id)sender
{
	NSURL*	baseURL = NULL;
#if SANDBOX_ENABLED
	NSData* binaryURLBM = [[NSUserDefaults standardUserDefaults] objectForKey:kBinaryURLBMKey];
	if (binaryURLBM)
	{
		baseURL = [NSURL URLByResolvingBookmarkData:
	 					binaryURLBM
	 						options:NSURLBookmarkResolutionWithoutUI+NSURLBookmarkResolutionWithoutMounting+NSURLBookmarkResolutionWithSecurityScope
	 							relativeToURL:NULL bookmarkDataIsStale:NULL error:NULL];
		baseURL = [NSURL fileURLWithPath:[[baseURL path] stringByDeletingLastPathComponent] isDirectory:YES];
	}
#else
	NSString* binaryPath = [[NSUserDefaults standardUserDefaults] objectForKey:kBinaryPathKey];
	baseURL = binaryPath ? [NSURL fileURLWithPath:[binaryPath stringByDeletingLastPathComponent] isDirectory:YES] : nil;
#endif
	NSOpenPanel*	openPanel = [NSOpenPanel openPanel];
	if (openPanel)
	{
		[openPanel setCanChooseDirectories:NO];
		[openPanel setCanChooseFiles:YES];
		[openPanel setAllowsMultipleSelection:NO];
		openPanel.directoryURL = baseURL;
		[openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result)
		{
			if (result == NSModalResponseOK)
			{
				NSArray* urls = [openPanel URLs];
				if ([urls count] == 1)
				{
					[self doOpen:urls[0]];
				}
			}
		}];
	}
}

/********************************* doOpen *************************************/
- (void)doOpen:(NSURL*)inDocURL
{
	if ([_serialHexViewController assignBinaryURL:inDocURL])
	{
		[self newRecentSetDoc:inDocURL];
	}
}

/****************************** newRecentSetDoc *******************************/
- (void)newRecentSetDoc:(NSURL*)inDocURL
 {
#if SANDBOX_ENABLED
	NSError*	error;
	NSData* binaryURLBM = [inDocURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
			includingResourceValuesForKeys:NULL relativeToURL:NULL error:&error];
	[[NSUserDefaults standardUserDefaults] setObject:binaryURLBM forKey:kBinaryURLBMKey];
#else
	[[NSUserDefaults standardUserDefaults] setObject:inDocURL.path forKey:kBinaryPathKey];
#endif
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:inDocURL];
	[self.window setTitle:[inDocURL.path lastPathComponent]];
}

/********************************* showHelp ***********************************/
- (IBAction)showHelp:(id)sender
{
	// Place help instructions...
	NSURL*	openingInstructionsTextURL = [[NSBundle mainBundle] URLForResource:@"OpeningInstructions" withExtension:@"rtf"];
	NSData* rtfData = [NSData dataWithContentsOfURL:openingInstructionsTextURL];
	NSAttributedString* openingInstructions = [[NSAttributedString alloc] initWithRTF:rtfData documentAttributes:nil];
	[_serialHexViewController.logText appendAttributedString:openingInstructions];
	[_serialHexViewController postWithoutScroll];
}

/******************************** exportBinary ********************************/
- (IBAction)exportBinary:(id)sender
{
#if SANDBOX_ENABLED
	NSData* binaryURLBM = [[NSUserDefaults standardUserDefaults] objectForKey:kBinaryURLBMKey];
	NSURL*	docURL = [NSURL URLByResolvingBookmarkData:
						binaryURLBM
							options:NSURLBookmarkResolutionWithoutUI+NSURLBookmarkResolutionWithoutMounting+NSURLBookmarkResolutionWithSecurityScope
								relativeToURL:NULL bookmarkDataIsStale:NULL error:NULL];
#else
	NSString* binaryPath = [[NSUserDefaults standardUserDefaults] objectForKey:kBinaryPathKey];
	NSURL*	docURL = binaryPath ? [NSURL fileURLWithPath:binaryPath isDirectory:NO] : nil;
#endif
	NSURL*	baseURL = docURL ? [NSURL fileURLWithPath:[docURL.path stringByDeletingLastPathComponent] isDirectory:YES] : nil;
	NSString*	initialName = docURL ? [[[docURL path] lastPathComponent] stringByDeletingPathExtension] : @"Untitled";

	_savePanel = [NSSavePanel savePanel];
	if (_savePanel)
	{
		_savePanel.directoryURL = baseURL;
		
		__block NSURL* exportURL = nil;
		_savePanel.allowedFileTypes = @[@"hex"];
		_savePanel.nameFieldStringValue = initialName;
		[_savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result)
		{
			if (result == NSModalResponseOK)
			{
				exportURL = self.savePanel.URL;
				if (exportURL)
				{
					[self.savePanel orderOut:nil];
					{
						[self->_serialHexViewController doExport:exportURL];
					}
				}
			}
		}];
	}
}

/********************************* sendFatFs **********************************/
- (IBAction)sendFatFs:(id)sender
{
	if ([self.serialHexViewController portIsOpen:YES])
	{
		NSError *error;
		NSString *globallyUniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
		NSString *tempDirectoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:globallyUniqueString];
		NSURL *tempDirectoryURL = [NSURL fileURLWithPath:tempDirectoryPath isDirectory:YES];
		[[NSFileManager defaultManager] createDirectoryAtURL:tempDirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
		if (error)
		{
			[self.serialHexViewController postErrorString:error.localizedDescription];
		} else
		{
			NSURL* docURL = [NSURL fileURLWithPath:@"temp.hex" relativeToURL:tempDirectoryURL];
			if ([self.serialHexViewController doExport:docURL])
			{
				[self.serialHexViewController sendHexFile:docURL];
			}
			[[NSFileManager defaultManager] removeItemAtURL:tempDirectoryURL error:&error];
			if (error)
			{
				[self.serialHexViewController postErrorString:error.localizedDescription];
			}
		}
	}
}

/******************************* stopFatFsSend ********************************/
- (IBAction)stopFatFsSend:(id)sender
{
	[self.serialHexViewController stop];
}

@end
