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
/*
*	HexLoader.ino
*	Copyright (c) 2018 Jonathan Mackey
*
*	Loads data onto NOR Flash or AT24C chips, and SD Cards connected to a MCU.
*	Receives data serially in Intel Hex format.
*
*	Example session:
*	- wait for serial
*	- receive an H for hex download, start waiting for lines
*	- respond with *
*	- receive a line/process a line
*	- respond with *
*	- loop till end hex command hit.
*
*	At any time if anything other than a line start is received when expected 
*	or an invalid character, respond with a ? follwed by an error message.
*
*	Line processing:
*	- On first line for a new block (256 or 512 bytes), clear the block by
*	filling it with nulls.
*	- Once a block is full OR the address changes to a new block, then write the
*	current block to the device.
*
*/
#include <SPI.h>


#define TARGET_AT24C	1
//#define TARGET_NORFLASH	1
//#define TARGET_SD		1	// Used to load data onto an SD card treated as a block device.

#ifdef TARGET_AT24C
#include <AT24C.h>
#include <Wire.h>
const uint8_t kAT24CDeviceAddr = 0x50;
const uint8_t kAT24CDeviceCapacity = 32;	// Value at end of AT24Cxxx xxx/8
AT24C	eeprom(kAT24CDeviceAddr, kAT24CDeviceCapacity);
#define BAUD_RATE	19200

#elif defined TARGET_SD
#include <SdFat.h>
const uint8_t kSdChipSelect = 10;
Sd2Card card;
SdVolume vol;
#define BAUD_RATE	9600
#elif defined TARGET_NORFLASH
#include "SPIMem.h"
const uint8_t kNFChipSelect = 10;
SPIMem flash(kNFChipSelect);
#define BAUD_RATE	19200
#endif

enum EIntelHexLineState
{
	// Start code   Byte count   Address H/L   Record type   Data   Checksum
	eGetByteCount,
	eGetAddressH,
	eGetAddressL,
	eGetRecordType,
	eGetData,
	eGetChecksum
};

enum EIntelHexRecordType
{
	eRecordTypeData,		// 0
	eRecordTypeEOF,			// 1
	eRecordTypeExSegAddr,	// 2
	eRecordTypeStSegAddr,	// 3
	eRecordTypeExLinAddr,	// 4
	eRecordTypeStLinAddr	// 5
};

enum EIntelHexStatus
{
	eProcessing,
	eDone,
	eError
};

#ifndef TARGET_SD
// Note that kBlockSize is simply the granularity of the hex data, i.e. where
// the hex lines will break within the hex file when "Omit nulls when possible"
// is checked within the SerialHexLoader application.  When checked, this should
// be the same or larger than SerialHexLoader's Page Size.  Any block size
// multiple of 16 can be used when "Omit nulls when possible" is  unchecked
// because the granularity at that point is 16 (no nulls being omitted therefore
// all lines are <= 16 data bytes.)
// Having said all that, note that WriteBlock in this ino assumes a 512 byte
// block size, so any changes to kBlockSize will necessitate modifying
// WriteBlock.
const uint32_t	kBlockSize = 512;
#ifdef TARGET_NORFLASH
static bool		sEraseBeforeWrite;
static uint32_t	sCurrent64KBlk;
#endif
static uint8_t	sBuffer[kBlockSize];
static bool		sVerifyAfterWrite = true;
#endif
#define MAX_HEX_LINE_LEN	45
static uint8_t	sLineBuffer[MAX_HEX_LINE_LEN];
static uint8_t*	sLineBufferPtr;
static uint8_t*	sEndOfLineBufferPtr;

#ifdef TARGET_NORFLASH
void DumpJDECInfo(void)
{
	uint32_t capacity = flash.GetCapacity();
	if (capacity > 0xFF)
	{
		if (flash.GetManufacturerID() == 0xEF)
		{
			Serial.print("Winbond");
		} else
		{
			Serial.print("Unknown manufacturer = 0x");
			Serial.print(flash.GetManufacturerID(), HEX);
		}
		if (flash.GetMemoryType() == 0x40)
		{
			Serial.print(", NOR Flash");
		} else
		{
			Serial.print(", unknown type = 0x");
			Serial.print(flash.GetMemoryType(), HEX);
		}
		Serial.print(", capacity = ");
		Serial.print(capacity/0x100000);
		Serial.println("MB");
	} else
	{
		Serial.println("?failed to read the JEDEC ID");
	}
}
#endif

/********************************** setup *************************************/
void setup(void)
{
	Serial.begin(BAUD_RATE);
#ifdef TARGET_SD
	if (card.init(SPI_HALF_SPEED, kSdChipSelect) &&
		vol.init(&card))
	{
		Serial.println("SD card initialized.");
	} else
	{
		Serial.println("SD card not initialized.");
	}
#elif defined TARGET_NORFLASH
	flash.begin();
	DumpJDECInfo();
#elif defined TARGET_AT24C
	Wire.begin();
#endif
}

/*********************************** loop *************************************/
void loop()
{
	while (!Serial.available());
	switch (Serial.read())
	{
#ifdef TARGET_SD
		case 'h':
		case 'H':	// Erase before write (default)
			HexDownload();
			break;
#else
		case 'H':	// Erase before write
	#ifdef TARGET_NORFLASH
			sEraseBeforeWrite = true;
			sCurrent64KBlk = 0xF0000000;
	#endif
			HexDownload();
			break;
		/*
		*	For a new or erased chip there is no need to erase before write.
		*	For all other NOR Flash chips you must erase before write because
		*	writing only clears bits, it doesn't set them.  Erasing sets all
		*	bits to 1.
		*/
		case 'h':	// Don't erase before write
	#ifdef TARGET_NORFLASH
			sEraseBeforeWrite = false;
	#endif
			HexDownload();
			break;
		case 'E':
			FullErase();
			break;
		case 'V':
			sVerifyAfterWrite = true;
			Serial.println("Verify after write ON");
			break;
		case 'v':
			sVerifyAfterWrite = false;
			Serial.println("Verify after write OFF");
			break;
	#ifdef TARGET_NORFLASH
		case 'j':
			flash.LoadJEDECInfo();
			DumpJDECInfo();
			break;
	#endif
#endif
	}
}

/******************************** FullErase ***********************************/
void FullErase(void)
{
#ifdef TARGET_NORFLASH
	Serial.println(flash.ChipErase() ? "*" : "?Erase chip failed");
#elif defined TARGET_AT24C
	Serial.println("*");	// Chip erase isn't supported, just ignore it.
#endif
}

/******************************* ClearBuffer **********************************/
uint8_t* ClearBuffer(void)
{
	uint8_t*	buffer;
#ifdef TARGET_SD
	cache_t*	cache = vol.cacheClear();
	buffer = cache->data;
#elif defined TARGET_NORFLASH || defined TARGET_AT24C
	buffer = sBuffer;
#endif
	uint8_t*	bufferPtr = buffer;
	uint8_t*	endBufferPtr = &bufferPtr[kBlockSize];
	while (bufferPtr < endBufferPtr)
	{
		*(bufferPtr++) = 0;
	}
	return(buffer);
}

/******************************* WriteBlock ***********************************/
bool WriteBlock(
	uint8_t*	inData,
	uint32_t	inBlockIndex)
{
	bool success = true;
	if (inData)
	{
#ifdef TARGET_SD
		success = card.writeBlock(inBlockIndex, inData);
#elif defined TARGET_NORFLASH
		uint32_t	address = inBlockIndex*kBlockSize;
		/*
		*	If erase before write is enabled AND
		*	the address just stepped over a 64KB block boundary THEN
		*	Erase the block. (this assumes all addresses are increasing)
		*/
		//Serial.write('+');
		if (sEraseBeforeWrite &&
			(address/0x10000) != sCurrent64KBlk)
		{
			sCurrent64KBlk = address/0x10000;
			success = flash.Erase64KBlock(address);
			if (success)
			{
				Serial.write('=');
			}
		}
		//Serial.write('-');
		if (success)
		{
			success = flash.WritePage(address, inData) &&
						flash.WritePage(address+256, &inData[256]);
			if (sVerifyAfterWrite)
			{
				uint8_t	verifyBuff[256];
				#if 0
				success = flash.Read(address, 256, verifyBuff) &&
					memcmp(inData, verifyBuff, 256) == 0 &&
					flash.Read(address+256, 256, verifyBuff) &&
					memcmp(&inData[256], verifyBuff, 256) == 0;
				#else
				success = flash.Read(address, 256, verifyBuff);
				if (success)
				{
					success = memcmp(inData, verifyBuff, 256) == 0;
					if (success)
					{
						success = flash.Read(address+256, 256, verifyBuff);
						if (success)
						{
							success = memcmp(&inData[256], verifyBuff, 256) == 0;
							if (!success)
							{
								Serial.print("?Failed compare data[256]\n");
								/*Serial.write((const char*)verifyBuff, 256);
								Serial.print("\n\n");
								Serial.write((const char*)&inData[256], 256);
								Serial.print("\n\n");*/
							}
						} else
						{
							Serial.print("?Failed reading data[256]\n");
						}
					} else
					{
						Serial.print("?Failed compare data[0]\n");
						/*Serial.write((const char*)verifyBuff, 256);
						Serial.print("\n\n");
						Serial.write((const char*)inData, 256);
						Serial.print("\n\n");*/
					}
				} else
				{
					Serial.print("?Failed reading data[0]\n");
				}
				#endif
			}
		} else
		{
			Serial.print("?Block erase failed\n");
		}
#elif defined TARGET_AT24C
		uint32_t	address = inBlockIndex*kBlockSize;
		{
			success = eeprom.Write(address, 256, inData) +
						eeprom.Write(address+256, 256, inData+256) == kBlockSize;

			if (sVerifyAfterWrite)
			{
				uint8_t	verifyBuff[256];
				#if 0
				success = (eeprom.Read(address, 256, verifyBuff) == 256 &&
					memcmp(inData, verifyBuff, 256) == 0 &&
					eeprom.Read(address+256, 256, verifyBuff) == 256 &&
					memcmp(&inData[256], verifyBuff, 256) == 0;
				#else
				success = eeprom.Read(address, 256, verifyBuff) == 256;
				if (success)
				{
					success = memcmp(inData, verifyBuff, 256) == 0;
					if (success)
					{
						success = eeprom.Read(address+256, 256, verifyBuff) == 256;
						if (success)
						{
							success = memcmp(&inData[256], verifyBuff, 256) == 0;
							if (!success)
							{
								Serial.print("?Failed compare data[256]\n");
								/*Serial.write((const char*)verifyBuff, 256);
								Serial.print("\n\n");
								Serial.write((const char*)&inData[256], 256);
								Serial.print("\n\n");*/
							}
						} else
						{
							Serial.print("?Failed reading data[256]\n");
						}
					} else
					{
						Serial.print("?Failed compare data[0]\n");
						/*Serial.write((const char*)verifyBuff, 256);
						Serial.print("\n\n");
						Serial.write((const char*)inData, 256);
						Serial.print("\n\n");*/
					}
				} else
				{
					Serial.print("?Failed reading data[0]\n");
				}
				#endif
			}
		}
#endif
	}

	return(success);
}

/****************************** HexAsciiToBin *********************************/
// Assumes 0-9, A-Z (uppercase)
uint8_t	HexAsciiToBin(
	uint8_t	inByte)
{
	 return (inByte <= '9' ? (inByte - '0') : (inByte - ('A' - 10)));
}

/********************************* GetChar ************************************/
uint8_t GetChar(void)
{
	uint32_t	timeout = millis() + 1000;
	while (!Serial.available())
	{
		if (millis() < timeout)continue;
		return('T');
	}
	return(Serial.read());
}

/**************************** GetNexHextLineChar ******************************/
uint8_t GetNexHextLineChar(void)
{
	uint8_t	thisChar = sEndOfLineBufferPtr > sLineBufferPtr ? *(sLineBufferPtr++) : 'O';
	return(thisChar);
}

/******************************* LoadHexLine **********************************/
bool LoadHexLine(void)
{
	uint8_t	thisChar = GetChar();
	uint8_t*	bufferPtr = sLineBuffer;
	uint8_t*	endBufferPtr = &sLineBuffer[MAX_HEX_LINE_LEN];
	sLineBufferPtr = sLineBuffer;
	while (thisChar != ':')
	{
		switch (thisChar)
		{
			case '\n':
			case '\r':
			case ' ':
			case '\t':
				thisChar = GetChar();
			continue;
		}
		sLineBuffer[0] = thisChar;
		sEndOfLineBufferPtr = &sLineBuffer[1];
		return(false);	// Start code not found
	}
	
	do
	{
		*(bufferPtr++) = thisChar;
		thisChar = GetChar();
		if (thisChar != '\n')
		{
			if (thisChar != 'T')
			{
				continue;
			}
			sLineBuffer[0] = 'T';
		}
		break;
	} while(bufferPtr < endBufferPtr);
	sEndOfLineBufferPtr = bufferPtr;
	return(thisChar == '\n');
}

/******************************* HexDownload **********************************/
void HexDownload(void)
{
	uint8_t	    thisChar;
	uint8_t		thisByte = 0;
	uint8_t		state = 0;
	uint8_t		status = eProcessing;
	uint32_t	byteCount = 0;
	uint32_t	address = 0;
	uint32_t	currentBlockIndex = 0xFFFFFFFF;
	uint32_t	baseAddress = 0;
	uint8_t		recordType = eRecordTypeData;
	uint8_t		checksum = 0;
	uint8_t		hiLow = 1;
	uint8_t*	data = NULL;
	uint8_t*	dataPtr = NULL;
	uint32_t	dataIndex = 0;
	
	Serial.write('*');	// Tell the host the mode change was successful
	while(status == eProcessing)
	{
		LoadHexLine();
		thisChar = GetNexHextLineChar();
		if (thisChar != ':')
		{
			/*
			*	If this isn't the character 'S' for stop THEN
			*	report the invalid character.
			*/
			switch (thisChar)
			{
				case 'S':
					Serial.print("?Stopped by user\n");
					break;
				case 'T':
					Serial.print("?Rx Timeout\n");
					break;
				default:
					Serial.print("?No Start Code\n");
					break;
			}
			status = eError;
			break;
		} else
		{
			while(status == eProcessing)
			{
				thisChar = GetNexHextLineChar();
				hiLow++;	// nibble toggle
				/*
				*	If this is the high nibble THEN
				*	process the complete byte
				*/
				if (hiLow & 1)
				{
					thisByte = (thisByte << 4) + HexAsciiToBin(thisChar);
					checksum += thisByte;
					switch (state)
					{
						case eGetByteCount:
						{
							byteCount = thisByte;
							address = 0;
							state++;
							continue;
						}
						case eGetAddressH:
						case eGetAddressL:
							address = (address << 8) + thisByte;
							state++;
							continue;
						case eGetRecordType:
							recordType = thisByte;
							state++;
							dataIndex = 0;
							if (recordType == eRecordTypeData)
							{
								uint32_t newBlockIndex = (baseAddress + address) / kBlockSize;
								/*
								*	If the block changed THEN
								*	write the current block (if any) and
								*	initialize the new block data buffer.
								*/
								if (currentBlockIndex != newBlockIndex)
								{
									if (WriteBlock(data, currentBlockIndex))
									{
										currentBlockIndex = newBlockIndex;
										data = ClearBuffer();
									} else
									{
										Serial.print("?Failed writing data\n");
										status = eError;
										break;
									}
								}
								dataPtr = &data[address % kBlockSize];
								/*
								*	For whatever the choosen page size in
								*	SerialHexLoader, a hex line must stay within
								*	the current page.
								*
								*	If this line spans two pages THEN
								*	fail.
								*	This can happen if the hex file was created
								*	with a larger page size than kBlockSize.
								*/
								if ((&dataPtr[byteCount] - data) > kBlockSize)
								{
									Serial.print("?Line spans two pages\n");
									status = eError;
									break;
								}
							} else if (recordType == eRecordTypeExLinAddr)
							{
								address = 0;	// The data contains the address
								if (byteCount != 2)
								{
									Serial.print("?byteCount for RecordTypeExLinAddr not 2\n");
									status = eError;
								}
							} else if (recordType == eRecordTypeEOF)
							{
								state++;	// Skip eGetData
							} else
							{
								Serial.print("?Unsupported type\n");
								status = eError;
							}
							continue;
						case eGetData:
							if (recordType == eRecordTypeData)
							{
								dataPtr[dataIndex] = thisByte;
							} else
							{
								address = (address << 8) + thisByte;
							}
							dataIndex++;
							if (dataIndex < byteCount)
							{
								continue;
							}
							state++;
							continue;
						case eGetChecksum:
							if (checksum == 0)
							{
								state = 0;
								if (recordType == eRecordTypeExLinAddr)
								{
									baseAddress = address << 16;
								} else if (recordType == eRecordTypeEOF)
								{
									status = eDone;
								}
								Serial.write('*');
								break;
							}
							Serial.print("?Checksum error\n");
							status = eError;
							break;
					}
					break;
				} else
				{
					thisByte = HexAsciiToBin(thisChar);
				}
			}
		}
	}
	if (status == eDone)
	{
		WriteBlock(data, currentBlockIndex);
		Serial.print("* success!\n");
	}
	// Clean out the rest of the serial buffer, if any
	delay(1000);
	while (Serial.available())
	{
		Serial.read();
	}
}