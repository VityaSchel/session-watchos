#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSFileSystem : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (BOOL)protectFileOrFolderAtPath:(NSString *)path;
+ (BOOL)protectFileOrFolderAtPath:(NSString *)path fileProtectionType:(NSFileProtectionType)fileProtectionType;

+ (BOOL)protectRecursiveContentsAtPath:(NSString *)path;

+ (NSString *)appDocumentDirectoryPath;

+ (NSString *)appLibraryDirectoryPath;

+ (NSString *)appSharedDataDirectoryPath;

+ (NSString *)cachesDirectoryPath;

+ (nullable NSError *)renameFilePathUsingRandomExtension:(NSString *)oldFilePath;

+ (nullable NSError *)moveAppFilePath:(NSString *)oldFilePath sharedDataFilePath:(NSString *)newFilePath;

// Returns NO IFF the directory does not exist and could not be created.
+ (BOOL)ensureDirectoryExists:(NSString *)dirPath;
+ (BOOL)ensureDirectoryExists:(NSString *)dirPath fileProtectionType:(NSFileProtectionType)fileProtectionType;

+ (BOOL)ensureFileExists:(NSString *)filePath;

+ (BOOL)deleteFile:(NSString *)filePath;

+ (BOOL)deleteFileIfExists:(NSString *)filePath;

+ (NSArray<NSString *> *_Nullable)allFilesInDirectoryRecursive:(NSString *)dirPath error:(NSError **)error;

+ (NSString *)temporaryFilePath;
+ (NSString *)temporaryFilePathWithFileExtension:(NSString *_Nullable)fileExtension;

// Returns nil on failure.
+ (nullable NSString *)writeDataToTemporaryFile:(NSData *)data fileExtension:(NSString *_Nullable)fileExtension;

+ (nullable NSNumber *)fileSizeOfPath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
