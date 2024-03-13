//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "NSUserDefaults+OWS.h"
#import <SessionUtilitiesKit/SessionUtilitiesKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation NSUserDefaults (OWS)

+ (NSUserDefaults *)appUserDefaults
{
    return [OWSCurrentAppContext appUserDefaults];
}

+ (void)migrateToSharedUserDefaults
{
    NSUserDefaults *appUserDefaults = self.appUserDefaults;

    NSDictionary<NSString *, id> *dictionary = [NSUserDefaults standardUserDefaults].dictionaryRepresentation;
    for (NSString *key in dictionary) {
        id value = dictionary[key];
        [appUserDefaults setObject:value forKey:key];
    }
}

+ (void)removeAll
{
    [NSUserDefaults.standardUserDefaults removeAll];
    [self.appUserDefaults removeAll];
}

- (void)removeAll
{
    NSDictionary<NSString *, id> *dictionary = self.dictionaryRepresentation;
    for (NSString *key in dictionary) {
        [self removeObjectForKey:key];
    }
    [self synchronize];
}

@end

NS_ASSUME_NONNULL_END
