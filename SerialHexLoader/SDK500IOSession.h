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
//
	Please maintain this license information along with authorship
	and copyright notices in any redistribution of this code
*******************************************************************************/
//
//  SDK500IOSession.h
//  SerialHexLoader
//
//	Partial implementation of SDK500 protocol
//	
//
//  Created by Jon Mackey on 10/31/19.
//  Copyright © 2019 Jon Mackey. All rights reserved.
//

#import "SerialPortIOSession.h"
#include "stk500.h"

@interface SDK500IOSession : SerialPortIOSession

@property (nonatomic) NSUInteger	dataIndex;		// used by any command expecting data in the response
@property (nonatomic) NSUInteger	bytesRequested;	// for read page
@property (nonatomic) NSUInteger	bytesReceived;	// used by any command expecting data in the response
@property (nonatomic) uint16_t		loadAddress;	// for load address
@property (nonatomic) BOOL			compareToProg;	// compare read with written, fail if not same
@property (nonatomic) uint8_t		memType;		// for read and prog page
@property (nonatomic) uint8_t		command;
@property (nonatomic) uint8_t		expectedResponse;
@property (nonatomic) uint32_t		signature;
@property (nonatomic, strong) NSMutableData*	commands;
@property (nonatomic) NSUInteger	commandIndex;
@property (nonatomic, strong) NSMutableData* dataRead;
@property (nonatomic, strong) NSData* deviceData;	// SSDK500ParamBlk

- (instancetype)init:(ORSSerialPort *)inPort;
- (void)begin;
- (NSData*)didReceiveData:(NSData *)inData;

- (void)sdkSetDevice:(SSDK500ParamBlk *)inDeviceParamBlk;
- (void)sdkLoadAddress:(uint16_t)inAddress;
- (void)sdkEnterProgMode;
- (void)sdkProgPage:(NSData *)inData memType:(uint8_t)inMemType verify:(BOOL)inVerify;	// memType one of 'E' or 'F' for eeprom or Flash
- (void)sdkReadPage:(NSMutableData *)inData memType:(uint8_t)inMemType length:(NSUInteger)inLength;
- (void)sdkLeaveProgMode;
- (void)sdkReadSignature;
@end
