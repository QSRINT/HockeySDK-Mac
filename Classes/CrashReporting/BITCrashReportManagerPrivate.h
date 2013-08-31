//
//  BITCrashReportManagerPrivate.h
//  HockeySDK
//
//  Created by Andreas Linde on 08.08.13.
//
//

#import <Foundation/Foundation.h>

#import <CrashReporter/CrashReporter.h>


@interface BITCrashReportManager ()


@property (nonatomic) NSUncaughtExceptionHandler *plcrExceptionHandler;

- (NSString *)applicationName;
- (NSString *)applicationVersion;

- (void)returnToMainApplication;

- (void)cancelReport;
- (void)sendReportWithCrash:(NSString*)crashFile crashDescription:(NSString *)crashDescription;

- (void)handleCrashReport;
- (BOOL)hasPendingCrashReport;
- (void)cleanCrashReports;
- (NSString *)extractAppUUIDs:(BITPLCrashReport *)report;

- (void)postXML:(NSString*)xml;

/**
 *  Initialize the crash reporter and check if there are any pending crash reports
 *
 *  This method initializes the PLCrashReporter instance if it is not disabled.
 *  It also checks if there are any pending crash reports available that should be send or
 *  presented to the user.
 */
- (void)startManager;

@end
