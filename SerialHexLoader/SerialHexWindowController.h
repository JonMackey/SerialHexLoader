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


#import <Cocoa/Cocoa.h>
#import "SerialHexViewController.h"
NS_ASSUME_NONNULL_BEGIN

@interface SerialHexWindowController : NSWindowController
{
	IBOutlet NSView *serialView;
}
- (IBAction)exportBinary:(id)sender;

@property (nonatomic, strong) SerialHexViewController *serialHexViewController;
@property (nonatomic, weak) NSSavePanel *savePanel; // valid only while panel is open

- (void)doOpen:(NSURL*)inDocURL;

@end

NS_ASSUME_NONNULL_END
