#import <Foundation/Foundation.h>
NSString *SLCiscoCLI(void);
BOOL SLCiscoIsConnected(void);
// Returns nil on verified connection, otherwise a user-facing error.
// Runs on a worker queue. Does not disconnect any existing tunnel.
NSString *SLConnectCisco(NSDictionary *settings, NSString *(^passwordProvider)(void), void (^progress)(NSString *));
