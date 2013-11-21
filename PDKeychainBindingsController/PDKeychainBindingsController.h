//
//  PDKeychainBindingsController.h
//  PDKeychainBindingsController
//
//  Created by Carl Brown on 7/10/11.
//  Copyright 2011 PDAgent, LLC. Released under MIT License.
//

#import <Foundation/Foundation.h>
#import "PDKeychainBindings.h"


@interface PDKeychainBindingsController : NSObject {
@private
    PDKeychainBindings *_keychainBindings;
    NSMutableDictionary *_valueBuffer;
}

+ (PDKeychainBindingsController *)sharedKeychainBindingsController;
- (PDKeychainBindings *) keychainBindings;

- (id)values;    // accessor object for PDKeychainBindings values. This property is observable using key-value observing.

- (NSString*)stringForKey:(NSString*)key;
- (BOOL)storeString:(NSString*)string forKey:(NSString*)key;
- (BOOL)storeString:(NSString*)string forKey:(NSString*)key accessibleAttribute:(CFTypeRef)accessibleAttribute;
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath accessibleAttribute:(CFTypeRef)accessibleAttribute;

// Hsoi 2013-06-25 - Added as a more generalized way to store stuff in the Keychain.
// Only available in iOS (no-op in Mac OS X).
- (NSData*)dataForKey:(NSString*)key;
- (BOOL)storeData:(NSData*)data forKey:(NSString*)key;


// Hsoi 2013-06-25 - added, as a mechanism to purge all Keychain items.
- (void)purge;

@end

