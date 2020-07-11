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
//  SDK500IOSession.m
//  SerialHexLoader
//
//  Created by Jon Mackey on 10/31/19.
//  Copyright © 2019 Jon Mackey. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SDK500IOSession.h"

@implementation SDK500IOSession

/*
SerialHexViewController is a subclass of SerialViewController.
SerialViewController has a member serialPortSession.
serialPortSession is alive for as long as isDone returns false or its stop
function isn't called.

For as long as it's alive any data received on the serial port will be passed
to the didRecieveData function.  Any data returned by didRecieveData is posted
in the application's log window (formatted as data received).
To keep a session going, sendData is called within didRecieveData, else
didRecieveData will end the session by setting done to YES.

All SDK500 commands are ASCII characters.  The command string is the list of
commands to be executed in that order.  The command string is set by calling
one or more sdkXXX functions.

If needed the command string could be changed to a command stack to accomodate
stringing multiple writes or reads together.  This would probably only be needed
if you don't want to (or can't) write or read the entire eeprom in one shot.

*/

/*
*	If more than 64 bytes of eeprom data is to be written, the shipping
*	ArduinoISP.ino needs to be fixed.  See "ArduinoISP eeprom bug.md" under
*	SerialHexLoader/Arduino/
*/
#define SDK_MAX_BLOCK_SIZE 256

/************************************ init ************************************/
- (instancetype)init:(ORSSerialPort *)inPort
{
	self = [super initWithData:nil port:inPort];
	if (self)
	{
		_loadAddress = 0;
		_commandIndex = 0;
		_commands = [NSMutableData dataWithCapacity:256];
		_compareToProg = 0;
	}
	return(self);
}

/*********************************** begin ************************************/
- (void)begin
{
	[super begin];
	self.dataIndex = 0;
	self.commandIndex = 0;
	[self continueSession];
}

/****************************** continueSession *******************************/
- (void)continueSession
{
	if (!self.isDone)
	{
		NSMutableData*	dataToSend = [NSMutableData dataWithCapacity:256];
		_command = ((uint8_t*)_commands.mutableBytes)[_commandIndex];
		[dataToSend appendBytes:&_command length:1];
		_expectedResponse = STK_INSYNC;
		switch(_command)
		{
			case STK_SET_DEVICE:	// + device data, Sync_CRC_EOP
				[dataToSend appendData:_deviceData];
				break;
			case STK_LOAD_ADDRESS: // + addr_low, addr_high, Sync_CRC_EOP
			{
				// loadAddress is a word address that is multiplied by 2 by
				// the ISP.  This defines the address that STK_PROG_PAGE and
				// STK_READ_PAGE write/read to/from.
				uint16_t loadAddress = _loadAddress + (_dataIndex/2);
				[dataToSend appendBytes:&loadAddress length:2];
				break;
			}
			case STK_ENTER_PROGMODE:	// + Sync_CRC_EOP
			case STK_LEAVE_PROGMODE:	// + Sync_CRC_EOP
				break;
			case STK_PROG_PAGE: // + bytes_high, bytes_low, memtype, data, Sync_CRC_EOP
			{
				NSUInteger	bytesToSend = self.data.length - _dataIndex;
				if (bytesToSend > SDK_MAX_BLOCK_SIZE)
				{
					bytesToSend = SDK_MAX_BLOCK_SIZE;
				}
				uint8_t	preamble[3];
				preamble[0] = (bytesToSend >> 8);		// bytes_high
				preamble[1] = (bytesToSend & 0xFF);		// bytes_low
				preamble[2] = _memType;					// memtype
				[dataToSend appendBytes:&preamble length:3];
				[dataToSend appendBytes:&((const uint8_t*)self.data.bytes)[_dataIndex] length:bytesToSend];
				_dataIndex += bytesToSend;
				if (_dataIndex == self.data.length)
				{
					_dataIndex = 0;
				}
				//fprintf(stderr, "bytesToSend = %ld\n", bytesToSend);
				break;
			}
			case STK_READ_PAGE: // + bytes_high, bytes_low, memtype, Sync_CRC_EOP
				{
					if (_dataIndex == 0)
					{
						_dataRead = [NSMutableData dataWithCapacity:256];
					}
					NSUInteger	bytesRequested = _bytesRequested - _dataIndex;
					if (bytesRequested > SDK_MAX_BLOCK_SIZE)
					{
						bytesRequested = SDK_MAX_BLOCK_SIZE;
					}
					uint8_t	preamble[3];
					preamble[0] = (bytesRequested >> 8);		// bytes_high
					preamble[1] = (bytesRequested & 0xFF);		// bytes_low
					preamble[2] = _memType;					// memtype
					[dataToSend appendBytes:&preamble length:3];
					_bytesReceived = 0;
					break;
				}
			case STK_READ_SIGN:	// + Sync_CRC_EOP
				_signature = 0;
				_bytesReceived = 0;
				break;
			case STK_READ_OSCCAL:
				_calibrationByte = 0;
				_bytesReceived = 0;
				break;
			default:
				break;
		}
		uint8_t	syncCRCEOP = CRC_EOP;
		[dataToSend appendBytes:&syncCRCEOP length:1];
		//fprintf(stderr, "len = %d\n", (int)dataToSend.length);
		[self.serialPort sendData:dataToSend];
	}
}

/******************************* didReceiveData *******************************/
- (NSData*)didReceiveData:(NSData *)inData
{
	if (!self.isDone)
	{
		//fprintf(stderr, "%.*s\n", (int)inData.length, inData.bytes);
		const uint8_t*	receivedData = (const uint8_t*)inData.bytes;
		NSUInteger	bytesToProcess = inData.length;
		while (bytesToProcess)
		{
			/*
			*	If waiting for the in-sync response THEN
			*	the first byte received must be STK_INSYNC
			*/
			if (_expectedResponse == STK_INSYNC)
			{
				if (*receivedData == STK_INSYNC)
				{
					bytesToProcess--;
					_expectedResponse = STK_OK;
					receivedData++;
					continue;
				/*
				*	Else, fail, the ISP is out of sync
				*/
				} else
				{
					break;	// Fail
				}
			}
			if (_expectedResponse == STK_OK)
			{
				// Commands that return data are in this switch
				// extract the data
				switch (_command)
				{
					case STK_READ_PAGE:
						if (_dataIndex < _bytesRequested)
						{
							NSUInteger	bytesRead = _bytesRequested - _dataIndex;
							/*
							*	The number of bytes requested in a read page command
							*	can be no more than 256 bytes.  The results of the
							*	command may not be received in a single call to
							*	didReceiveData.  _bytesReceived tracks the total
							*	recieved for this single command.  _dataIndex tracks
							*	the total received for the _bytesRequested, which
							*	may be divided amoung consecutive commands in chunks
							*	no larger than 256 bytes.
							*/
							if (bytesRead > (SDK_MAX_BLOCK_SIZE - _bytesReceived))
							{
								bytesRead = SDK_MAX_BLOCK_SIZE - _bytesReceived;
							}
							
							if (bytesRead > bytesToProcess)
							{
								bytesRead = bytesToProcess;
							}
							if (bytesRead)
							{
								[_dataRead appendBytes:receivedData length:bytesRead];
								_dataIndex += bytesRead;
								receivedData += bytesRead;
								bytesToProcess -= bytesRead;
								_bytesReceived += bytesRead;
							}
							if (_dataIndex == _bytesRequested)
							{
								if (_compareToProg)
								{
									if ([_dataRead isEqualToData:self.data])
									{
										[self.delegate logInfoString:@"Data verification successful"];
									} else
									{
										[self.delegate logErrorString:@"Data verification failed"];
										self.stoppedDueToError = YES;
									}
								}
							}
						}
						break;
					case STK_READ_SIGN: // Resp_STK_INSYNC, sign_high, sign_middle, sign_low, Resp_STK_OK
					{
						NSUInteger	bytesRead = 3 - _bytesReceived;
						if (bytesRead > bytesToProcess)
						{
							bytesRead = bytesToProcess;
						}
						_bytesReceived += bytesRead;
						bytesToProcess -= bytesRead;
						for (; bytesRead; --bytesRead)
						{
							_signature = (_signature << 8) + *(receivedData++);
						}
						if (_bytesReceived == 3)
						{
							[self.delegate logInfoString:[NSString stringWithFormat:@"Device signature = 0x%X", _signature]];
						}
						break;
					}
					case STK_READ_OSCCAL: // Resp_STK_INSYNC, OSCCAL, Resp_STK_OK
					{
						_calibrationByte = *(receivedData++);
						_bytesReceived++;
						bytesToProcess--;
						[self.delegate logInfoString:[NSString stringWithFormat:@"Calibration byte (OSCCAL) = 0x%hhX", _calibrationByte]];
						break;
					}
				}
				/*
				*	If there's still bytesToProcess THEN
				*	the byte received must be STK_OK
				*/
				if (bytesToProcess == 1)
				{
					if (*receivedData == STK_OK)
					{
						bytesToProcess = 0;
						_expectedResponse = 0;	// command is done
						receivedData++;
						_commandIndex++;
						if (_commandIndex < _commands.length)
						{
							[self continueSession];
						} else
						{
							self.done = YES;
						}
					/*
					*	Else, fail, the ISP is out of sync
					*/
					} else
					{
						break; // Fail
					}
				}
			} else
			{
				break;	// Fail
			}
		}
		/*
		*	If all of the bytes received were expected and processed THEN
		*	don't dump the bytes received to the log.
		*/
		if (bytesToProcess == 0)
		{
			inData = [NSData data];	// Don't need to see what was received.
		/*
		*	Else, this is a sync error, dump the unprocessed bytes
		*/
		} else
		{
			self.stoppedDueToError = YES;
			[self.delegate logErrorString:[NSString stringWithFormat:@"Sync error, ISP unexpected response (expected %s).", _expectedResponse == STK_OK ? "STK_OK":"STK_INSYNC"]];
			self.done = YES;
			// dump whatever wasn't processed.
			inData = [NSData dataWithBytes:&((const uint8_t*)inData.bytes)[inData.length-bytesToProcess] length:bytesToProcess];
		}
	}
	return(inData);
}

/******************************* appendCommand ********************************/
- (void)appendCommand:(uint8_t)inCommand
{
	[_commands appendBytes:&inCommand length:1];
}

/******************************** sdkSetDevice ********************************/
- (void)sdkSetDevice:(SSDK500ParamBlk *)inDeviceParamBlk
{
	[self appendCommand:STK_SET_DEVICE];
	_deviceData = [NSData dataWithBytes:inDeviceParamBlk length:sizeof(SSDK500ParamBlk)];
}

/******************************* sdkLoadAddress *******************************/
- (void)sdkLoadAddress:(uint16_t)inAddress
{
	// The load address commands get added by sdkProgPage and sdkReadPage
	_loadAddress = inAddress;
}

/****************************** sdkEnterProgMode ******************************/
- (void)sdkEnterProgMode
{
	[self appendCommand:STK_ENTER_PROGMODE];
}

/******************************** sdkProgPage *********************************/
- (void)sdkProgPage:(NSData *)inData memType:(uint8_t)inMemType verify:(BOOL)inVerify
{
	[self appendCommand:STK_LOAD_ADDRESS];
	[self appendCommand:STK_PROG_PAGE];
	self.data = inData;
	_memType = inMemType;
	NSUInteger	dataLength = inData.length;
	NSUInteger	dataIndex = SDK_MAX_BLOCK_SIZE;
	for (; dataIndex < dataLength; dataIndex += SDK_MAX_BLOCK_SIZE)
	{
		[self appendCommand:STK_LOAD_ADDRESS];
		[self appendCommand:STK_PROG_PAGE];
	}
	if (inVerify)
	{
		_compareToProg = YES;
		[self sdkReadPage:nil memType:inMemType length:dataLength];
	}
}

/******************************** sdkReadPage *********************************/
- (void)sdkReadPage:(NSMutableData *)inData memType:(uint8_t)inMemType length:(NSUInteger)inLength
{
	[self appendCommand:STK_LOAD_ADDRESS];
	[self appendCommand:STK_READ_PAGE];
	_dataRead = inData;
	_memType = inMemType;
	_bytesRequested = inLength;
	NSUInteger	dataIndex = SDK_MAX_BLOCK_SIZE;
	for (; dataIndex < inLength; dataIndex += SDK_MAX_BLOCK_SIZE)
	{
		[self appendCommand:STK_LOAD_ADDRESS];
		[self appendCommand:STK_READ_PAGE];
	}
}

/****************************** sdkLeaveProgMode ******************************/
- (void)sdkLeaveProgMode
{
	[self appendCommand:STK_LEAVE_PROGMODE];
}

/****************************** sdkReadSignature ******************************/
- (void)sdkReadSignature
{
	[self appendCommand:STK_READ_SIGN];
}

/***************************** sdkReadCalibration *****************************/
- (void)sdkReadCalibration
{
	[self appendCommand:STK_READ_OSCCAL];
}

/*************************** setStoppedDueToTimeout ***************************/
/*
*	Override of setter function for _stoppedDueToTimeout
*/
- (void)setStoppedDueToTimeout:(BOOL)inStoppedDueToTimeout
{
	[super setStoppedDueToTimeout:inStoppedDueToTimeout];
	if (inStoppedDueToTimeout)
	{
		[self.delegate logErrorString:@"ISP is not responding (timeout)"];
	}
}

@end
