//
//  MiscTools.m
//  EFI Agent
//
//  Created by Ben Baker on 1/29/19.
//  Copyright © 2019 Ben Baker. All rights reserved.
//

#include "MiscTools.h"
#include <CoreFoundation/CoreFoundation.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <sys/stat.h>
#include <poll.h>
#include "Authorization.h"

bool launchCommand(NSString *launchPath, NSArray *arguments, NSString **stdoutString)
{
	@try
	{
		NSPipe *pipe = [NSPipe pipe];
		NSFileHandle *file = pipe.fileHandleForReading;
		
		NSTask *task = [[NSTask alloc] init];
		task.currentDirectoryPath = @"/";
		task.launchPath = launchPath;
		task.arguments = arguments;
		task.standardOutput = pipe;
		
		[task launch];
		NSMutableData *data = [[file readDataToEndOfFile] mutableCopy];
		[task waitUntilExit];
		
		[data appendData:[file readDataToEndOfFile]];
		[file closeFile];
		
		[task release];
		
		*stdoutString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	@catch (NSException *ex)
	{
		return false;
	}
	
	return true;
}

bool launchCommandAsAdmin(NSString *launchPath, NSArray *arguments, NSString **stdoutString)
{
	OSStatus status = 0;
	AuthorizationRef authorization = NULL;
	
	if ((status = getAuthorization(&authorization)) != errAuthorizationSuccess)
		return status;
	
	AuthorizationItem adminAuthorization = { "system.privilege.admin", 0, NULL, 0 };
	AuthorizationRights rightSet = { 1, &adminAuthorization };
	
	status = AuthorizationCopyRights(authorization, &rightSet, kAuthorizationEmptyEnvironment, kAuthorizationFlagPreAuthorize | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights, NULL);
	
	callAuthorizationGrantedCallback(status);
	
	if (status != errAuthorizationSuccess)
		return false;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	FILE *pipe = NULL;
	NSUInteger count = [arguments count];
	char **args = (char **)calloc(count + 1, sizeof(char *));
	uint32_t i;
	
	for(i = 0; i < count; i++)
		args[i] = (char *)[arguments[i] UTF8String];
	
	args[i] = NULL;
	
	status = AuthorizationExecuteWithPrivileges(authorization, [launchPath UTF8String], kAuthorizationFlagDefaults, args, &pipe);
	
	free(args);
	
	[pool drain];
	
	if (status == errAuthorizationSuccess)
		getStdioOutput(pipe, stdoutString, true);
	
	return (status == errAuthorizationSuccess);
}

// https://svn.ajdeveloppement.org/ajcommons/branches/1.1/c-src/MacOSXAuthProcess.c
bool launchCommandAsAdmin(NSString *launchPath, NSArray *arguments, NSString **stdoutString, NSString **stderrString)
{
	OSStatus status;
	*stdoutString = nil;
	*stderrString = nil;
	char stdoutPath[] = "/tmp/AuthorizationExecuteWithPrivilegesXXXXXXX.stdout";
	char stderrPath[] = "/tmp/AuthorizationExecuteWithPrivilegesXXXXXXX.stderr";
	char command[1024];
	const char **args;
	int i;
	int stdoutFd = 0, stderrFd = 0;
	pid_t pid = 0;
	
	AuthorizationRef authorization = NULL;
	
	if ((status = getAuthorization(&authorization)) != errAuthorizationSuccess)
		return status;
	
	AuthorizationItem adminAuthorization = { "system.privilege.admin", 0, NULL, 0 };
	AuthorizationRights rightSet = { 1, &adminAuthorization };
	
	status = AuthorizationCopyRights(authorization, &rightSet, kAuthorizationEmptyEnvironment, kAuthorizationFlagPreAuthorize | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights, NULL);
	
	callAuthorizationGrantedCallback(status);
	
	if (status != errAuthorizationSuccess)
		return false;
	
	// Create temporary file for stdout
	{
		stdoutFd = mkstemps(stdoutPath, strlen(".stdout"));
		
		// create a pipe on that path
		close(stdoutFd);
		unlink(stdoutPath);
		
		if (mkfifo(stdoutPath, S_IRWXU | S_IRWXG) != 0)
			return false;
		
		if (stdoutFd < 0)
			return false;
	}
	
	// Create temporary file for stderr
	{
		stderrFd = mkstemps(stderrPath, strlen(".stderr"));
		
		// create a pipe on that path
		close(stderrFd);
		unlink(stderrPath);
		
		if (mkfifo(stderrPath, S_IRWXU | S_IRWXG) != 0)
			return false;
		
		if (stderrFd < 0)
			return false;
	}
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Create command to be executed
	args = (const char **)malloc(sizeof(char *)*(arguments.count + 5));
	args[0] = "-c";
	snprintf(command, sizeof(command), "echo $$; \"$@\" 1>%s 2>%s", stdoutPath, stderrPath);
	args[1] = command;
	args[2] = "";
	args[3] = (char *)[launchPath UTF8String];
	
	for (i = 0; i < arguments.count; ++i)
		args[i + 4] = [arguments[i] UTF8String];
	
	args[arguments.count + 4] = 0;
	
	// for debugging: log the executed command
	//printf ("/bin/sh"); for (i = 0; args[i] != 0; ++i) { printf (" \"%s\"", args[i]); } printf ("\n");
	
	FILE *commPipe;
	
	// Execute command
	status = AuthorizationExecuteWithPrivileges(authorization, "/bin/sh",  kAuthorizationFlagDefaults, (char **)args, &commPipe);
	
	free(args);
	
	[pool drain];
	
	if (status != noErr)
	{
		unlink(stdoutPath);
		unlink(stderrPath);
		return false;
	}
	
	// Read the first line of stdout => it's the pid
	{
		NSMutableString *stdoutMutableString = [NSMutableString string];
		stdoutFd = fileno(commPipe);
		char ch = 0;
		
		while ((read(stdoutFd, &ch, sizeof(ch)) == 1) && (ch != '\n'))
			[stdoutMutableString appendFormat:@"%c", ch];
		
		if (ch != '\n')
		{
			// we shouldn't get there
			unlink (stdoutPath);
			unlink (stderrPath);
			
			return false;
		}
		
		pid = [stdoutMutableString intValue];
		
		close(stdoutFd);
	}
	
	stdoutFd = open(stdoutPath, O_RDONLY, 0);
	stderrFd = open(stderrPath, O_RDONLY, 0);
	
	unlink(stdoutPath);
	unlink(stderrPath);
	
	if (stdoutFd < 0 || stderrFd < 0)
	{
		close(stdoutFd);
		close(stderrFd);
		
		return false;
	}
	
	int outFlags = fcntl(stdoutFd, F_GETFL);
	int errFlags = fcntl(stderrFd, F_GETFL);
	fcntl(stdoutFd, F_SETFL, outFlags | O_NONBLOCK);
	fcntl(stderrFd, F_SETFL, errFlags | O_NONBLOCK);
	
	NSMutableString *stdoutMutableString = [NSMutableString string];
	NSMutableString *stderrMutableString = [NSMutableString string];
	char ch = 0;
	int stat = 0, retval = 0;
	struct pollfd stdoutPollFd, stderrPollFd;
	stdoutPollFd.fd = stdoutFd;
	stdoutPollFd.events = POLLIN;
	stderrPollFd.fd = stderrFd;
	stderrPollFd.events = POLLIN;
	
	while (waitpid(pid, &stat, WNOHANG) != pid)
	{
		if ((retval = poll(&stdoutPollFd, 1, 100)) > 0)
		{
			if (stdoutPollFd.revents & POLLIN)
			{
				while (read(stdoutFd, &ch, sizeof(ch)) == 1)
					[stdoutMutableString appendFormat:@"%c", ch];
			}
		}
		
		if ((retval = poll(&stderrPollFd, 1, 100)) > 0)
		{
			if (stderrPollFd.revents & POLLIN)
			{
				while (read(stderrFd, &ch, sizeof(ch)) == 1)
					[stderrMutableString appendFormat:@"%c", ch];
			}
		}
		
		//if (WIFEXITED(stat) || WIFSIGNALED(stat) || WIFSTOPPED(stat))
		//	break;
	}
	
	if ((retval = poll(&stdoutPollFd, 1, 100)) > 0)
	{
		if (stdoutPollFd.revents & POLLIN)
		{
			while (read(stdoutFd, &ch, sizeof(ch)) == 1)
				[stdoutMutableString appendFormat:@"%c", ch];
		}
	}
	
	if ((retval = poll(&stderrPollFd, 1, 100)) > 0)
	{
		if (stderrPollFd.revents & POLLIN)
		{
			while (read(stderrFd, &ch, sizeof(ch)) == 1)
				[stderrMutableString appendFormat:@"%c", ch];
		}
	}
	
	*stdoutString = [NSString stringWithString:stdoutMutableString];
	*stderrString = [NSString stringWithString:stderrMutableString];
	
	close(stdoutFd);
	close(stderrFd);
	
	return true;
}

NSString *getBase64String(uint32_t uint32Value)
{
	NSMutableData *uint32Data = [NSMutableData new];
	[uint32Data appendBytes:&uint32Value length:sizeof(uint32Value)];
	NSString *uint32Base64 = [uint32Data base64EncodedStringWithOptions:0];
	[uint32Data release];
	
	return uint32Base64;
}

NSData *getNSDataUInt32(uint32_t uint32Value)
{
	return [NSData dataWithBytes:&uint32Value length:sizeof(uint32Value)];
}

NSString *getByteString(uint32_t uint32Value)
{
	return [NSString stringWithFormat:@"0x%02X, 0x%02X, 0x%02X, 0x%02X", uint32Value & 0xFF, (uint32Value >> 8) & 0xFF, (uint32Value >> 16) & 0xFF, (uint32Value >> 24) & 0xFF];
}

NSMutableString *getByteString(NSData *data)
{
	return getByteString(data, true, true);
}

NSMutableString *getByteString(NSData *data, bool insertComma, bool prefix0x)
{
	NSMutableString *result = [NSMutableString string];
	
	const char *bytes = (const char *)[data bytes];
	
	for (int i = 0; i < [data length]; i++)
	{
		if (i > 0)
			[result appendString:insertComma ? @", " : @" "];
		
		[result appendFormat:@"%@%02X", prefix0x ? @"0x" : @"", (unsigned char)bytes[i]];
	}
	
	return result;
}

NSString *getTempPath()
{
	NSBundle *mainBundle = [NSBundle mainBundle];
	NSDictionary *infoDictionary = [mainBundle infoDictionary];
	NSString *bundleIdentifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];
	NSString *tempDirectoryPath = nil;
	NSString *tempDirectoryTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.XXXXXX", bundleIdentifier]];
	const char *tempDirectoryTemplateCString = [tempDirectoryTemplate fileSystemRepresentation];
	char *tempDirectoryNameCString = (char *)malloc(strlen(tempDirectoryTemplateCString) + 1);
	strcpy(tempDirectoryNameCString, tempDirectoryTemplateCString);
	
	char *result = mkdtemp(tempDirectoryNameCString);
	
	if (result)
		tempDirectoryPath = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempDirectoryNameCString length:strlen(result)];
	
	free(tempDirectoryNameCString);
	
	return tempDirectoryPath;
}

string replaceAll(string& str, const string& from, const string& to)
{
	if(from.empty())
		return string(from);
	
	string ret = string(str);
	size_t start_pos = 0;
	
	while((start_pos = ret.find(from, start_pos)) != string::npos)
	{
		ret.replace(start_pos, from.length(), to);
		start_pos += to.length();
	}
	
	return ret;
}

bool getUInt32PropertyValue(MainViewController *mainViewController, NSDictionary *propertyDictionary, NSString *propertyName, uint32_t *propertyValue)
{
	NSData *propertyData = [propertyDictionary objectForKey:propertyName];
	
	if (propertyData == nil)
		return false;
	
	//return CFSwapInt32BigToHost(*(uint32_t *)([propertyData bytes]));
	*propertyValue = *(uint32_t *)([propertyData bytes]);
	
	return true;
}

bool applyFindAndReplacePatch(NSData *findData, NSData *replaceData, uint8_t *findAddress, uint8_t *replaceAddress, size_t maxSize, uint32_t count)
{
	bool r = false;
	size_t i = 0, patchCount = 0, patchLength = MIN([findData length], [replaceData length]);
	uint8_t *startAddress = findAddress;
	uint8_t *endAddress = findAddress + maxSize - patchLength;
	uint8_t *startReplaceAddress = replaceAddress;
	
	while (startAddress < endAddress)
	{
		for (i = 0; i < patchLength; i++)
		{
			if (startAddress[i] != static_cast<const uint8_t *>([findData bytes])[i])
				break;
		}
		
		if (i == patchLength)
		{
			for (i = 0; i < patchLength; i++)
				startReplaceAddress[i] = static_cast<const uint8_t *>([replaceData bytes])[i];
			
			r = true;
			
			if (++patchCount >= count)
				break;
			
			startAddress += patchLength;
			startReplaceAddress += patchLength;
			continue;
		}
		
		startAddress++;
		startReplaceAddress++;
	}
	
	return r;
}

NSData *stringToData(NSString *dataString, int size)
{
	NSString *hexChars = @"0123456789abcdefABCDEF";
	NSCharacterSet *hexCharSet = [NSCharacterSet characterSetWithCharactersInString:hexChars];
	NSCharacterSet *invalidHexCharSet = [hexCharSet invertedSet];
	NSString *cleanDataString = [dataString stringByReplacingOccurrencesOfString:@"0x" withString:@""];
	cleanDataString = [[cleanDataString componentsSeparatedByCharactersInSet:invalidHexCharSet] componentsJoinedByString:@""];
	
	NSMutableData *result = [[NSMutableData alloc] init];
	
	for (int i = 0; i + size <= cleanDataString.length; i += size)
	{
		NSRange range = NSMakeRange(i, size);
		NSString *hexString = [cleanDataString substringWithRange:range];
		NSScanner *scanner = [NSScanner scannerWithString:hexString];
		unsigned int intValue;
		[scanner scanHexInt:&intValue];
		unsigned char uc = (unsigned char)intValue;
		[result appendBytes:&uc length:1];
	}
	
	NSData *resultData = [NSData dataWithData:result];
	[result release];
	
	return resultData;
}

NSData *stringToData(NSString *dataString)
{
	return stringToData(dataString, 2);
}

NSString *decimalToBinary(unsigned long long integer)
{
	NSString *string = @"" ;
	unsigned long long x = integer;
	do
	{
		string = [[NSString stringWithFormat: @"%llu", x & 1] stringByAppendingString:string];
	}
	while (x >>= 1);
	
	return string;
}

unsigned long long binaryToDecimal(NSString *str)
{
	double j = 0;
	
	for(int i = 0; i < [str length]; i++)
	{
		if ([str characterAtIndex:i] == '1')
			j = j+ pow(2, [str length] - 1 - i);
	}
	
	return (unsigned long long) j;
}

NSString *appendSuffixToPath(NSString *path, NSString *suffix)
{
	NSString *containingFolder = [path stringByDeletingLastPathComponent];
	NSString *fullFileName = [path lastPathComponent];
	NSString *fileExtension = [fullFileName pathExtension];
	NSString *fileName = [fullFileName stringByDeletingPathExtension];
	NSString *newFileName = [fileName stringByAppendingString:suffix];
	NSString *newFullFileName = [newFileName stringByAppendingPathExtension:fileExtension];
	
	return [containingFolder stringByAppendingPathComponent:newFullFileName];
}

bool getStdioOutput(FILE *pipe, NSString **stdoutString, bool waitForExit)
{
	int stat = 0;
	int pipeFD = fileno(pipe);

	if (pipeFD <= 0)
		return false;
	
	if (waitForExit)
	{
		pid_t pid = fcntl(pipeFD, F_GETOWN, 0);
		while ((pid = waitpid(pid, &stat, WNOHANG)) == 0);
	}
	
	NSFileHandle *stdoutHandle = [[NSFileHandle alloc] initWithFileDescriptor:pipeFD closeOnDealloc:YES];
	NSData *stdoutData = [stdoutHandle readDataToEndOfFile];
	NSMutableData *stdoutMutableData = [NSMutableData dataWithData:stdoutData];
	((char *)[stdoutMutableData mutableBytes])[[stdoutData length] - 1] = '\0';
	*stdoutString = [NSString stringWithCString:(const char *)[stdoutMutableData bytes] encoding:NSASCIIStringEncoding];
	[stdoutHandle release];
	
	return true;
}

uint32_t getUInt32FromData(NSData *data)
{
	if (data == nil)
		return 0;
	
	if ([data length] != 4)
		return 0;
	
	return *(const uint32_t *)[data bytes];
}

NSColor *getColorAlpha(NSColor *color, float alpha)
{
	NSColor *resultColor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	return [NSColor colorWithRed:resultColor.redComponent green:resultColor.greenComponent blue:resultColor.blueComponent alpha:alpha];
}

bool getRegExArray(NSString *regExPattern, NSString *valueString, uint32_t itemCount, NSMutableArray **itemArray)
{
	NSError *regError = nil;
	NSRegularExpression *regEx = [NSRegularExpression regularExpressionWithPattern:regExPattern options:NSRegularExpressionCaseInsensitive error:&regError];
	
	if (regError)
		return false;
	
	NSTextCheckingResult *match = [regEx firstMatchInString:valueString options:0 range:NSMakeRange(0, [valueString length])];
	
	if (match == nil || [match numberOfRanges] != itemCount + 1)
		return false;
	
	*itemArray = [NSMutableArray array];
	
	for (int i = 1; i < match.numberOfRanges; i++)
		[*itemArray addObject:[valueString substringWithRange:[match rangeAtIndex:i]]];
	
	return true;
}

uint32_t getInt(NSString *valueString)
{
	uint32_t value;
	
	NSScanner *scanner = [NSScanner scannerWithString:valueString];
	[scanner scanInt:(int *)&value];
	
	return value;
}

uint32_t getHexInt(NSString *valueString)
{
	uint32_t value;
	
	NSScanner *scanner = [NSScanner scannerWithString:valueString];
	[scanner scanHexInt:&value];
	
	return value;
}

void sendNotificationTitle(id delegate, NSString *title, NSString *subtitle, NSString *text, NSString *actionButtonTitle, NSString *otherButtonTitle, bool hasActionButton)
{
	NSUserNotification *notification = [[NSUserNotification alloc] init];
	
	notification.title = title;
	notification.subtitle = subtitle;
	notification.soundName = NSUserNotificationDefaultSoundName;
	notification.informativeText = text;
	//notification.deliveryDate = deliveryDate;
	
	if(hasActionButton)
	{
		notification.hasActionButton = YES;
		notification.actionButtonTitle = actionButtonTitle;
		notification.otherButtonTitle = otherButtonTitle;
	}
	
	NSUserNotificationCenter *notificationCenter = [NSUserNotificationCenter defaultUserNotificationCenter];
	
	notificationCenter.delegate = delegate;
	
	[notificationCenter deliverNotification:notification];
	[notification release];
}

NSString *trimNewLine(NSString *string)
{
	NSRange newLineRange = [string rangeOfString:@"\n"];
	
	if (newLineRange.location == NSNotFound)
		return string;
	
	return [string substringToIndex:newLineRange.location];
}
