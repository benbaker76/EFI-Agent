//
//  IORegTools.m
//  EFI Agent
//
//  Created by Ben Baker on 1/29/19.
//  Copyright © 2019 Ben Baker. All rights reserved.
//

#include "IORegTools.h"
#include "MiscTools.h"
#include <IOKit/IOBSD.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/graphics/IOGraphicsLib.h>

#define GetLocalizedString(key) \
[[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]

bool getIORegChild(io_service_t device, NSArray *nameArray, io_service_t *foundDevice, uint32_t *foundIndex, bool useClass, bool recursive)
{
	io_iterator_t childIterator;
	kern_return_t kr = IORegistryEntryCreateIterator(device, kIOServicePlane, (recursive ? kIORegistryIterateRecursively : 0), &childIterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t childDevice; IOIteratorIsValid(childIterator) && (childDevice = IOIteratorNext(childIterator)); IOObjectRelease(childDevice))
	{
		io_name_t name {};
		kr = (useClass ? IOObjectGetClass(childDevice, name) : IORegistryEntryGetName(childDevice, name));
		
		if (kr == KERN_SUCCESS)
		{
			for (int i = 0; i < [nameArray count]; i++)
			{
				if (CFStringCompare((__bridge CFStringRef)[NSString stringWithUTF8String:name], (__bridge CFStringRef)[nameArray objectAtIndex:i], 0) == kCFCompareEqualTo)
				{
					*foundDevice = childDevice;
					*foundIndex = i;
					
					IOObjectRelease(childIterator);
					
					return true;
				}
			}
		}
	}
	
	return false;
}

bool getIORegChild(io_service_t device, NSArray *nameArray, io_service_t *foundDevice, bool useClass, bool recursive)
{
	uint32_t foundIndex = 0;
	
	return getIORegChild(device, nameArray, foundDevice, &foundIndex, useClass, recursive);
}

bool getIORegParent(io_service_t device, NSString *name, io_service_t *foundDevice, bool recursive)
{
	io_iterator_t parentIterator;
	kern_return_t kr = IORegistryEntryCreateIterator(device, kIOServicePlane, (recursive ? kIORegistryIterateRecursively : 0) | kIORegistryIterateParents, &parentIterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t parentDevice; IOIteratorIsValid(parentIterator) && (parentDevice = IOIteratorNext(parentIterator)); IOObjectRelease(parentDevice))
	{
		if (IOObjectConformsTo(parentDevice, [name UTF8String]))
		{
			*foundDevice = parentDevice;
			
			IOObjectRelease(parentIterator);
			
			return true;
		}
	}
	
	return false;
}

bool getIORegParent(io_service_t device, NSArray *nameArray, io_service_t *foundDevice, uint32_t *foundIndex, bool useClass, bool recursive)
{
	io_iterator_t parentIterator;
	kern_return_t kr = IORegistryEntryCreateIterator(device, kIOServicePlane, (recursive ? kIORegistryIterateRecursively : 0) | kIORegistryIterateParents, &parentIterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t parentDevice; IOIteratorIsValid(parentIterator) && (parentDevice = IOIteratorNext(parentIterator)); IOObjectRelease(parentDevice))
	{
		io_name_t name {};
		kr = (useClass ? IOObjectGetClass(parentDevice, name) : IORegistryEntryGetName(parentDevice, name));
		
		if (kr == KERN_SUCCESS)
		{
			for (int i = 0; i < [nameArray count]; i++)
			{
				if (CFStringCompare((__bridge CFStringRef)[NSString stringWithUTF8String:name], (__bridge CFStringRef)[nameArray objectAtIndex:i], 0) == kCFCompareEqualTo)
				{
					*foundDevice = parentDevice;
					*foundIndex = i;
					
					IOObjectRelease(parentIterator);
					
					return true;
				}
			}
		}
	}
	
	return false;
}

bool getIORegParent(io_service_t device, NSArray *nameArray, io_service_t *foundDevice, bool useClass, bool recursive)
{
	uint32_t foundIndex = 0;
	
	return getIORegParent(device, nameArray, foundDevice, &foundIndex, useClass, recursive);
}

bool getAPFSPhysicalStoreBSDName(NSString *mediaUUID, NSString **bsdName)
{
	io_iterator_t iterator;
	
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleAPFSContainer"), &iterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t device; IOIteratorIsValid(iterator) && (device = IOIteratorNext(iterator)); IOObjectRelease(device))
	{
		CFMutableDictionaryRef propertyDictionaryRef = 0;
		
		kr = IORegistryEntryCreateCFProperties(device, &propertyDictionaryRef, kCFAllocatorDefault, kNilOptions);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		NSDictionary *propertyDictionary = (__bridge NSDictionary *)propertyDictionaryRef;
			
		NSString *uuid = [propertyDictionary objectForKey:@"UUID"];
		
		if (uuid == nil || ![uuid isEqualToString:mediaUUID])
			continue;
			
		io_service_t parentDevice;
			
		if (getIORegParent(device, @[@"IOMedia"], &parentDevice, true, true))
		{
			CFMutableDictionaryRef parentPropertyDictionaryRef = 0;
			
			kr = IORegistryEntryCreateCFProperties(parentDevice, &parentPropertyDictionaryRef, kCFAllocatorDefault, kNilOptions);
			
			if (kr == KERN_SUCCESS)
			{
				NSMutableDictionary *parentPropertyDictionary = (__bridge NSMutableDictionary *)parentPropertyDictionaryRef;
				
				*bsdName = [parentPropertyDictionary objectForKey:@"BSD Name"];
				
				IOObjectRelease(parentDevice);
				IOObjectRelease(device);
				IOObjectRelease(iterator);
				
				return true;
			}
			
			IOObjectRelease(parentDevice);
		}
	}
	
	IOObjectRelease(iterator);
	
	return false;
}

bool getIORegUSBPropertyDictionaryArray(NSMutableArray **propertyDictionaryArray)
{
	*propertyDictionaryArray = [NSMutableArray array];
	io_iterator_t iterator;
	
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleUSBHostPort"), &iterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t device; IOIteratorIsValid(iterator) && (device = IOIteratorNext(iterator)); IOObjectRelease(device))
	{
		io_name_t name {};
		kr = IORegistryEntryGetName(device, name);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		io_name_t className {};
		kr = IOObjectGetClass(device, className);
		
		if (kr != KERN_SUCCESS)
			continue;

		bool isHubPort = IOObjectConformsTo(device, "AppleUSBHubPort");
		bool isInternalHubPort = IOObjectConformsTo(device, "AppleUSBInternalHubPort");
		bool hubDeviceFound = false;
		uint32_t hubLocationID = 0;
		io_service_t hubDevice;
		io_name_t hubName {};
		
		if (isHubPort || isInternalHubPort)
		{
			if (getIORegParent(device, @"IOUSBDevice", &hubDevice, true))
			{
				kr = IORegistryEntryGetName(hubDevice, hubName);
				
				if (kr == KERN_SUCCESS)
				{
					CFTypeRef locationID = IORegistryEntrySearchCFProperty(hubDevice, kIOServicePlane, CFSTR("locationID"), kCFAllocatorDefault, kNilOptions);
					
					if (locationID)
					{
						// HUB1: (locationID == 0x1D100000)
						// HUB2: (locationID == 0x1A100000)
						hubLocationID = [(__bridge NSNumber *)locationID unsignedIntValue];
						
						CFRelease(locationID);
						
						hubDeviceFound = true;
					}
				}
				
				IOObjectRelease(hubDevice);
			}
		}
		
		io_service_t parentDevice;
		
		if (getIORegParent(device, @"IOPCIDevice", &parentDevice, true))
		{
			io_name_t parentName {};
			kr = IORegistryEntryGetName(parentDevice, parentName);
			
			if (kr == KERN_SUCCESS)
			{
				CFMutableDictionaryRef parentPropertyDictionaryRef = 0;
				
				kr = IORegistryEntryCreateCFProperties(parentDevice, &parentPropertyDictionaryRef, kCFAllocatorDefault, kNilOptions);
				
				if (kr == KERN_SUCCESS)
				{
					NSMutableDictionary *parentPropertyDictionary = (__bridge NSMutableDictionary *)parentPropertyDictionaryRef;
					
					CFMutableDictionaryRef propertyDictionaryRef = 0;
					
					kr = IORegistryEntryCreateCFProperties(device, &propertyDictionaryRef, kCFAllocatorDefault, kNilOptions);
					
					if (kr == KERN_SUCCESS)
					{
						NSMutableDictionary *propertyDictionary = (__bridge NSMutableDictionary *)propertyDictionaryRef;
						
						NSString *portName = [propertyDictionary objectForKey:@"name"];
						NSData *deviceID = [parentPropertyDictionary objectForKey:@"device-id"];
						NSData *vendorID = [parentPropertyDictionary objectForKey:@"vendor-id"];
						
						if (portName == nil)
							[propertyDictionary setValue:[NSString stringWithUTF8String:name] forKey:@"name"];
						
						uint32_t deviceIDInt = getUInt32FromData(deviceID);
						uint32_t vendorIDInt = getUInt32FromData(vendorID);
						
						[propertyDictionary setValue:[NSString stringWithUTF8String:parentName] forKey:@"UsbController"];
						[propertyDictionary setValue:[NSNumber numberWithInt:(deviceIDInt << 16) | vendorIDInt] forKey:@"UsbControllerID"];
						
						if (hubDeviceFound)
						{
							[propertyDictionary setValue:[NSString stringWithUTF8String:hubName] forKey:@"HubName"];
							[propertyDictionary setValue:[NSNumber numberWithInt:hubLocationID] forKey:@"HubLocation"];
						}
						
						[*propertyDictionaryArray addObject:propertyDictionary];
					}
				}
			}
			
			IOObjectRelease(parentDevice);
		}
	}
	
	IOObjectRelease(iterator);
	
	return ([*propertyDictionaryArray count] > 0);
}

bool getIORegPropertyDictionaryArray(NSString *serviceName, NSString *entryName, NSArray *classNameArray, NSMutableDictionary **propertyDictionary)
{
	*propertyDictionary = [NSMutableDictionary dictionary];
	io_iterator_t iterator;
	
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching([serviceName UTF8String]), &iterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t device; IOIteratorIsValid(iterator) && (device = IOIteratorNext(iterator)); IOObjectRelease(device))
	{
		io_name_t name {};
		kr = IORegistryEntryGetName(device, name);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		if (CFStringCompare((__bridge CFStringRef)[NSString stringWithUTF8String:name], (__bridge CFStringRef)entryName, 0) != kCFCompareEqualTo)
			continue;
		
		io_iterator_t childIterator;
		
		kr = IORegistryEntryGetChildIterator(device, kIOServicePlane, &childIterator);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		for (io_service_t childDevice; IOIteratorIsValid(childIterator) && (childDevice = IOIteratorNext(childIterator)); IOObjectRelease(childDevice))
		{
			io_name_t childName {};
			kr = IOObjectGetClass(childDevice, childName);
			
			if (kr != KERN_SUCCESS)
				continue;
			
			bool classFound = false;
			
			for (int i = 0; i < [classNameArray count]; i++)
			{
				if (CFStringCompare((__bridge CFStringRef)[NSString stringWithUTF8String:childName], (__bridge CFStringRef)[classNameArray objectAtIndex:i], 0) == kCFCompareEqualTo)
				{
					classFound = true;
					
					break;
				}
			}
			
			if (!classFound)
				continue;
			
			CFMutableDictionaryRef propertyDictionaryRef = 0;
			
			kr = IORegistryEntryCreateCFProperties(childDevice, &propertyDictionaryRef, kCFAllocatorDefault, kNilOptions);
			
			if (kr != KERN_SUCCESS)
				continue;
			
			*propertyDictionary = (__bridge NSMutableDictionary *)propertyDictionaryRef;
			
			IOObjectRelease(childIterator);
			IOObjectRelease(childDevice);
			IOObjectRelease(iterator);
			IOObjectRelease(device);
			
			return (*propertyDictionary != nil);
		}
	}
	
	IOObjectRelease(iterator);
	
	return false;
}

bool getIORegPropertyDictionaryArray(io_service_t device, NSMutableArray **propertyDictionaryArray, bool recursive)
{
	kern_return_t kr;
	io_iterator_t childIterator;
	
	kr = IORegistryEntryGetChildIterator(device, kIOServicePlane, &childIterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t childDevice; IOIteratorIsValid(childIterator) && (childDevice = IOIteratorNext(childIterator)); IOObjectRelease(childDevice))
	{
		if (recursive)
			getIORegPropertyDictionaryArray(childDevice, propertyDictionaryArray, recursive);
		
		CFMutableDictionaryRef propertyDictionaryRef = 0;
		
		kr = IORegistryEntryCreateCFProperties(childDevice, &propertyDictionaryRef, kCFAllocatorDefault, kNilOptions);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		NSDictionary *propertyDictionary = (__bridge NSDictionary *)propertyDictionaryRef;
		
		[*propertyDictionaryArray addObject:propertyDictionary];
	}
	
	return true;
}

bool getIORegPropertyDictionaryArray(NSString *serviceName, NSMutableArray **propertyDictionaryArray, bool recursive)
{
	*propertyDictionaryArray = [NSMutableArray array];
	io_iterator_t iterator;
	
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching([serviceName UTF8String]), &iterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t device; IOIteratorIsValid(iterator) && (device = IOIteratorNext(iterator)); IOObjectRelease(device))
		getIORegPropertyDictionaryArray(device, propertyDictionaryArray, recursive);
	
	IOObjectRelease(iterator);
	
	return ([*propertyDictionaryArray count] > 0);
}

bool getIORegPropertyDictionaryArray(NSString *serviceName, NSMutableArray **propertyDictionaryArray)
{
	return getIORegPropertyDictionaryArray(serviceName, propertyDictionaryArray, false);
}

bool getIORegPropertyDictionary(NSString *serviceName, NSArray *entryNameArray, NSMutableDictionary **propertyDictionary, uint32_t *foundIndex)
{
	io_iterator_t iterator;
	
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching([serviceName UTF8String]), &iterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t device; IOIteratorIsValid(iterator) && (device = IOIteratorNext(iterator)); IOObjectRelease(device))
	{
		io_name_t name {};
		kr = IORegistryEntryGetName(device, name);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		bool entryFound = false;
		
		for (int i = 0; i < [entryNameArray count]; i++)
		{
			if (CFStringCompare((__bridge CFStringRef)[NSString stringWithUTF8String:name], (__bridge CFStringRef)[entryNameArray objectAtIndex:i], 0) == kCFCompareEqualTo)
			{
				entryFound = true;
				*foundIndex = i;
				
				break;
			}
		}
		
		if (!entryFound)
			continue;
		
		CFMutableDictionaryRef propertyDictionaryRef = 0;
		
		kr = IORegistryEntryCreateCFProperties(device, &propertyDictionaryRef, kCFAllocatorDefault, kNilOptions);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		*propertyDictionary = (__bridge NSMutableDictionary *)propertyDictionaryRef;
		
		IOObjectRelease(iterator);
		IOObjectRelease(device);
		
		return true;
	}
	
	IOObjectRelease(iterator);
	
	return false;
}

bool getIORegPropertyDictionary(NSString *serviceName, NSString *entryName, NSMutableDictionary **propertyDictionary)
{
	io_iterator_t iterator;
	
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching([serviceName UTF8String]), &iterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t device; IOIteratorIsValid(iterator) && (device = IOIteratorNext(iterator)); IOObjectRelease(device))
	{
		io_name_t name {};
		kr = IORegistryEntryGetName(device, name);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		if (CFStringCompare((__bridge CFStringRef)[NSString stringWithUTF8String:name], (__bridge CFStringRef)entryName, 0) != kCFCompareEqualTo)
			continue;
		
		CFMutableDictionaryRef propertyDictionaryRef = 0;
		
		kr = IORegistryEntryCreateCFProperties(device, &propertyDictionaryRef, kCFAllocatorDefault, kNilOptions);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		*propertyDictionary = (__bridge NSMutableDictionary *)propertyDictionaryRef;
		
		IOObjectRelease(iterator);
		IOObjectRelease(device);
		
		return true;
	}
	
	IOObjectRelease(iterator);
	
	return false;
}

bool hasIORegEntry(NSString *path)
{
	io_registry_entry_t device = IORegistryEntryFromPath(kIOMasterPortDefault, [path UTF8String]);
	
	return (device != MACH_PORT_NULL);
}

bool hasACPIEntry(NSString *name)
{
	bool result = false;
	
	io_registry_entry_t device = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/AppleACPIPlatformExpert");
	
	if (device == MACH_PORT_NULL)
		return false;
	
	io_service_t foundDevice;
	
	result = getIORegChild(device, @[name], &foundDevice, false, true);

	IOObjectRelease(device);
	
	return result;
}

bool getIORegProperty(NSString *path, NSString *propertyName, CFTypeRef *property)
{
	*property = nil;
	io_registry_entry_t device = IORegistryEntryFromPath(kIOMasterPortDefault, [path UTF8String]);
	
	if (device == MACH_PORT_NULL)
		return false;
	
	*property = IORegistryEntryCreateCFProperty(device, (__bridge CFStringRef)propertyName, kCFAllocatorDefault, kNilOptions);
	
	IOObjectRelease(device);
	
	return (*property != nil);
}

bool getIORegProperties(NSString *path, NSMutableDictionary **propertyDictionary)
{
	*propertyDictionary = nil;
	io_registry_entry_t device = IORegistryEntryFromPath(kIOMasterPortDefault, [path UTF8String]);
	
	if (device == MACH_PORT_NULL)
		return false;
	
	CFMutableDictionaryRef propertyDictionaryRef = 0;
	
	kern_return_t kr = IORegistryEntryCreateCFProperties(device, &propertyDictionaryRef, kCFAllocatorDefault, kNilOptions);
	
	if (kr == KERN_SUCCESS)
		*propertyDictionary = (__bridge NSMutableDictionary *)propertyDictionaryRef;
	
	IOObjectRelease(device);
	
	return (*propertyDictionary != nil);
}

bool getIORegProperty(NSString *serviceName, NSString *entryName, NSString *propertyName, CFTypeRef *property)
{
	*property = nil;
	io_iterator_t iterator;
	
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching([serviceName UTF8String]), &iterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t device; IOIteratorIsValid(iterator) && (device = IOIteratorNext(iterator)); IOObjectRelease(device))
	{
		io_name_t name {};
		kr = IORegistryEntryGetName(device, name);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		if (CFStringCompare((__bridge CFStringRef)[NSString stringWithUTF8String:name], (__bridge CFStringRef)entryName, 0) != kCFCompareEqualTo)
			continue;
		
		*property = IORegistryEntrySearchCFProperty(device, kIOServicePlane, (__bridge CFStringRef)propertyName, kCFAllocatorDefault, kNilOptions);
		
		IOObjectRelease(iterator);
		IOObjectRelease(device);
		
		return (*property != nil);
	}
	
	IOObjectRelease(iterator);
	
	return false;
}

bool getVideoPerformanceStatisticsDictionary(CFMutableDictionaryRef *performanceStatisticsDictionary)
{
	io_iterator_t iterator;
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(kIOAcceleratorClassName), &iterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t device; IOIteratorIsValid(iterator) && (device = IOIteratorNext(iterator)); IOObjectRelease(device))
	{
		CFMutableDictionaryRef properties = NULL;
		kr = IORegistryEntryCreateCFProperties(device, &properties, kCFAllocatorDefault, (IOOptionBits)0);
		
		if (kr == KERN_SUCCESS)
		{
			*performanceStatisticsDictionary = (CFMutableDictionaryRef)CFDictionaryGetValue(properties, CFSTR("PerformanceStatistics"));
			
			if (*performanceStatisticsDictionary)
			{
				IOObjectRelease(iterator);
				IOObjectRelease(device);
				
				return true;
			}
		}
		
		if (properties)
			CFRelease(properties);
	}
	
	IOObjectRelease(iterator);
	
	return false;
}

bool getGPUModelAndVRAM(NSString **gpuModel, uint32_t &gpuDeviceID, uint32_t &gpuVendorID, mach_vm_size_t &vramSize, mach_vm_size_t &vramFree)
{
	*gpuModel = GetLocalizedString(@"Unknown");
	io_iterator_t iterator;
	kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCIDevice"), &iterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t device; IOIteratorIsValid(iterator) && (device = IOIteratorNext(iterator)); IOObjectRelease(device))
	{
		io_name_t name {};
		kr = IORegistryEntryGetName(device, name);
		
		if (kr != KERN_SUCCESS)
			continue;
		
		if (CFStringCompare((__bridge CFStringRef)[NSString stringWithUTF8String:name], CFSTR("IGPU"), 0) != kCFCompareEqualTo)
			continue;
		
		CFTypeRef model = IORegistryEntrySearchCFProperty(device, kIOServicePlane, CFSTR("model"), kCFAllocatorDefault, kNilOptions);
		
		if (model)
		{
			*gpuModel = [[NSString stringWithUTF8String:(const char *)[(__bridge NSData *)model bytes]] retain];
			
			CFRelease(model);
		}
		
		CFTypeRef deviceID = IORegistryEntrySearchCFProperty(device, kIOServicePlane, CFSTR("device-id"), kCFAllocatorDefault, kNilOptions);
		
		if (deviceID)
		{
			gpuDeviceID = *(const uint32_t *)CFDataGetBytePtr((__bridge CFDataRef)deviceID);
			
			CFRelease(deviceID);
		}
		
		CFTypeRef vendorID = IORegistryEntrySearchCFProperty(device, kIOServicePlane, CFSTR("vendor-id"), kCFAllocatorDefault, kNilOptions);
		
		if (vendorID)
		{
			gpuVendorID = *(const uint32_t *)CFDataGetBytePtr((__bridge CFDataRef)vendorID);
			
			CFRelease(vendorID);
		}
		
		_Bool valueInBytes = TRUE;
		CFTypeRef totalSize = IORegistryEntrySearchCFProperty(device, kIOServicePlane, CFSTR("VRAM,totalsize"), kCFAllocatorDefault, kIORegistryIterateRecursively);
		
		if (!totalSize)
		{
			valueInBytes = FALSE;
			totalSize = IORegistryEntrySearchCFProperty(device, kIOServicePlane, CFSTR("VRAM,totalMB"), kCFAllocatorDefault, kIORegistryIterateRecursively);
		}
		
		if (totalSize)
		{
			mach_vm_size_t size = 0;
			CFTypeID type = CFGetTypeID(totalSize);
			
			if (type == CFDataGetTypeID())
				vramSize = (CFDataGetLength((__bridge CFDataRef)totalSize) == sizeof(uint32_t) ? (mach_vm_size_t) *(const uint32_t *)CFDataGetBytePtr((__bridge CFDataRef)totalSize) : *(const uint64_t *)CFDataGetBytePtr((__bridge CFDataRef)totalSize));
			else if (type == CFNumberGetTypeID())
				CFNumberGetValue((__bridge CFNumberRef)totalSize, kCFNumberSInt64Type, &size);
			
			if (valueInBytes)
				vramSize >>= 20;
			
			CFRelease(totalSize);
		}
		
		CFMutableDictionaryRef performanceStatisticsDictionary = nil;
		
		if (getVideoPerformanceStatisticsDictionary(&performanceStatisticsDictionary))
		{
			CFNumberRef vramFreeBytes = (__bridge CFNumberRef)CFDictionaryGetValue(performanceStatisticsDictionary, CFSTR("vramFreeBytes"));
			
			if (vramFreeBytes)
				CFNumberGetValue(vramFreeBytes, kCFNumberSInt64Type, &vramFree);
		}
		
		IOObjectRelease(iterator);
		IOObjectRelease(device);
		
		return true;
	}
	
	IOObjectRelease(iterator);
	
	return false;
}

void getScreenInfoForDisplay(io_service_t service, NSString **displayName, SInt32 *vendorID, SInt32 *productID, SInt32 *serialNumber, NSData **edid, NSString **prefsKey)
{
	*displayName = GetLocalizedString(@"Unknown");
	
	CFDictionaryRef displayInfo = IODisplayCreateInfoDictionary(service, kIODisplayOnlyPreferredName);
	//CFStringRef displayNameRef = nil;
	CFNumberRef vendorIDRef = nil;
	CFNumberRef productIDRef = nil;
	CFNumberRef serialNumberRef = nil;
	CFDataRef edidRef = nil;
	CFStringRef prefsKeyRef = nil;
	CFDictionaryRef names = (CFDictionaryRef)CFDictionaryGetValue(displayInfo, CFSTR(kDisplayProductName));
	
	if (names && CFDictionaryGetCount(names) > 0)
	{
		NSDictionary *namesDictionary = (__bridge NSDictionary *)names;
		*displayName = [[namesDictionary valueForKey:namesDictionary.allKeys[0]] retain];
	}
	
	/* if (names && CFDictionaryGetValueIfPresent(names, CFSTR("en_US"), (const void **)&displayNameRef))
	{
		*displayName = [[NSString stringWithString:(__bridge NSString *)displayNameRef] retain];
	} */
	
	Boolean success;
	success = CFDictionaryGetValueIfPresent(displayInfo, CFSTR(kDisplayVendorID), (const void **)&vendorIDRef);
	success &= CFDictionaryGetValueIfPresent(displayInfo, CFSTR(kDisplayProductID), (const void **)&productIDRef);
	
	if (success)
	{
		CFNumberGetValue(vendorIDRef, kCFNumberSInt32Type, vendorID);
		CFNumberGetValue(productIDRef, kCFNumberSInt32Type, productID);
	}
	
	if (CFDictionaryGetValueIfPresent(displayInfo, CFSTR(kDisplaySerialNumber), (const void **)&serialNumberRef))
	{
		CFNumberGetValue(serialNumberRef, kCFNumberSInt32Type, serialNumber);
	}
	
	if (CFDictionaryGetValueIfPresent(displayInfo, CFSTR("IODisplayEDID"), (const void **)&edidRef))
	{
		*edid = [[NSData dataWithData:(__bridge NSData *)edidRef] retain];
	}
	
	if (CFDictionaryGetValueIfPresent(displayInfo, CFSTR("IODisplayPrefsKey"), (const void **)&prefsKeyRef))
	{
		*prefsKey = [[NSString stringWithString:(__bridge NSString *)prefsKeyRef] retain];
	}
	
	CFRelease(displayInfo);
}

bool hasIORegChildEntry(io_registry_entry_t device, NSString *findClassName)
{
	kern_return_t kr;
	io_iterator_t childIterator;
	
	kr = IORegistryEntryGetChildIterator(device, kIOServicePlane, &childIterator);
	
	if (kr != KERN_SUCCESS)
		return false;
	
	for (io_service_t childDevice; IOIteratorIsValid(childIterator) && (childDevice = IOIteratorNext(childIterator)); IOObjectRelease(childDevice))
	{
		io_name_t childName {};
		kr = IOObjectGetClass(childDevice, childName);
		
		if (kr == KERN_SUCCESS)
		{
			if (CFStringCompare((__bridge CFStringRef)findClassName, (__bridge CFStringRef)[NSString stringWithUTF8String:childName], 0) == kCFCompareEqualTo)
			{
				IOObjectRelease(childIterator);
				IOObjectRelease(childDevice);
				
				return true;
			}
		}
		
		if (hasIORegChildEntry(childDevice, findClassName))
		{
			IOObjectRelease(childIterator);
			IOObjectRelease(childDevice);
			
			return true;
		}
	}
	
	return false;
}

bool hasIORegClassEntry(NSString *findClassName)
{
	io_registry_entry_t device = IORegistryEntryFromPath(kIOMasterPortDefault, kIOServicePlane ":/");
	
	if (hasIORegChildEntry(device, findClassName))
	{
		IOObjectRelease(device);
		
		return true;
	}
	
	IOObjectRelease(device);
	
	return false;
}

bool getIORegString(NSString *service, NSString *name, NSString **value)
{
	io_service_t ioService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching([service UTF8String]));
	
	if (!ioService)
		return false;
	
	CFTypeRef data = IORegistryEntryCreateCFProperty(ioService, (__bridge CFStringRef)name, kCFAllocatorDefault, 0);
	
	IOObjectRelease(ioService);
	
	if (data == nil)
		return false;
	
	CFTypeID type = CFGetTypeID(data);
	
	if (type == CFStringGetTypeID())
	{
		*value = (__bridge NSString *)data;
		
		return true;
	}
	else if (type == CFDataGetTypeID())
		*value = [NSString stringWithUTF8String:(const char *)[(__bridge NSData *)data bytes]];

	CFRelease(data);
	
	return true;
}

bool getIORegArray(NSString *service, NSString *name, NSArray **value)
{
	io_service_t ioService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching([service UTF8String]));
	
	if (!ioService)
		return false;
	
	CFTypeRef data = IORegistryEntryCreateCFProperty(ioService, (__bridge CFStringRef)name, kCFAllocatorDefault, 0);
	
	IOObjectRelease(ioService);
	
	if (data == nil)
		return false;
	
	*value = (__bridge NSArray *)data;
	
	return true;
}

bool getIORegDictionary(NSString *service, NSString *name, NSDictionary **value)
{
	io_service_t ioService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching([service UTF8String]));
	
	if (!ioService)
		return false;
	
	CFTypeRef data = IORegistryEntryCreateCFProperty(ioService, (__bridge CFStringRef)name, kCFAllocatorDefault, 0);
	
	IOObjectRelease(ioService);
	
	if (data == nil)
		return false;
	
	*value = (__bridge NSDictionary *)data;
	
	return true;
}

bool getIORegPCIDeviceUInt32(NSString *pciName, NSString *propertyName, uint32_t *propertyValue)
{
	CFTypeRef property = nil;
	
	if (!getIORegProperty(@"IOPCIDevice", pciName, propertyName, &property))
		return false;
	
	*propertyValue = *(const uint32_t *)CFDataGetBytePtr((CFDataRef)property);
	
	CFRelease(property);
	
	return true;
}

bool getIORegPCIDeviceNSData(NSString *pciName, NSString *propertyName, NSData **propertyValue)
{
	CFTypeRef property = nil;
	
	if (!getIORegProperty(@"IOPCIDevice", pciName, propertyName, &property))
		return false;
	
	*propertyValue = (__bridge NSData *)property;
	
	CFRelease(property);
	
	return true;
}

bool getPlatformTableNative(NSData **nativePlatformTable)
{
	CFTypeRef property = nil;
	
	if (!getIORegProperty(@"IOService:/IOResources/WhateverGreen", @"platform-table-native", &property))
		return false;
	
	*nativePlatformTable = (__bridge NSData *)property;
	
	return true;
}

bool getPlatformTablePatched(NSData **patchedPlatformTable)
{
	CFTypeRef property = nil;
	
	if (!getIORegProperty(@"IOService:/IOResources/WhateverGreen", @"platform-table-patched", &property))
		return false;
	
	*patchedPlatformTable = (__bridge NSData *)property;
	
	return true;
}

bool getPlatformID(uint32_t *platformID)
{
	if (!getIORegPCIDeviceUInt32(@"IGPU", @"AAPL,ig-platform-id", platformID))
		if (!getIORegPCIDeviceUInt32(@"IGPU", @"AAPL,snb-platform-id", platformID))
			return false;
	
	return true;
}


