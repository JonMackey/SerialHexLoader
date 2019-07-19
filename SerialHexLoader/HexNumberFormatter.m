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
*	HexNumberFormatter
*	
*	Created by Jon Mackey on 5/10/19.
*	Copyright © 2019 Jon Mackey. All rights reserved.
*/


#import "HexNumberFormatter.h"

@implementation HexNumberFormatter
/**************************** stringForObjectValue ****************************/
-(NSString*)stringForObjectValue:(id)obj
{
	if ([obj isKindOfClass:[NSNumber class]])
	{
		return([NSString stringWithFormat:@"0x%X", [obj intValue]]);
	}
	return(nil);
}

/******************************* getObjectValue *******************************/
- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString  **)error
{
	uint32_t unsigned32Result;
	NSScanner *scanner;
	BOOL returnValue = NO;

	scanner = [NSScanner scannerWithString: string];
	//[scanner scanString: @"0x" intoString: NULL]; // ignore  return value
	if ([scanner scanHexInt:&unsigned32Result] && ([scanner isAtEnd]))
	{
		returnValue = YES;
		if (obj)
		{
			*obj = [NSNumber numberWithUnsignedLong:unsigned32Result];
		}
	} else
	{
		if (error)
		{
			*error = @"Couldn’t convert  to hexadecimal";
		}
	}
	return(returnValue);
}

/**************************** isPartialStringValid ****************************/
- (BOOL)isPartialStringValid:(NSString *)partialString
		newEditingString:(NSString * _Nullable *)newString
		errorDescription:(NSString * _Nullable *)error
{
	BOOL	acceptable = YES;
	if (partialString.length > 0)
	{
		uint32_t unsigned32Result;
		NSScanner *scanner = [NSScanner scannerWithString: partialString];
		if ([scanner scanHexInt:&unsigned32Result])
		{
			NSString*	reformattedString = [NSString stringWithFormat:@"0x%X", unsigned32Result];
			acceptable = [reformattedString compare:partialString] == kCFCompareEqualTo;
			if (!acceptable)
			{
				*newString = reformattedString;
			}
		}
	}
	return(acceptable);
}

@end
