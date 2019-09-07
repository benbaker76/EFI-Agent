//
//  MiscTools.h
//  EFI Agent
//
//  Created by Ben Baker on 1/29/19.
//  Copyright © 2019 Ben Baker. All rights reserved.
//

#ifndef MiscTools_h
#define MiscTools_h

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import <stdio.h>
#import <string>

using std::string;

#define membersize(type, member) sizeof(((type *)0)->member)

template <class T, size_t N>
constexpr size_t arrsize(const T (&array)[N])
{
	return N;
}

bool launchCommand(NSString *launchPath, NSArray *arguments, NSString **stdoutString);
bool launchCommandAsAdmin(NSString *launchPath, NSArray *arguments, NSString **stdoutString);
bool launchCommandAsAdmin(NSString *launchPath, NSArray *arguments, NSString **stdoutString, NSString **stderrString);
NSData *getNSDataUInt32(uint32_t uint32Value);
NSString *getBase64String(uint32_t uint32Value);
NSString *getByteString(uint32_t uint32Value);
NSMutableString *getByteString(NSData *data);
NSMutableString *getByteString(NSData *data, bool insertComma, bool prefix0x);
NSString *getTempPath();
string replaceAll(string& str, const string& from, const string& to);
bool getUInt32PropertyValue(MainViewController *mainViewController, NSDictionary *propertyDictionary, NSString *propertyName, uint32_t *propertyValue);
bool applyFindAndReplacePatch(NSData *findData, NSData *replaceData, uint8_t *findAddress, uint8_t *replaceAddress, size_t maxSize, uint32_t count);
NSData *stringToData(NSString *dataString);
NSString *decimalToBinary(unsigned long long integer);
unsigned long long binaryToDecimal(NSString *str);
NSString *appendSuffixToPath(NSString *path, NSString *suffix);
bool getStdioOutput(FILE *pipe, NSString **stdoutString, bool waitForExit);
uint32_t getUInt32FromData(NSData *data);
NSColor *getColorAlpha(NSColor *color, float alpha);
bool getRegExArray(NSString *regExPattern, NSString *valueString, uint32_t itemCount, NSMutableArray **itemArray);
uint32_t getInt(NSString *valueString);
uint32_t getHexInt(NSString *valueString);
void sendNotificationTitle(id delegate, NSString *title, NSString *subtitle, NSString *text, NSString *actionButtonTitle, NSString *otherButtonTitle, bool hasActionButton);
NSString *trimNewLine(NSString *string);

#endif /* MiscTools_hpp */
