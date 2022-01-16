#include "Base64Str.h"

const char Base64Str::kDecodeTable[] = {
			-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
			-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
			-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63,
			52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1,  0, -1, -1,
			-1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
			15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1,
			-1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
			41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1
		};
		
const char Base64Str::kEncodeTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/******************************** Decode **********************************/
/*
*	Decode the data from the base 64 encoded string pointed to by inBase64Str.
*	The result is returned in outDecodedStr.
*/
const std::string& Base64Str::Decode(
	const std::string&	inBase64Str,
	std::string&		outDecodedStr)
{
	unsigned long	strLen = inBase64Str.size();
	outDecodedStr.clear();
	if (strLen >= 4)
	{
		const char*	encodedPtr = inBase64Str.c_str();
		const char*	encodedEndPtr = &encodedPtr[strLen];
		unsigned long	acc = 0;
		unsigned long	every4thCh = 0;
		unsigned long	eosHit = 0;
		bool			validBase64 = true;
		outDecodedStr.reserve(inBase64Str.size() *3 /4);
		for (; encodedPtr != encodedEndPtr; ++encodedPtr)
		{
			unsigned char uch = *encodedPtr;
			if (uch < 0x7B)
			{
				char udch = kDecodeTable[uch];
				if (udch >= 0)
				{
					if (!eosHit ||
						uch == '=')
					{
						every4thCh++;
						acc <<= 6;
						acc += kDecodeTable[uch];
						if ((every4thCh & 0x3) == 0)
						{
							outDecodedStr += (char)(acc>>16);
							outDecodedStr += (char)(acc>>8);
							outDecodedStr += (char)acc;
						}
						if (uch == '=')
						{
						//	fprintf(stderr, "every4thCh = 0x%lX\n", (every4thCh & 0x3));
							eosHit++;
							// Only allow for (2) end of string padding chars
							if (eosHit > 2)
							{
								validBase64 = false;
								break;
							}
						}
					} else
					{
						validBase64 = false;
						break;
					}
				} else if (isspace(uch))
				{
					continue;
				} else	// Invalid base64 character
				{
					validBase64 = false;
					break;
				}
			} else	// Invalid base64 character
			{
				validBase64 = false;
				break;
			}
		}
		if (validBase64)
		{
		//	fprintf(stderr, "E every4thCh = 0x%lX\n", (every4thCh & 0x3));
			switch (every4thCh & 0x3)
			{
				/*
				*	Cases 2 and 3 occur when the placeholder equates at the end
				*	of the string are omitted.  (Technically an error)
				*/
				case 0x2:
					outDecodedStr += (char)(acc>>4);
					break;
				case 0x3:
					outDecodedStr += (char)(acc>>10);
					outDecodedStr += (char)(acc>>2);
					break;
				default:
					if (eosHit)
					{
						// Remove the placeholder nulls added due to padding at
						// the end of the encoded string.
						outDecodedStr.resize(outDecodedStr.size()-eosHit);
					}
					break;
			}
		} else
		{
			outDecodedStr.assign("Invalid Base64");
		}
	}
	return(outDecodedStr);
}

/******************************** Encode ********************************/
/*
*	Base-64 encoding
*	The base-64 encoding packs three 8-bit bytes into four 7-bit ASCII characters.
*	If the number of bytes in the original data isn't divisable by three, "="
*	characters are used to pad the encoded data.
*/
const std::string& Base64Str::Encode(
	const std::string&	inStrToEncode,
	std::string&		outBase64Str)
{
	unsigned long	strLen = inStrToEncode.size();
	const unsigned char*	strPtr = (const unsigned char*)inStrToEncode.c_str();
	const unsigned char*	end3StrPtr = &strPtr[strLen - (strLen%3)];
	outBase64Str.clear();
	outBase64Str.reserve(strLen /3 *4 + (strLen % 3 ? 4 : 0));
	for (; strPtr != end3StrPtr; strPtr+=3)
	{
		outBase64Str += kEncodeTable[strPtr[0] >> 2];
		outBase64Str += kEncodeTable[((strPtr[0] << 4) + (strPtr[1] >> 4)) & 0x3f];
		outBase64Str += kEncodeTable[((strPtr[1] << 2) + (strPtr[2] >> 6)) & 0x3f];
		outBase64Str += kEncodeTable[(strPtr[2] & 0x3f)];
	}
	switch (strLen%3)
	{
		case 1:	// 1 odd byte remaining
			outBase64Str += kEncodeTable[strPtr[0]>>2];
			outBase64Str += kEncodeTable[(strPtr[0]<<4) & 0x30];
			outBase64Str +=  "==";
			break;
		case 2: // 2 odd bytes remaining
			outBase64Str += kEncodeTable[strPtr[0] >> 2];
			outBase64Str += kEncodeTable[((strPtr[0] << 4) + (strPtr[1] >> 4)) & 0x3f];
			outBase64Str += kEncodeTable[(strPtr[1] << 2) & 0x3c];
			outBase64Str +=  '=';
			break;
	}
	return(outBase64Str);
}
