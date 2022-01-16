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
#include "Base64Str.h"


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

// When the action is set to nil the item is a submenu
// When only the mainMenuTag is zero the item is a submenu item of the previous submenu entry.
// When mainMenuTag and subMenuTag are zero, it means pop the submenu to the previous submenu
SMenuItemDesc	menuItems[] =
{
	{1,10, @selector(open:)},
	{1,15, @selector(exportBinary:)},
	{3,1, @selector(setTimeCommand:)},
	{3,2, nil},	// SDK500 commands submenu
		{0,1, @selector(setNodeIDCommand:)},
		{0,2, @selector(getWatchdogResetCountCommand:)},
		{0,3, @selector(resetWatchdogResetCountCommand:)},
		{0,4, @selector(readCalibrationCommand:)},
		{0,5, @selector(readEEPROMRangeCommand:)},
		{0,6, @selector(writeEEPROMRangeCommand:)},
	/*
	*	I thought about dynamically building the AT commands menu but I
	*	couldn't come up with a property list format that's easy to use.
	*	Instead, the AT commands mostly use the same selector and then look up
	*	the command based on the menu item tag value.  For this reason the
	*	menu item tags should be unique.
	*/
	{3,3,nil},	// AT commands submenu
		{0,100, nil},	// Time submenu
			{0,10001, @selector(sendStaticStringByTag:)},
			{0,10002, @selector(setATTimeCommand:)},
			{0,0, nil},
		{0,3, @selector(sendStaticStringByTag:)},
		{0,4, @selector(sendStaticStringByTag:)},
		{0,5, @selector(sendStaticStringByTag:)},
		{0,6, @selector(sendStaticStringByTag:)},
		{0,7, @selector(sendStaticStringByTag:)},
		{0,8, @selector(sendStaticStringByTag:)},
		{0,9, @selector(sendStaticStringByTag:)},
		{0,10, @selector(sendStaticStringByTag:)},
		{0,1000, nil},	// DNS suubmenu
			{0,100001, @selector(sendStaticStringByTag:)},
			{0,100002, @selector(sendStaticStringByTag:)},
			{0,0, nil},
		{0,1001, nil},	// SMS suubmenu
			{0,100101, @selector(sendStaticStringByTag:)},
			{0,100102, @selector(sendStaticStringByTag:)},
			{0,100103, @selector(sendStaticStringByTag:)},
			{0,100104, @selector(sendStaticStringByTag:)},
			{0,100105, @selector(sendStaticStringByTag:)},
			{0,100106, @selector(sendStaticStringByTag:)},
			{0,100107, @selector(sendStaticStringByTag:)},
			{0,100108, @selector(sendStaticStringByTag:)},
			{0,0, nil},
		{0,1002, nil}, // Network submenu
			{0,100201, @selector(sendStaticStringByTag:)},
			{0,100202, @selector(sendStaticStringByTag:)},
			{0,100203, @selector(sendStaticStringByTag:)},
			{0,0, nil},
		{0,1005, nil},	// HTTP submenu
			{0,100501, @selector(sendStaticStringByTag:)},
			{0,100502, @selector(sendStaticStringByTag:)},
			{0,100503, @selector(sendStaticStringByTag:)},
			{0,100504, @selector(sendStaticStringByTag:)},
			{0,100505, @selector(sendStaticStringByTag:)},
			{0,100506, @selector(sendStaticStringByTag:)},
			{0,0, nil},
	{3,94, @selector(sendEscapeChar:)},
	{3,95, @selector(sendCtrlZChar:)},
	{3,96, @selector(sendSelection:)},
	{3,97, @selector(sendStaticStringByTag:)},
	{3,98, @selector(sendStaticStringByTag:)},
	{3,99, @selector(sendStaticStringByTag:)},
	{4,401, @selector(encodeBase64:)},
	{4,402, @selector(decodeBase64:)}
};

/******************************* windowDidLoad ********************************/
- (void)windowDidLoad
{
	[super windowDidLoad];
	{
		const SMenuItemDesc*	miDesc = menuItems;
		const SMenuItemDesc*	miDescEnd = &menuItems[sizeof(menuItems)/sizeof(SMenuItemDesc)];
		NSMenu*	subMenu = nil;
		NSMenu*	prevSubMenu = nil;	// Only supports 2 levels
		NSMenu*	mainMenu = [NSApplication sharedApplication].mainMenu;
		NSMenuItem *menuItem = nil;
		for (; miDesc < miDescEnd; miDesc++)
		{
			if (miDesc->mainMenuTag)
			{
				subMenu = nil;
				menuItem = [[mainMenu itemWithTag:miDesc->mainMenuTag].submenu itemWithTag:miDesc->subMenuTag];
				if (menuItem)
				{
					if (miDesc->action)
					{
						// Assign this object as the target.
						menuItem.target = self;
						menuItem.action = miDesc->action;
					} else
					{
						prevSubMenu = nil;
						subMenu = menuItem.submenu;
					}
				}
			} else if (subMenu)
			{
				if (miDesc->subMenuTag)
				{
					menuItem = [subMenu itemWithTag:miDesc->subMenuTag];
					if (menuItem)
					{
						if (miDesc->action)
						{
							menuItem.target = self;
							menuItem.action = miDesc->action;
						} else	// Else this is a submenu
						{
							prevSubMenu = subMenu;
							subMenu = menuItem.submenu;
						}
					}
				} else	// Else both mainMenuTag and subMenuTag are zero
				{
					// This marks the end of the submenu, pop the previous
					subMenu = prevSubMenu;
					prevSubMenu = nil;
				}
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
		
		_serialHexViewController.receivedDataTextView.automaticQuoteSubstitutionEnabled = NO;
	}
	_smsModeIsText = NO;
}

/****************************** validateMenuItem ******************************/
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	BOOL	isValid = YES;
	switch (menuItem.tag)
	{
		case 15:	// Export…
			isValid = [_serialHexViewController binaryPathIsValid];
			break;
		case 96:
		case 401:
		case 402:
		{
			NSArray<NSValue *> *selection = self.serialHexViewController.receivedDataTextView.selectedRanges;
			isValid = selection.count == 1 &&
						selection.firstObject.rangeValue.length > 0;
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

/****************************** setATTimeCommand ******************************/
/*
*	Sends the AT command to set the time using the format "yy/MM/dd,hh:mm:ss+/-zz"
*/
- (IBAction)setATTimeCommand:(id)sender
{
	unsigned unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay |
						NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond |
						NSCalendarUnitTimeZone;
	NSDate *date = [NSDate date];
	NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	NSDateComponents *comps = [gregorianCalendar components:unitFlags fromDate:date];
	NSString* setTimeCommandStr = [NSString stringWithFormat:@"AT+CCLK=\"%02ld/%02ld/%02ld,%02ld:%02ld:%02ld%+03ld\"",
		comps.year-2000, comps.month, comps.day, comps.hour,
		comps.minute, comps.second, comps.timeZone.secondsFromGMT/3600];
	[self.serialHexViewController sendString:setTimeCommandStr];
}

/*************************** sendStaticStringByTag ****************************/
- (IBAction)sendStaticStringByTag:(id)sender
{
	NSMenuItem*	menuItem = sender;
	NSString*	commandStr = nil;
	switch (menuItem.tag)
	{
		case 3:	// Get Connection
			commandStr = @"AT+CREG?";
			break;
		case 4:	// Get Network Operators
			commandStr = @"AT+COPS=?";
			break;
		case 5:	// Connect to Verizon
			commandStr = @"AT+COPS=4,2,\"311480\",7";
			break;
		case 6:	// Set Verbose Error Response
			commandStr = @"AT+CMEE=2";
			break;
		case 7:	// Get RSSI
			commandStr = @"AT+CSQ";
			break;
		case 8:	// Check Battery
			commandStr = @"AT+CBC";
			break;
		case 9:	// Get Device IMEI
			commandStr = @"AT+GSN";
			break;
		case 10:	// Get SIM ICCID
			commandStr = @"AT+CCID";
			break;
		case 97:	// Send Wakeup Request
			commandStr = @"w";
			break;
		case 98:	// Send Sleep Request
			commandStr = @"s";
			_smsModeIsText = NO;
			break;
		case 99:	// Send Reset Request
			commandStr = @"r";
			_smsModeIsText = NO;
			break;
		case 10001:	// Get Time
			commandStr = @"AT+CCLK?";
			break;
		case 100001:	// Get DNS IPs
			commandStr = @"AT+CDNSCFG?";
			break;
		case 100002:	// Set DNS IPs to Google
			commandStr = @"AT+CDNSCFG=\"8.8.8.8\",\"8.8.4.4\"";
			break;
		case 100101:	// Get SMS Mode
			commandStr = @"AT+CMGF?";
			break;
		case 100102:	// Set SMS Text Mode
			commandStr = @"AT+CMGF=1";
			_smsModeIsText = YES;
			break;
		case 100103:	// Set SMS PDU Mode
			commandStr = @"AT+CMGF=0";
			_smsModeIsText = NO;
			break;
		case 100104:	// Get SMSC
			commandStr = @"AT+CSCA?";
			break;
		case 100105:	// Set Verizon SMSC
			commandStr = @"AT+CSCA=\"+19036384682\",145";
			//commandStr = @"AT+CSCA=\"+316540951000\",145";
			break;
		case 100106:	// Set AT&T SMSC
			commandStr = @"AT+CSCA=\"+13123149810\",145";
			break;
		case 100107:	// Read All Messages
			commandStr = _smsModeIsText ? @"AT+CMGL=\"ALL\"" : @"AT+CMGL=4";
			break;
		case 100108:	// Read New Messages (received)
			commandStr = _smsModeIsText ? @"AT+CMGL=\"REC UNREAD\"" : @"AT+CMGL=0";
			break;
		case 100201:	// Deactivate Network
			commandStr = @"AT+CNACT=0";
			break;
		case 100202:	// Activate Verizon internet network APN
			commandStr = @"AT+CNACT=2,\"vzwinternet\"";
			// @"AT+CNACT=2,\"vzwims\""	Verizon text network APN
			break;
		case 100501:	// Initialize HTTP
			commandStr = @"AT+HTTPINIT";
			break;
		case 100502:	// Terminate HTTP
			commandStr = @"AT+HTTPTERM";
			break;
		case 100503:	// HTTP GET
			commandStr = @"AT+HTTPACTION=0";
			break;
		case 100504:	// HTTP POST
			commandStr = @"AT+HTTPACTION=1";
			break;
		case 100505:	// HTTP read
			commandStr = @"AT+HTTPREAD";
			break;
		case 100506:	// HTTP status
			commandStr = @"AT+HTTPSTATUS?";
			break;
	}
	[self.serialHexViewController sendString:commandStr];
}

/******************************* sendSelection ********************************/
- (IBAction)sendSelection:(id)sender
{
	NSArray<NSValue *> *selection = self.serialHexViewController.receivedDataTextView.selectedRanges;
	if (selection.count == 1 &&
		selection.firstObject.rangeValue.length > 0)
	{
		[self.serialHexViewController sendString:[self.serialHexViewController.receivedDataTextView.textStorage.string substringWithRange:selection.firstObject.rangeValue]];
	}
}

/******************************* sendEscapeChar *******************************/
- (IBAction)sendEscapeChar:(id)sender
{
	[self.serialHexViewController sendData:[NSData dataWithBytes:"\x1B" length:1]];
}

/******************************* sendCtrlZChar ********************************/
- (IBAction)sendCtrlZChar:(id)sender
{
	[self.serialHexViewController sendData:[NSData dataWithBytes:"\x1Z" length:1]];
}

/******************************** encodeBase64 ********************************/
- (IBAction)encodeBase64:(id)sender
{
	NSArray<NSValue *> *selection = self.serialHexViewController.receivedDataTextView.selectedRanges;
	if (selection.count == 1 &&
		selection.firstObject.rangeValue.length > 0)
	{
		NSRange	selectedRange = selection.firstObject.rangeValue;
		const char* utfText = self.serialHexViewController.receivedDataTextView.textStorage.string.UTF8String;
		std::string	selectedText(&utfText[selectedRange.location], selectedRange.length);
		std::string encodedStr;
		Base64Str::Encode(selectedText, encodedStr);
		[self.serialHexViewController.receivedDataTextView.textStorage replaceCharactersInRange:selectedRange withString:[NSString stringWithUTF8String:encodedStr.c_str()]];
		selectedRange.length = encodedStr.size();
		[self.serialHexViewController.receivedDataTextView setSelectedRange:selectedRange];
	}

}

/******************************** decodeBase64 ********************************/
- (IBAction)decodeBase64:(id)sender
{
	NSArray<NSValue *> *selection = self.serialHexViewController.receivedDataTextView.selectedRanges;
	if (selection.count == 1 &&
		selection.firstObject.rangeValue.length > 0)
	{
		NSRange	selectedRange = selection.firstObject.rangeValue;
		const char* utfText = self.serialHexViewController.receivedDataTextView.textStorage.string.UTF8String;
		std::string	selectedText(&utfText[selectedRange.location], selectedRange.length);
		std::string decodedStr;
		Base64Str::Decode(selectedText, decodedStr);
		if ([self.serialHexViewController containsNonPrintableChars:decodedStr.c_str() length:decodedStr.size()])
		{
			[self.serialHexViewController appendNewLine];
			[self.serialHexViewController appendColoredString:self.serialHexViewController.yellowColor string:@"----- Decoded Base64 string contains non-printable characters, dump follows -----"];
			[self.serialHexViewController appendHexDump:decodedStr.c_str() length:decodedStr.size() addPreamble:YES];
			[self.serialHexViewController post];
		} else
		{
			[self.serialHexViewController.receivedDataTextView.textStorage replaceCharactersInRange:selectedRange withString:[NSString stringWithUTF8String:decodedStr.c_str()]];
			selectedRange.length = decodedStr.size();
			[self.serialHexViewController.receivedDataTextView setSelectedRange:selectedRange];
		}
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
