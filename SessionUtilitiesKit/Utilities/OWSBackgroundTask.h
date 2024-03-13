//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, BackgroundTaskState) {
    BackgroundTaskState_Success,
    BackgroundTaskState_CouldNotStart,
    BackgroundTaskState_Expired,
    BackgroundTaskState_Cancelled,
};

typedef void (^BackgroundTaskCompletionBlock)(BackgroundTaskState backgroundTaskState);

// This class can be safely accessed and used from any thread.
@interface OWSBackgroundTaskManager : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedManager;

- (void)observeNotifications;

@end

#pragma mark -

// This class makes it easier and safer to use background tasks.
//
// * Uses RAII (Resource Acquisition Is Initialization) pattern.
// * Ensures completion block is called exactly once and on main thread,
//   to facilitate handling "background task timed out" case, for example.
// * Ensures we properly handle the "background task could not be created"
//   case.
//
// Usage:
//
// * Use factory method to start a background task.
// * Retain a strong reference to the OWSBackgroundTask during the "work".
// * Clear all references to the OWSBackgroundTask when the work is done,
//   if possible.
@interface OWSBackgroundTask : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (OWSBackgroundTask *)backgroundTaskWithLabelStr:(const char *)labelStr;

// completionBlock will be called exactly once on the main thread.
+ (OWSBackgroundTask *)backgroundTaskWithLabelStr:(const char *)labelStr
                                  completionBlock:(BackgroundTaskCompletionBlock)completionBlock;

+ (OWSBackgroundTask *)backgroundTaskWithLabel:(NSString *)label;

// completionBlock will be called exactly once on the main thread.
+ (OWSBackgroundTask *)backgroundTaskWithLabel:(NSString *)label
                               completionBlock:(BackgroundTaskCompletionBlock)completionBlock;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
