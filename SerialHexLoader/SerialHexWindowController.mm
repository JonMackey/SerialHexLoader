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
#import "SetRFM69IDsWindowController.h"
#import "MemoryHelperWindowController.h"
#import "SDK500IOSession.h"


@interface SerialHexWindowController ()

@end

@implementation SerialHexWindowController
// SANDBOX_ENABLED is defined in GCC_PREPROCESSOR_DEFINITIONS
#if SANDBOX_ENABLED
NSString *const kBinaryURLBMKey = @"binaryURLBM";
#else
NSString *const kBinaryPathKey = @"binaryPath";
#endif
NSString *const kNetworkIDKey = @"networkID";
NSString *const kNodeIDKey = @"nodeID";
NSString *const kStartingMemAddressKey = @"startingMemAddress";
NSString *const kMemLengthKey = @"memLength";
NSString *const kMemValueKey = @"memValue";
NSString *const kViewDataAs = @"viewDataAs";

struct SMenuItemDesc
{
	NSInteger	mainMenuTag;
	NSInteger	subMenuTag;
    SEL action;
};

SMenuItemDesc	menuItems[] =
{
	{1,10, @selector(open:)},
	{1,15, @selector(exportBinary:)},
	{3,1, @selector(setTimeCommand:)},
	{3,2, @selector(setNodeIDCommand:)},
	{3,3, @selector(getWatchdogResetCountCommand:)},
	{3,4, @selector(resetWatchdogResetCountCommand:)},
	{3,5, @selector(readCalibrationCommand:)},
	{3,6, @selector(readEEPROMRangeCommand:)},
	{3,7, @selector(writeEEPROMRangeCommand:)}
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

/********************************** sendHex ***********************************/
- (IBAction)sendHex:(id)sender
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

/******************************** stopSendHex *********************************/
- (IBAction)stopSendHex:(id)sender
{
	[self.serialHexViewController stop];
}

/******************************* setTimeCommand *******************************/
/*
*	Sends an > followed by the unix time in hex as an ascii string.
*	Used to set the time on a device.
*/
- (IBAction)setTimeCommand:(id)sender
{
	NSTimeZone* timeZone = NSTimeZone.localTimeZone;
	time_t result = time(nullptr) + timeZone.secondsFromGMT;
	NSString* setTimeCommandStr = [NSString stringWithFormat:@">%lX", result];
	if ([self.serialHexViewController sendString:setTimeCommandStr])
	{
		[self.serialHexViewController postInfoString:@"Time set command sent"];
	}
}

/****************************** setNodeIDCommand ******************************/
- (IBAction)setNodeIDCommand:(id)sender
{
	if ([self.serialHexViewController portIsOpen:YES])
	{
		SetRFM69IDsWindowController* rfm69IDsWindowController = [[SetRFM69IDsWindowController alloc] initWithWindowNibName:@"SetRFM69IDsWindowController"];
		
		if ([[NSApplication sharedApplication] runModalForWindow:rfm69IDsWindowController.window] == NSModalResponseOK)
		{
			NSInteger networkID = [[NSUserDefaults standardUserDefaults] integerForKey:kNetworkIDKey];
			NSInteger nodeID = [[NSUserDefaults standardUserDefaults] integerForKey:kNodeIDKey];
			
			struct SRFM69IDs
			{
				uint8_t	networkID;
				uint8_t nodeID;
			} rfm69IDs = {(uint8_t)networkID, (uint8_t)nodeID};
			SDK500IOSession* sdk500IOSession = [[SDK500IOSession alloc] init:self.serialHexViewController.serialPort];
		#if 0
			// A test for sending a large block of eeprom data
			const char testData[] = "In the case of multiple BMP280 remotes, power should not be applied to the "
			"remotes simultaneously to avoid packet collisions.  This requirement doesn't "
			"apply to the log 3 button remote because the log remote uses the BMP280 "
			"remote's period to determine when to send a packet.  The log remote sends "
			"it's packet immediately after the BMP280's packet.";
			NSData* rfm69IDsData = [NSData dataWithBytes:&testData length:sizeof(testData)-1];
		#else
			NSData* rfm69IDsData = [NSData dataWithBytes:&rfm69IDs length:2];
			sdk500IOSession.timeout = 2;	// Timeout after n seconds if no response from ISP
		#endif
			SSDK500ParamBlk	devParamBlk = {0};
			devParamBlk.eepromSize = Endian16_Swap(512);	// The only param used by the ISP when programming the eeprom is the eepromsize.
			[sdk500IOSession sdkSetDevice:&devParamBlk];
			[sdk500IOSession sdkLoadAddress:0];
			[sdk500IOSession sdkEnterProgMode];
			[sdk500IOSession sdkReadSignature];
			[sdk500IOSession sdkProgPage:rfm69IDsData memType:'E' verify:YES];
			[sdk500IOSession sdkLeaveProgMode];
			sdk500IOSession.beginMsg = @"Set network and node ID command sent";
			sdk500IOSession.completedMsg = [NSString stringWithFormat:@"Network ID set to %ld.  Node ID set to %ld (verified).", networkID, nodeID];
			[self.serialHexViewController beginSerialPortIOSession:sdk500IOSession clearLog:NO];
		}
		[rfm69IDsWindowController.window close];
	}
}

/************************** writeEEPROMRangeCommand ***************************/
- (IBAction)writeEEPROMRangeCommand:(id)sender
{
	if ([self.serialHexViewController portIsOpen:YES])
	{
		MemoryHelperWindowController* memoryHelpersWindowController = [[MemoryHelperWindowController alloc] initWithWindowNibName:@"MemoryHelperWindowController"];
		memoryHelpersWindowController.isRead = NO;
		
		if ([[NSApplication sharedApplication] runModalForWindow:memoryHelpersWindowController.window] == NSModalResponseOK)
		{
			NSInteger startingMemAddress = [[NSUserDefaults standardUserDefaults] integerForKey:kStartingMemAddressKey];
			NSInteger memLength = [[NSUserDefaults standardUserDefaults] integerForKey:kMemLengthKey];
			NSInteger memValue = [[NSUserDefaults standardUserDefaults] integerForKey:kMemValueKey];
			if (memLength &&
				memLength < 512)
			{
				SDK500IOSession* sdk500IOSession = [[SDK500IOSession alloc] init:self.serialHexViewController.serialPort];

				uint32_t	memLength32 = ((uint32_t)(memLength+3)/4);
				uint32_t	*memBlock = new uint32_t[memLength32];
				for (uint32_t i = 0; i < memLength32; i++)
				{
					memBlock[i] = (uint32_t)memValue;
				}
				NSData* memData = [NSData dataWithBytes:memBlock length:memLength];
				delete [] memBlock;
				
				sdk500IOSession.timeout = 2;	// Timeout after n seconds if no response from ISP
				SSDK500ParamBlk	devParamBlk = {0};
				devParamBlk.eepromSize = Endian16_Swap(512);	// The only param used by the ISP when programming the eeprom is the eepromsize.
				[sdk500IOSession sdkSetDevice:&devParamBlk];
				[sdk500IOSession sdkLoadAddress:startingMemAddress];
				[sdk500IOSession sdkEnterProgMode];
				[sdk500IOSession sdkReadSignature];
				[sdk500IOSession sdkProgPage:memData memType:'E' verify:YES];
				[sdk500IOSession sdkLeaveProgMode];
				sdk500IOSession.beginMsg = @"Write EEPROM command sent";
				sdk500IOSession.completedMsg = [NSString stringWithFormat:@"0x%lX EEPROM memory bytes written starting at address 0x%lX set to 0x%lX. (verified).", memLength, startingMemAddress*2, memValue];
				[self.serialHexViewController beginSerialPortIOSession:sdk500IOSession clearLog:NO];
			} else
			{
				[self.serialHexViewController postErrorString:@"Memory length must be between 1 and 512 bytes."];
			}
		}
		[memoryHelpersWindowController.window close];
	}
}

/*************************** readEEPROMRangeCommand ***************************/
- (IBAction)readEEPROMRangeCommand:(id)sender
{
	if ([self.serialHexViewController portIsOpen:YES])
	{
		MemoryHelperWindowController* memoryHelpersWindowController = [[MemoryHelperWindowController alloc] initWithWindowNibName:@"MemoryHelperWindowController"];
		memoryHelpersWindowController.isRead = YES;
		
		if ([[NSApplication sharedApplication] runModalForWindow:memoryHelpersWindowController.window] == NSModalResponseOK)
		{
			NSInteger startingMemAddress = [[NSUserDefaults standardUserDefaults] integerForKey:kStartingMemAddressKey];
			NSInteger memLength = [[NSUserDefaults standardUserDefaults] integerForKey:kMemLengthKey];
			NSInteger viewDataAs = [[NSUserDefaults standardUserDefaults] integerForKey:kViewDataAs];
			
			if (memLength &&
				memLength < 512)
			{
				SDK500IOSession* sdk500IOSession = [[SDK500IOSession alloc] init:self.serialHexViewController.serialPort];
				
				sdk500IOSession.timeout = 2;	// Timeout after n seconds if no response from ISP
				SSDK500ParamBlk	devParamBlk = {0};
				devParamBlk.eepromSize = Endian16_Swap(512);	// The only param used by the ISP when programming the eeprom is the eepromsize.
				[sdk500IOSession sdkSetDevice:&devParamBlk];
				[sdk500IOSession sdkLoadAddress:startingMemAddress];
				[sdk500IOSession sdkEnterProgMode];
				[sdk500IOSession sdkReadSignature];
				[sdk500IOSession sdkReadPage:nil memType:'E' length:memLength];
				[sdk500IOSession sdkLeaveProgMode];
				sdk500IOSession.beginMsg = @"Read EEPROM command sent";
				sdk500IOSession.completedMsg = [NSString stringWithFormat:@"0x%lX EEPROM memory bytes read starting at 0x%lX.", memLength, startingMemAddress];
				sdk500IOSession.completionBlock = ^(SerialPortIOSession* ioSession)
				{
					SDK500IOSession*	sdk500Session = (SDK500IOSession*)ioSession;
					[self.serialHexViewController appendFormat:@"\nlength = %d\n", (int)sdk500Session.dataRead.length];
//					[self.serialHexViewController appendHexDump:sdk500Session.dataRead.bytes length:sdk500Session.dataRead.length addPreamble:NO];
					[self.serialHexViewController appendDataDump:sdk500Session.dataRead.bytes length:sdk500Session.dataRead.length startAddress:startingMemAddress*2 unit:(uint8_t)viewDataAs];
					[self.serialHexViewController post];
				};
				[self.serialHexViewController beginSerialPortIOSession:sdk500IOSession clearLog:NO];
			} else
			{
				[self.serialHexViewController postErrorString:@"Memory length must be between 1 and 512 bytes."];
			}
		}
		[memoryHelpersWindowController.window close];
	}
}

/************************ getWatchdogResetCountCommand ************************/
- (IBAction)getWatchdogResetCountCommand:(id)sender
{
	if ([self.serialHexViewController portIsOpen:YES])
	{
		SDK500IOSession* sdk500IOSession = [[SDK500IOSession alloc] init:self.serialHexViewController.serialPort];
		sdk500IOSession.timeout = 2;	// Timeout after n seconds if no response from ISP
		SSDK500ParamBlk	devParamBlk = {0};
		devParamBlk.eepromSize = Endian16_Swap(512);	// The only param used by the ISP when programming the eeprom is the eepromsize.
		[sdk500IOSession sdkSetDevice:&devParamBlk];
		[sdk500IOSession sdkLoadAddress:2];
		[sdk500IOSession sdkEnterProgMode];
		[sdk500IOSession sdkReadSignature];
		[sdk500IOSession sdkReadPage:nil memType:'E' length:2];
		[sdk500IOSession sdkLeaveProgMode];
		sdk500IOSession.beginMsg = @"Get watchdog reset count command sent.";
		sdk500IOSession.completionBlock = ^(SerialPortIOSession* ioSession)
		{
			SDK500IOSession*	sdk500Session = (SDK500IOSession*)ioSession;
			if (sdk500Session.dataRead.length == 2)
			{
				[self.serialHexViewController postInfoString:
					[NSString stringWithFormat:@"Watchdog reset count = %hd",
						*(uint16_t*)sdk500Session.dataRead.bytes]];
			} else
			{
				[self.serialHexViewController postErrorString:@"Unable to retrieve reset count."];
			}
		};
		[self.serialHexViewController beginSerialPortIOSession:sdk500IOSession clearLog:NO];
	}
}

/*********************** resetWatchdogResetCountCommand ***********************/
- (IBAction)resetWatchdogResetCountCommand:(id)sender
{
	if ([self.serialHexViewController portIsOpen:YES])
	{
		SDK500IOSession* sdk500IOSession = [[SDK500IOSession alloc] init:self.serialHexViewController.serialPort];
		uint16_t	zeroData = 0;
		NSData* resetData = [NSData dataWithBytes:&zeroData length:2];
		sdk500IOSession.timeout = 2;	// Timeout after n seconds if no response from ISP
		SSDK500ParamBlk	devParamBlk = {0};
		devParamBlk.eepromSize = Endian16_Swap(512);	// The only param used by the ISP when programming the eeprom is the eepromsize.
		[sdk500IOSession sdkSetDevice:&devParamBlk];
		[sdk500IOSession sdkLoadAddress:2];
		[sdk500IOSession sdkEnterProgMode];
		[sdk500IOSession sdkReadSignature];
		[sdk500IOSession sdkProgPage:resetData memType:'E' verify:YES];
		[sdk500IOSession sdkLeaveProgMode];
		sdk500IOSession.beginMsg = @"Reset watchdog reset count command sent.";
		sdk500IOSession.completedMsg = @"Watchdog reset count reset to zero.";
		[self.serialHexViewController beginSerialPortIOSession:sdk500IOSession clearLog:NO];
	}
}

/************************** readCalibrationCommand ***************************/
- (IBAction)readCalibrationCommand:(id)sender
{
	if ([self.serialHexViewController portIsOpen:YES])
	{
		SDK500IOSession* sdk500IOSession = [[SDK500IOSession alloc] init:self.serialHexViewController.serialPort];
		[sdk500IOSession sdkEnterProgMode];
		[sdk500IOSession sdkReadSignature];
		[sdk500IOSession sdkReadCalibration];
		[sdk500IOSession sdkLeaveProgMode];
		sdk500IOSession.beginMsg = @"Read calibration (OSCCAL) command sent.";
		sdk500IOSession.completedMsg = @"Done.";
		[self.serialHexViewController beginSerialPortIOSession:sdk500IOSession clearLog:NO];
	}
}

@end
