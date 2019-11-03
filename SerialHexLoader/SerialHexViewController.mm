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
*	SerialHexViewController
*	
*	Created by Jon Mackey on 5/10/19.
*	Copyright © 2019 Jon Mackey. All rights reserved.
*/


#import "SerialHexViewController.h"
#import "SendHexIOSession.h"

#include "IntelHex.h"

@interface SerialHexViewController ()

@end

@implementation SerialHexViewController
// SANDBOX_ENABLED is defined in GCC_PREPROCESSOR_DEFINITIONS
#if SANDBOX_ENABLED
NSString *const kBinaryURLBMKey = @"binaryURLBM";
#else
NSString *const kBinaryPathKey = @"binaryPath";
#endif

NSString *const kOmitNullsWhenPossibleKey = @"omitNullsWhenPossible";
NSString *const kPageSizeKey = @"pageSize";

/****************************** viewDidLoad ***********************************/
- (void)viewDidLoad
{
    [super viewDidLoad];
	[self bind:@"eraseBeforeWrite" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:@"eraseBeforeWrite" options:NULL];
	self.progressMin = 0;
	self.progressMax = 1;
	[[NSScanner scannerWithString: startAddressTextField.stringValue] scanHexInt:&_startingAddress];
}

/*************************** binaryPathIsValid ********************************/
-(BOOL)binaryPathIsValid
{
	BOOL isDirectory = YES;
	return([[NSFileManager defaultManager] fileExistsAtPath:binaryPathControl.URL.path isDirectory:&isDirectory] && isDirectory == NO);
}

/******************************* binaryFileName *******************************/
-(NSString*)binaryFileName
{
	return([[[[binaryPathControl URL] path] lastPathComponent] stringByDeletingPathExtension]);
}

/**************************** setBinaryFileLength *****************************/
-(void)setBinaryFileLength:(long)binaryFileLength
{
	_binaryFileLength = binaryFileLength;
	binaryLengthTextField.stringValue = [NSString stringWithFormat:@"%ld", binaryFileLength];
	[self startAddressChanged:self];
}

/****************************** assignBinaryURL *******************************/
-(BOOL)assignBinaryURL:(NSURL*)inBinaryURL
{
	[binaryPathControl setURL:inBinaryURL];
	BOOL	success = [self binaryPathIsValid];
	if (success)
	{
		if ([inBinaryURL startAccessingSecurityScopedResource])
		{
			FILE*	binaryFile = fopen(inBinaryURL.path.UTF8String, "r");
			if (binaryFile)
			{
				fseek(binaryFile, 0, SEEK_END);
				self.binaryFileLength = ftell(binaryFile);
				fclose(binaryFile);
				success = self.binaryFileLength > 0;
			}
			[inBinaryURL stopAccessingSecurityScopedResource];
		}
	}
	return(success);
}

/**************************** startAddressChanged *****************************/
- (IBAction)startAddressChanged:(id)sender
{
	uint32_t unsigned32Result;
	NSScanner *scanner = [NSScanner scannerWithString: startAddressTextField.stringValue];
	if ([scanner scanHexInt:&unsigned32Result])
	{
		_startingAddress = unsigned32Result;
		unsigned32Result += (uint32_t)_binaryFileLength;
		endAddressTextField.stringValue = [NSString stringWithFormat:@"0x%X", unsigned32Result];
	}
}

/********************************** doExport **********************************/
- (BOOL)doExport:(NSURL*)inDocURL
{
#if SANDBOX_ENABLED
	NSData* binaryURLBM = [[NSUserDefaults standardUserDefaults] objectForKey:kBinaryURLBMKey];
	NSURL*	binaryURL = [NSURL URLByResolvingBookmarkData:
						binaryURLBM
							options:NSURLBookmarkResolutionWithoutUI+NSURLBookmarkResolutionWithoutMounting+NSURLBookmarkResolutionWithSecurityScope
								relativeToURL:NULL bookmarkDataIsStale:NULL error:NULL];
#else
	NSString* binaryPath = [[NSUserDefaults standardUserDefaults] objectForKey:kBinaryPathKey];
	NSURL*	binaryURL = binaryPath ? [NSURL fileURLWithPath:binaryPath isDirectory:NO] : nil;
#endif
	NSNumber* omitNullsWhenPossible = [[NSUserDefaults standardUserDefaults] objectForKey:kOmitNullsWhenPossibleKey];
	NSNumber* pageSize = [[NSUserDefaults standardUserDefaults] objectForKey:kPageSizeKey];

	bool success = IntelHex::SaveToFile(binaryURL.path.UTF8String,
								_startingAddress,
								omitNullsWhenPossible.boolValue,
								pageSize.unsignedIntValue,
								inDocURL.path.UTF8String);
	[self clear:self];
	if (success)
	{
		[self postInfoString:[NSString stringWithFormat:@"Exported %@ to %@", binaryURL.path.lastPathComponent, inDocURL.path]];
	} else
	{
		[self postErrorString:[NSString stringWithFormat:@"Write failed: %@", inDocURL.path]];
	}
	return(success);
}

/******************************* sendHexFile **********************************/
- (void)sendHexFile:(NSURL*)inDocURL
{
	if ([self portIsOpen:YES])
	{
		NSError* error;
		NSData *dataToSend = [NSData dataWithContentsOfURL:inDocURL options:0 error:&error];
		self.progressMin = _startingAddress;
		self.progressMax = dataToSend.length+_startingAddress;
		self.progressValue = _startingAddress;

		SendHexIOSession* sendHexIOSession = [[SendHexIOSession alloc] initWithData:dataToSend port:self.serialPort];
		sendHexIOSession.eraseBeforeWrite = self.eraseBeforeWrite;
		[super beginSerialPortIOSession:sendHexIOSession clearLog:YES];
	}
}


/************************** beginSerialPortIOSession **************************/
- (void)beginSerialPortIOSession:(SerialPortIOSession*)inSerialPortIOSession clearLog:(BOOL)inClearLog
{
	self.progressMin = 0;
	self.progressMax = 100;
	self.progressValue = 0;
	[super beginSerialPortIOSession:inSerialPortIOSession clearLog:inClearLog];
}

/****************************** updateProgress ********************************/
-(void)updateProgress
{
	self.progressValue = ((SendHexIOSession*)self.serialPortSession).currentAddress;
}


@end
