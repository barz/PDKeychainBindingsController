//
//  PDKeychainBindingsController.m
//  PDKeychainBindingsController
//
//  Created by Carl Brown on 7/10/11.
//  Copyright 2011 PDAgent, LLC. Released under MIT License.
//

//  There's (understandably) a lot of controversy about how (and whether)
//   to use the Singleton pattern for Cocoa.  I am here because I'm 
//   trying to emulate existing Singleton (NSUserDefaults) behavior
//
//   and I'm using the singleton methodology from
//   http://www.duckrowing.com/2010/05/21/using-the-singleton-pattern-in-objective-c/
//   because it seemed reasonable


#import "PDKeychainBindingsController.h"
#import <Security/Security.h>

static PDKeychainBindingsController *sharedInstance = nil;

@implementation PDKeychainBindingsController

#pragma mark -
#pragma mark Keychain Access

- (NSString*)serviceName {
	return [[NSBundle mainBundle] bundleIdentifier];
}


- (NSString*)stringForKey:(NSString*)key {
    NSString* string = nil;
    
#if TARGET_OS_IPHONE
    NSData*     stringData = [self dataForKey:key];
    if (stringData) {
        string = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
    }    
#else //OSX
    //SecKeychainItemRef item = NULL;
    UInt32 stringLength;
    void *stringBuffer;
    OSStatus status = SecKeychainFindGenericPassword(NULL, (uint) [[self serviceName] lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [[self serviceName] UTF8String],
                                            (uint) [key lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [key UTF8String],
                                            &stringLength, &stringBuffer, NULL);

	if (status == noErr) {
        string = [[NSString alloc] initWithBytes:stringBuffer length:stringLength encoding:NSUTF8StringEncoding];
        SecKeychainItemFreeAttributesAndData(NULL, stringBuffer);
    }
#endif
    
	return string;	
}


// Hsoi 2013-06-2013 - added as a more generalized way to store stuff in the keychain (since the original
// author ultimately is storing stuff as NSData anyways).
//
// I only added iOS support because I'm not using OS X and not going to maintain that.
- (NSData*)dataForKey:(NSString *)key {
    NSData* theData = nil;
#if TARGET_OS_IPHONE
    NSDictionary*   query = @{(__bridge id)kSecReturnData:(__bridge id)kCFBooleanTrue,
                              (__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                              (__bridge id)kSecAttrAccount:key,
                              (__bridge id)kSecAttrService:[self serviceName]
                              };
	
    CFDataRef stringData = NULL;
    OSStatus  status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef*)&stringData);
    if (status == errSecSuccess) {
        theData = CFBridgingRelease(stringData);
    }
#endif
    return theData;
}


- (BOOL)storeString:(NSString*)string forKey:(NSString*)key {
    return [self storeString:string forKey:key accessibleAttribute:kSecAttrAccessibleWhenUnlocked];
}

- (BOOL)storeString:(NSString*)string forKey:(NSString*)key accessibleAttribute:(CFTypeRef)accessibleAttribute {
#if TARGET_OS_IPHONE
    if (!string) {
        return [self storeData:nil forKey:key accessibleAttribute:accessibleAttribute];
    }
    else {
        NSData* stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
        return [self storeData:stringData forKey:key accessibleAttribute:accessibleAttribute];
    }
#else
	if (!string)  {
        SecKeychainItemRef item = NULL;
        OSStatus status = SecKeychainFindGenericPassword(NULL, (uint) [[self serviceName] lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [[self serviceName] UTF8String],
                                                         (uint) [key lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [key UTF8String],
                                                         NULL, NULL, &item);
        if(status) return YES;
        if(!item) return YES;
        return !SecKeychainItemDelete(item);
    } else {
        SecKeychainItemRef item = NULL;
        OSStatus status = SecKeychainFindGenericPassword(NULL, (uint) [[self serviceName] lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [[self serviceName] UTF8String],
                                                         (uint) [key lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [key UTF8String],
                                                         NULL, NULL, &item);
        if(status) {
            //NO such item. Need to add it
            return !SecKeychainAddGenericPassword(NULL, (uint) [[self serviceName] lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [[self serviceName] UTF8String],
                                                  (uint) [key lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [key UTF8String],
                                                  (uint) [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding],[string UTF8String],
                                                  NULL);
        }
        
        if(item)
            return !SecKeychainItemModifyAttributesAndData(item, NULL, (uint) [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [string UTF8String]);
        
        else
            return !SecKeychainAddGenericPassword(NULL, (uint) [[self serviceName] lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [[self serviceName] UTF8String],
                                                  (uint) [key lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [key UTF8String],
                                                  (uint) [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding],[string UTF8String],
                                                  NULL);
    }
#endif
}


// Hsoi 2013-06-2013 - added as a more generalized way to store stuff in the keychain (since the original
// author ultimately is storing stuff as NSData anyways).
//
// I only added iOS support because I'm not using OS X and not going to maintain that.
- (BOOL)storeData:(NSData*)data forKey:(NSString*)key {
    return [self storeData:data forKey:key accessibleAttribute:kSecAttrAccessibleWhenUnlocked];
}


- (BOOL)storeData:(NSData*)data forKey:(NSString*)key accessibleAttribute:(CFTypeRef)accessibleAttribute {
    BOOL stored = NO;
    
#if TARGET_OS_IPHONE
    NSDictionary *spec = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                           (__bridge id)kSecAttrAccount:key,
                           (__bridge id)kSecAttrService:[self serviceName]
                           };
    
    if (!data) {
        stored = (SecItemDelete((__bridge CFDictionaryRef)spec) == errSecSuccess);
    }
    else if ([self dataForKey:key]) {
        NSDictionary *update = @{
                                 (__bridge id)kSecAttrAccessible:(__bridge id)accessibleAttribute,
                                 (__bridge id)kSecValueData:data
                                };
        
        stored = (SecItemUpdate((__bridge CFDictionaryRef)spec, (__bridge CFDictionaryRef)update) == errSecSuccess);
    }
    else {
        NSMutableDictionary* dataDict = [[NSMutableDictionary alloc] initWithDictionary:spec];
        dataDict[(__bridge id)kSecValueData] = data;
        dataDict[(__bridge id)kSecAttrAccessible] =(__bridge id)accessibleAttribute;
        stored = (SecItemAdd((__bridge CFDictionaryRef)dataDict, NULL) == errSecSuccess);
    }
#endif
    
    return stored;
}



#pragma mark -
#pragma mark Singleton Stuff

+ (PDKeychainBindingsController *)sharedKeychainBindingsController 
{
    static dispatch_once_t onceQueue;

    dispatch_once(&onceQueue, ^{
        sharedInstance = [[self alloc] init];
    });

	return sharedInstance;
}

#pragma mark -
#pragma mark Business Logic

- (PDKeychainBindings *) keychainBindings {
    if (_keychainBindings == nil) {
        _keychainBindings = [[PDKeychainBindings alloc] init]; 
    }
    if (_valueBuffer==nil) {
        _valueBuffer = [[NSMutableDictionary alloc] init];
    }
    return _keychainBindings;
}

-(id) values {
    if (_valueBuffer==nil) {
        _valueBuffer = [[NSMutableDictionary alloc] init];
    }
    return _valueBuffer;
}

- (id)valueForKeyPath:(NSString *)keyPath {
    NSRange firstSeven=NSMakeRange(0, 7);
    if (NSEqualRanges([keyPath rangeOfString:@"values."],firstSeven)) {
        //This is a values keyPath, so we need to check the keychain
        NSString *subKeyPath = [keyPath stringByReplacingCharactersInRange:firstSeven withString:@""];
        NSString *retrievedString = [self stringForKey:subKeyPath];
        if (retrievedString) {
            if (![_valueBuffer objectForKey:subKeyPath] || ![[_valueBuffer objectForKey:subKeyPath] isEqualToString:retrievedString]) {
                //buffer has wrong value, need to update it
                [_valueBuffer setValue:retrievedString forKey:subKeyPath];
            }
        }
    }
    
    return [super valueForKeyPath:keyPath];
}

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath {
    [self setValue:value forKeyPath:keyPath accessibleAttribute:kSecAttrAccessibleWhenUnlocked];
}

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath accessibleAttribute:(CFTypeRef)accessibleAttribute {
    NSRange firstSeven=NSMakeRange(0, 7);
    if (NSEqualRanges([keyPath rangeOfString:@"values."],firstSeven)) {
        //This is a values keyPath, so we need to check the keychain
        NSString *subKeyPath = [keyPath stringByReplacingCharactersInRange:firstSeven withString:@""];
        NSString *retrievedString = [self stringForKey:subKeyPath];
        if (retrievedString) {
            if (![value isEqualToString:retrievedString]) {
                [self storeString:value forKey:subKeyPath accessibleAttribute:accessibleAttribute];
            }
            if (![_valueBuffer objectForKey:subKeyPath] || ![[_valueBuffer objectForKey:subKeyPath] isEqualToString:value]) {
                //buffer has wrong value, need to update it
                [_valueBuffer setValue:value forKey:subKeyPath ];
            }
        } else {
            //First time to set it
            [self storeString:value forKey:subKeyPath accessibleAttribute:accessibleAttribute];
            [_valueBuffer setValue:value forKey:subKeyPath];
        }
    } 
    [super setValue:value forKeyPath:keyPath];
}


// Hsoi 2013-06-25 - purges all items from the app's Keychain.
//
// Added because the keychain data sticks around forever, but this may not be desired. So in my iOS app,
// if I detect all "first launch" I'll purge to ensure we're using fresh data and don't risk stale
// data coming back into the app.
//
// I did this for iOS onl. I don't know if this pans over to Mac OS X or not. Presently is no-op on Mac OS X.
- (void)purge {
#if TARGET_OS_IPHONE
    NSArray *secItemClasses = @[(__bridge id)kSecClassGenericPassword,
                                (__bridge id)kSecClassInternetPassword,
                                (__bridge id)kSecClassCertificate,
                                (__bridge id)kSecClassKey,
                                (__bridge id)kSecClassIdentity];
    for (id secItemClass in secItemClasses) {
        NSDictionary *spec = @{(__bridge id)kSecClass:secItemClass};
        SecItemDelete((__bridge CFDictionaryRef)spec);
    }
#endif
}

@end
