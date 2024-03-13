#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (Image)

// If mimeType is non-nil, we ensure that the magic numbers agree with the
// mimeType.
+ (BOOL)ows_isValidImageAtPath:(NSString *)filePath;
+ (BOOL)ows_isValidImageAtPath:(NSString *)filePath mimeType:(nullable NSString *)mimeType;
- (BOOL)ows_isValidImage;
- (BOOL)ows_isValidImageWithMimeType:(nullable NSString *)mimeType;
- (NSString *_Nullable)ows_guessMimeType;

// Returns the image size in pixels.
//
// Returns CGSizeZero on error.
+ (CGSize)imageSizeForFilePath:(NSString *)filePath mimeType:(NSString *)mimeType;

+ (BOOL)hasAlphaForValidImageFilePath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
