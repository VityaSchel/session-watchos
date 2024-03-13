//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "Randomness.h"

NS_ASSUME_NONNULL_BEGIN

@implementation Randomness

+ (NSData *)generateRandomBytes:(int)numberBytes
{
    NSMutableData *_Nullable randomBytes = [NSMutableData dataWithLength:numberBytes];
    if (!randomBytes) {
        OWSFail(@"Could not allocate buffer for random bytes.");
    }
    int err = 0;
    err = SecRandomCopyBytes(kSecRandomDefault, numberBytes, [randomBytes mutableBytes]);
    if (err != noErr || randomBytes.length != numberBytes) {
        OWSFail(@"Could not generate random bytes.");
    }
    NSData *copy = [randomBytes copy];

    OWSAssert(copy != nil);
    OWSAssert(copy.length == numberBytes);
    return copy;
}

@end

NS_ASSUME_NONNULL_END
