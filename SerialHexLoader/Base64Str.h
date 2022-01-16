#ifndef __Base64Str__
#define __Base64Str__ 1
#include <string>

class Base64Str
{
public:
static const std::string&	Decode(
								const std::string&		inBase64Str,
								std::string&			outDecodedStr);
static const std::string&	Encode(
								const std::string&		inStrToEncode,
								std::string&			outBase64Str);
protected:
	static const char kDecodeTable[];
	static const char kEncodeTable[];
};

#endif
