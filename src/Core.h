#import <Foundation/Foundation.h>
BOOL SLValidAlias(NSString *alias);
BOOL SLValidFolder(NSString *folder);
NSString *SLQuote(NSString *value);
NSString *SLRemoteCD(NSString *folder);
NSString *SLTerminalScript(NSString *alias, NSString *folder);
NSString *SLHash(NSString *value);
NSString *SLSupport(void);
NSString *SLCodeCLI(void);
NSArray<NSString *> *SLHosts(NSString *config);
NSArray<NSString *> *SLRecentFolders(NSString *alias, NSString *storage);
NSDictionary *SLRun(NSString *path, NSArray *args, NSDictionary *environment, NSTimeInterval timeout);
NSDictionary *SLResolved(NSString *alias);
NSString *SLCredentialID(NSString *alias, NSDictionary *resolved);
BOOL SLPasswordPromptMatches(NSString *prompt, NSDictionary *resolved);
BOOL SLConfigureHost(NSString *alias, NSString *sshDirectory, NSError **error);
BOOL SLPrivateDirectory(NSString *path);
