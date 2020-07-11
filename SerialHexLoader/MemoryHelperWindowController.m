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
*	MemoryHelperWindowController
*	
*	Created by Jon Mackey on 7/8/20.
*	Copyright © 2020 Jon Mackey. All rights reserved.
*/


#import "MemoryHelperWindowController.h"

@interface MemoryHelperWindowController ()

@end

@implementation MemoryHelperWindowController

/****************************** windowDidLoad *********************************/
- (void)windowDidLoad
{
    [super windowDidLoad];

	_startingAddress = (uint32_t)startAddressTextField.integerValue;
	_memLength = (uint32_t)lengthTextField.integerValue;
	[self updateAddressRange];
	
	if (_isRead)
	{
		[self showViewDataAsField];
	} else
	{
		[self showValueField];
	}
}
   
/************************************* ok *************************************/
- (IBAction)ok:(id)sender
{
	/*
	*	Force a validation of the current field being edited.
	*	If validation passed THEN
	*	it's OK to exit.
	*/
	if ([[self window] makeFirstResponder:nil])
	{
		[[NSApplication sharedApplication] stopModalWithCode:NSModalResponseOK];
	}
}

/*********************************** cancel ***********************************/
- (IBAction)cancel:(id)sender
{
	[[NSApplication sharedApplication] stopModalWithCode:NSModalResponseCancel];
}

/**************************** startAddressChanged *****************************/
- (IBAction)startAddressChanged:(id)sender
{
	uint32_t unsigned32Result;
	NSScanner *scanner = [NSScanner scannerWithString: startAddressTextField.stringValue];
	if ([scanner scanHexInt:&unsigned32Result])
	{
		_startingAddress = unsigned32Result;
		[self updateAddressRange];
	}
}

/****************************** memLengthChanged ******************************/
- (IBAction)memLengthChanged:(id)sender
{
	uint32_t unsigned32Result;
	NSScanner *scanner = [NSScanner scannerWithString: lengthTextField.stringValue];
	if ([scanner scanHexInt:&unsigned32Result])
	{
		_memLength = unsigned32Result;
		[self updateAddressRange];
	}
}

/****************************** updateAddressRange ******************************/
-(void)updateAddressRange
{
	addressRangeTextField.stringValue = [NSString stringWithFormat:@"%04X:%04X",
						_startingAddress*2, (_startingAddress*2) + _memLength];
}

/******************************* showValueField *******************************/
- (void)showValueField
{
	valueTextField.hidden = NO;
	valueLabel.hidden = NO;
	valueTextField.needsDisplay = YES;
	valueLabel.needsDisplay = YES;
}

/******************************* showViewDataAsField *******************************/
- (void)showViewDataAsField
{
	viewDataAsPopUp.hidden = NO;
	viewDataAsLabel.hidden = NO;
	viewDataAsPopUp.needsDisplay = YES;
	viewDataAsLabel.needsDisplay = YES;
}

@end
