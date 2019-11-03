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
*	SetRFM69IDsWindowController
*	
*	Created by Jon Mackey on 10/26/19.
*	Copyright © 2019 Jon Mackey. All rights reserved.
*/


#import "SetRFM69IDsWindowController.h"

@interface SetRFM69IDsWindowController ()

@end

@implementation SetRFM69IDsWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
}

/*********************************** ok ***************************************/
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

/********************************* cancel *************************************/
- (IBAction)cancel:(id)sender
{
	[[NSApplication sharedApplication] stopModalWithCode:NSModalResponseCancel];
}

@end
