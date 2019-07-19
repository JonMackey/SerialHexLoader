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
*	IntelHex
*	
*	Created by Jon Mackey on 5/12/19.
*	Copyright © 2019 Jon Mackey. All rights reserved.
*/


#include "IntelHex.h"

// HEX_LINE_DATA_LEN was previously hard coded as 32.  32 results in a 76 byte
// hex line length that has the potential of overwriting the 64 byte Arduino
// serial ring buffer.  This is probably why the Arduino ISP uses 16 data bytes
// which results in a 44 byte hex line.
#define HEX_LINE_DATA_LEN	16

enum EIntelHexRecordType
{
	eRecordTypeData,		// 0
	eRecordTypeEOF,			// 1
	eRecordTypeExSegAddr,	// 2
	eRecordTypeStSegAddr,	// 3
	eRecordTypeExLinAddr,	// 4
	eRecordTypeStLinAddr	// 5
};


static const char kHexChars[] = "0123456789ABCDEF";
/******************************** Int8ToHexStr ********************************/
/*
*	Returns hex8 str with leading zeros (0x0 would return 00, 0x1 01)
*/
char* Int8ToHexStr(
	uint8_t	inNum,
	char*	inBuffer)
{
	char*	bufPtr = &inBuffer[1];
	for (; bufPtr >= inBuffer; bufPtr--)
	{
		*bufPtr =  kHexChars[inNum & 0xF];
		inNum >>= 4;
	}
	return(&inBuffer[2]);
}

/**************************** ToIntelHexLine **********************************/
// https://en.wikipedia.org/wiki/Intel_HEX
size_t ToIntelHexLine(
	const uint8_t*	inData,
	uint8_t			inDataLen,
	uint16_t		inAddress,
	uint8_t			inRecordType,
	char*			inLineBuffer)
{
	uint8_t	checksum = inDataLen;
	uint8_t	thisByte = 0;

	inLineBuffer[0] = ':';
	char* nextHexBytePtr = Int8ToHexStr(inDataLen, &inLineBuffer[1]);
	if (inRecordType != eRecordTypeExLinAddr)
	{
		thisByte = inAddress >> 8;
		nextHexBytePtr = Int8ToHexStr(thisByte, nextHexBytePtr);
		checksum += thisByte;
		thisByte = inAddress & 0xFF;
		nextHexBytePtr = Int8ToHexStr(thisByte, nextHexBytePtr);
		checksum += thisByte;
		nextHexBytePtr = Int8ToHexStr(inRecordType, nextHexBytePtr);
		checksum += inRecordType;
		for (uint8_t i = 0; i < inDataLen; i++)
		{
			thisByte = inData[i];
			nextHexBytePtr = Int8ToHexStr(thisByte, nextHexBytePtr);
			checksum += thisByte;
		}
	// Else it's record type 4, 'Extended Linear Address'
	} else
	{
		nextHexBytePtr = Int8ToHexStr(0, nextHexBytePtr);
		nextHexBytePtr = Int8ToHexStr(0, nextHexBytePtr);
		nextHexBytePtr = Int8ToHexStr(eRecordTypeExLinAddr, nextHexBytePtr);
		checksum += eRecordTypeExLinAddr;
		thisByte = inAddress >> 8;
		nextHexBytePtr = Int8ToHexStr(thisByte, nextHexBytePtr);
		checksum += thisByte;
		thisByte = inAddress & 0xFF;
		nextHexBytePtr = Int8ToHexStr(thisByte, nextHexBytePtr);
		checksum += thisByte;
	}
	nextHexBytePtr = Int8ToHexStr(-checksum, nextHexBytePtr);
	*(nextHexBytePtr++) = '\n';
	*nextHexBytePtr = 0;
	return(nextHexBytePtr-inLineBuffer);
}

/********************************* SaveToFile *********************************/
bool IntelHex::SaveToFile(
	const char*	inBinaryFilePath,
	uint32_t	inStartingAddress,
	bool		inOmitNullsWhenPossible,
	uint32_t	inPageSize,
	const char*	inHexFilePath)
{
	bool success = false;
	FILE*	binaryFile = fopen(inBinaryFilePath, "r");
	if (binaryFile)
	{
		fseek(binaryFile, 0, SEEK_END);
		long binaryFileLength = ftell(binaryFile);
		fseek(binaryFile, 0, SEEK_SET);
		uint8_t*	binaryBuffer = new uint8_t[binaryFileLength];
		fread(binaryBuffer, 1, binaryFileLength, binaryFile);
		FILE*    hexFile = fopen(inHexFilePath, "w");
		if (hexFile)
		{
			char		hexLine[(HEX_LINE_DATA_LEN * 2) + 14];
			uint32_t	hexAddress = inStartingAddress;
			uint32_t	upperAddress = 0;
			uint8_t*	dataPtr = binaryBuffer;
			uint8_t*	endDataPtr = &binaryBuffer[binaryFileLength];
			size_t		lineLength, dataLength;
			/*
			*	endOfHexBlockPtr is the pointer within the binaryBuffer relative
			*	to the end of the current 64K hex block containing the hexAddress.
			*/
			uint8_t*	endOfHexBlockPtr = &binaryBuffer[0x10000 - (hexAddress % 0x10000)];
			while (dataPtr < endDataPtr)
			{
				/*
				*	The Intel hex format address field is only 16 bits.  When the
				*	address moves to the next block of 65536 bytes you need to write
				*	an address record that all data records will offset from.
				*/
				upperAddress = hexAddress / 0x10000;
				if (upperAddress)
				{
					lineLength = ToIntelHexLine(NULL, 2, upperAddress, eRecordTypeExLinAddr, hexLine);
					fwrite(hexLine, 1, lineLength, hexFile);
				}
				if (endOfHexBlockPtr > endDataPtr)
				{
					endOfHexBlockPtr = endDataPtr;
				}
				while (dataPtr < endOfHexBlockPtr)
				{
					/*
					*	If omitting nulls THEN
					*	omit nulls by first skipping all leading nulls up till the end
					*	of the current page.  If a non-null is hit before the end of the page, then
					*	any run of 6 nulls will cause the line to break.  6 was choosen because
					*	it takes a minimum of 5 bytes as overhead for a new Intel hex line.
					*/
					if (inOmitNullsWhenPossible)
					{
						/*
						*	The page size is used only when nulls are being
						*	omitted.  bytesInPage is the number of bytes already
						*	in the page.  bytesInPage may be non-zero for
						*	the first page written.  All other starting
						*	addresses should be page aligned (bytesInPage = 0)
						*/
						uint32_t	bytesInPage = (hexAddress % inPageSize);
						uint8_t*	endOfPagePtr = &dataPtr[inPageSize - bytesInPage];
						if (endOfPagePtr > endOfHexBlockPtr)
						{
							endOfPagePtr = endOfHexBlockPtr;
						}
						// Write the hex lines, stopping at the page boundary
						uint8_t*	startPtr = endOfPagePtr;
						bool		entirePageIsNull = bytesInPage == 0;
						while (dataPtr < endOfPagePtr)
						{
							/*
							*	Skip leading nulls
							*/
							if (!*dataPtr)
							{
								dataPtr++;
								continue;
							}
							startPtr = dataPtr;
							uint8_t* endOfLinePtr = dataPtr + HEX_LINE_DATA_LEN;
							if (endOfLinePtr > endOfPagePtr)
							{
								endOfLinePtr = endOfPagePtr;
							}
							/*
							*	Break the line if a run of 6 nulls is found.
							*	This run may in fact be longer than 6, and
							*	that's OK, because the start of the next line
							*	will skip them (via Skip leading nulls above.)
							*/
							uint32_t	nullRunLen = 0;
							for (dataPtr++; dataPtr < endOfLinePtr; dataPtr++)
							{
								if (*dataPtr)
								{
									nullRunLen = 0;
									continue;
								}
								nullRunLen++;
								/*
								*	Only runs of 6 nulls is worth breaking a line.
								*/
								if (nullRunLen < 6)
								{
									continue;
								}
								dataPtr++;
								break;
							}
							dataLength = (dataPtr - startPtr) - nullRunLen;
							if (dataLength)
							{
								entirePageIsNull = false;
								lineLength = ToIntelHexLine(startPtr, dataLength,
												(uint32_t)(startPtr - binaryBuffer) + inStartingAddress,	// inAddress is a uint16_t, so this value will be truncated to 16 bits.
													eRecordTypeData, hexLine);
								fwrite(hexLine, 1, lineLength, hexFile);
							}
						}
						/*
						*	If the entire page is null THEN
						*	write a null single byte data line so that the
						*	interpreter will zero the entire page.
						*/
						if (entirePageIsNull)
						{
							uint8_t	nullByte = 0;
							lineLength = ToIntelHexLine(&nullByte, 1, hexAddress, eRecordTypeData, hexLine);
							fwrite(hexLine, 1, lineLength, hexFile);
						}
						hexAddress += (inPageSize - bytesInPage);
					/*
					*	Else, write a line of data
					*/
					} else
					{
						uint8_t*	endOfLinePtr = &dataPtr[HEX_LINE_DATA_LEN];
						if (endOfLinePtr > endOfHexBlockPtr)
						{
							endOfLinePtr = endOfHexBlockPtr;
						}
						dataLength = endOfLinePtr - dataPtr;
						if (dataLength)
						{
							lineLength = ToIntelHexLine(dataPtr, dataLength, hexAddress, eRecordTypeData, hexLine);
							fwrite(hexLine, 1, lineLength, hexFile);
						}
						dataPtr = endOfLinePtr;
						hexAddress += dataLength;
					}
				}
				endOfHexBlockPtr += 0x10000;
			}
			lineLength = ToIntelHexLine(dataPtr, 0, 0, eRecordTypeEOF, hexLine);
			fwrite(hexLine, 1, lineLength, hexFile);
			fclose(hexFile);
			success = true;
		}
		fclose(binaryFile);
	}
	return(success);
}
