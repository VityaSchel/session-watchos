#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (normalizeImage)

- normalizedImage;
- resizedWithQuality:(CGInterpolationQuality)quality rate:(CGFloat)rate;

- (nullable UIImage *)resizedWithMaxDimensionPoints:(CGFloat)maxDimensionPoints;
- (nullable UIImage *)resizedImageToSize:(CGSize)dstSize;
- resizedImageToFillPixelSize:(CGSize)boundingSize;

+ imageWithColor:color;
+ imageWithColor:color size:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
