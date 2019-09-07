//
//  IORegTools.h
//  EFI Agent
//
//  Created by Ben Baker on 1/29/19.
//  Copyright © 2019 Ben Baker. All rights reserved.
//

#ifndef IORegTools_h
#define IORegTools_h

#import "AppDelegate.h"

bool getAPFSPhysicalStoreBSDName(NSString *mediaUUID, NSString **bsdName);
bool getIORegUSBPropertyDictionaryArray(NSMutableArray **propertyDictionaryArray);
bool getIORegAudioDeviceArray(NSMutableArray **propertyDictionaryArray);
bool getIORegPropertyDictionary(NSString *serviceName, NSArray *entryNameArray, NSMutableDictionary **propertyDictionary, uint32_t *foundIndex);
bool getIORegPropertyDictionary(NSString *serviceName, NSString *entryName, NSMutableDictionary **propertyDictionary);
//bool getIORegPropertyDictionaryArray(NSString *serviceName, NSString *className, NSMutableArray **propertyDictionaryArray);
//bool getIORegPropertyDictionaryArray(NSArray *serviceNameArray, NSMutableArray **propertyDictionaryArray);
bool getIORegPropertyDictionaryArray(NSString *serviceName, NSString *entryName, NSArray *classNameArray, NSMutableDictionary **propertyDictionary);
bool getIORegPropertyDictionaryArray(NSString *serviceName, NSMutableArray **propertyDictionaryArray, bool recursive);
bool getIORegPropertyDictionaryArray(NSString *serviceName, NSMutableArray **propertyDictionaryArray);
bool getIORegPropertyDictionary(NSString *serviceName, NSString *entryName, NSMutableDictionary **propertyDictionary);
bool hasACPIEntry(NSString *name);
bool hasIORegEntry(NSString *path);
bool getIORegProperty(NSString *path, NSString *propertyName, CFTypeRef *property);
bool getIORegProperties(NSString *path, NSMutableDictionary **propertyDictionary);
bool getIORegProperty(NSString *serviceName, NSString *entryName, NSString *propertyName, CFTypeRef *property);
//CFTypeRef getUSBPortProperty(NSString *portName, NSString *propertyName, IOOptionBits options);
//bool getIORegPropertyChildren(NSString *serviceName, NSArray *classNameArray, NSString *propertyName, CFTypeRef *property);
//bool getIORegTreePlanePropertyChildren(NSString *treeName, NSArray *childNameArray, NSString *propertyName, CFTypeRef *property);
bool getGPUModelAndVRAM(NSString **gpuModel, uint32_t &gpuDeviceID, uint32_t &gpuVendorID, mach_vm_size_t &vramSize, mach_vm_size_t &vramFree);
bool hasIORegClassEntry(NSString *findClassName);
bool getIORegString(NSString *service, NSString *name, NSString **value);
bool getIORegArray(NSString *service, NSString *name, NSArray **value);
bool getIORegDictionary(NSString *service, NSString *name, NSDictionary **value);
bool getIORegPCIDeviceUInt32(NSString *pciName, NSString *propertyName, uint32_t *propertyValue);
bool getIORegPCIDeviceNSData(NSString *pciName, NSString *propertyName, NSData **propertyValue);
bool getIntelGenString(NSString **intelGen);
bool getPlatformTableNative(NSData **nativePlatformTable);
bool getPlatformTablePatched(NSData **patchedPlatformTable);
bool getPlatformID(uint32_t *platformID);

#endif /* IORegTools_hpp */
