#import "Core.h"
#import <CommonCrypto/CommonDigest.h>
#import <glob.h>
#import <sys/stat.h>
#import <unistd.h>
#import <signal.h>
#import <fcntl.h>

NSArray<NSString *> *SLConnectionPlan(BOOL vpn, BOOL code, BOOL terminal) {
    NSMutableArray *plan=[NSMutableArray array];
    if (vpn) [plan addObject:@"vpn"];
    if (code || terminal) [plan addObjectsFromArray:@[@"ssh",@"folder"]];
    if (code) [plan addObject:@"vscode"];
    if (terminal) [plan addObject:@"terminal"];
    return plan;
}
NSString *SLHTTPSOrigin(NSString *url) {
    if (!url.length || [url rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location!=NSNotFound ||
        [url rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound || [url containsString:@"\\"]) return nil;
    NSURLComponents *parts=[NSURLComponents componentsWithString:url];
    if (![parts.scheme.lowercaseString isEqualToString:@"https"] || !parts.host.length || parts.user || parts.password) return nil;
    if (parts.port && (parts.port.integerValue<1 || parts.port.integerValue>65535)) return nil;
    NSURLComponents *origin=[NSURLComponents new];origin.scheme=@"https";origin.host=parts.host.lowercaseString;
    if (parts.port.integerValue!=443) origin.port=parts.port;
    return origin.string;
}
NSString *SLVPNEndpoint(NSString *value) {
    if (!value.length || [value hasPrefix:@"-"]) return nil;
    NSString *url=[value containsString:@"://"] ? value : [@"https://" stringByAppendingString:value];
    if (!SLHTTPSOrigin(url)) return nil;
    NSURLComponents *parts=[NSURLComponents componentsWithString:url];
    if (parts.query || parts.fragment) return nil;
    return url;
}
BOOL SLCiscoConnectedOutput(NSString *output) {
    NSRegularExpression *pattern=[NSRegularExpression regularExpressionWithPattern:
        @"(?im)^[ \\t]*(?:>>[ \\t]*)?state:[ \\t]*([^\\r\\n]*)" options:0 error:nil];
    NSTextCheckingResult *last=[pattern matchesInString:output options:0 range:NSMakeRange(0,output.length)].lastObject;
    if (!last) return NO;
    NSString *state=[[output substringWithRange:[last rangeAtIndex:1]]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    return [state.lowercaseString isEqualToString:@"connected"];
}

BOOL SLValidAlias(NSString *alias) {
    if (!alias.length || alias.length > 128) return NO;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
        @"^[A-Za-z0-9_][A-Za-z0-9_.-]*$" options:0 error:nil];
    return [re numberOfMatchesInString:alias options:0 range:NSMakeRange(0, alias.length)] == 1;
}
BOOL SLValidFolder(NSString *folder) {
    return folder.length && ([folder hasPrefix:@"/"] || [folder isEqualToString:@"~"] ||
        [folder hasPrefix:@"~/"]) &&
        [folder rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location == NSNotFound;
}
NSString *SLQuote(NSString *value) {
    return [NSString stringWithFormat:@"'%@'", [value stringByReplacingOccurrencesOfString:@"'" withString:@"'\"'\"'"]];
}
NSString *SLRemoteCD(NSString *folder) {
    NSString *quoted = SLQuote(folder);
    if ([folder isEqualToString:@"~"]) quoted = @"\"$HOME\"";
    else if ([folder hasPrefix:@"~/"]) quoted = [@"\"$HOME\"/" stringByAppendingString:SLQuote([folder substringFromIndex:2])];
    return [@"cd -- " stringByAppendingString:quoted];
}
NSString *SLTerminalScript(NSString *alias, NSString *folder) {
    if (!SLValidAlias(alias) || !SLValidFolder(folder)) return nil;
    NSString *remote = [SLRemoteCD(folder) stringByAppendingString:@" && exec \"${SHELL:-/bin/sh}\" -i"];
    return [NSString stringWithFormat:
        @"#!/bin/sh\n# SSO Connect: no credentials in this file.\nexec /usr/bin/ssh -t -o ConnectTimeout=20 -- %@ %@\n",
        SLQuote(alias), SLQuote(remote)];
}
NSString *SLHash(NSString *value) {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger i = 0; i < 16; i++) [result appendFormat:@"%02x", digest[i]];
    return result;
}
NSString *SLSupport(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/SSH Launch"];
}
BOOL SLPrivateDirectory(NSString *path) {
    struct stat st;
    if (lstat(path.fileSystemRepresentation, &st) == 0) {
        if (!S_ISDIR(st.st_mode) || st.st_uid != getuid()) return NO;
        return chmod(path.fileSystemRepresentation, 0700) == 0;
    }
    return [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES
        attributes:@{NSFilePosixPermissions:@0700} error:nil];
}
NSString *SLCodeCLI(void) {
    for (NSString *root in @[@"/Applications", [NSHomeDirectory() stringByAppendingPathComponent:@"Applications"]]) {
        NSString *path = [root stringByAppendingPathComponent:@"Visual Studio Code.app/Contents/Resources/app/bin/code"];
        if ([NSFileManager.defaultManager isExecutableFileAtPath:path]) return path;
    }
    return nil;
}
// Discovery only. OpenSSH resolves User, HostName, Port, Match and ProxyJump.
static NSArray *SLTokens(NSString *line) {
    NSMutableArray *tokens = [NSMutableArray array];
    NSMutableString *word = [NSMutableString string];
    unichar quote = 0;
    BOOL escaped = NO;
    for (NSUInteger i = 0; i < line.length; i++) {
        unichar c = [line characterAtIndex:i];
        if (escaped) { [word appendFormat:@"%C", c]; escaped = NO; continue; }
        if (c == '\\') { escaped = YES; continue; }
        if (quote) { if (c == quote) quote = 0; else [word appendFormat:@"%C",c]; continue; }
        if (c == '"' || c == '\'') { quote = c; continue; }
        if (c == '#') break;
        if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:c] || (c == '=' && tokens.count <= 1)) {
            if (word.length) { [tokens addObject:[word copy]]; [word setString:@""]; }
        } else [word appendFormat:@"%C",c];
    }
    if (word.length) [tokens addObject:[word copy]];
    return tokens;
}
static void SLReadHosts(NSString *path, NSString *sshRoot, NSMutableOrderedSet *hosts,
                        NSMutableSet *visited, NSUInteger depth) {
    path = path.stringByStandardizingPath;
    if (depth > 12 || visited.count >= 256 || [visited containsObject:path]) return;
    [visited addObject:path];
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if ([attributes fileSize] > 1024*1024) return;
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    for (NSString *line in [contents componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSArray *tokens = SLTokens(line);
        if (tokens.count < 2) continue;
        NSString *key = [tokens[0] lowercaseString];
        if ([key isEqualToString:@"host"])
            for (NSString *alias in [tokens subarrayWithRange:NSMakeRange(1,tokens.count-1)])
                if (SLValidAlias(alias)) [hosts addObject:alias];
        if ([key isEqualToString:@"include"]) {
            for (NSString *include in [tokens subarrayWithRange:NSMakeRange(1,tokens.count-1)]) {
                NSString *pattern = include.stringByExpandingTildeInPath;
                if (![pattern isAbsolutePath]) pattern = [sshRoot stringByAppendingPathComponent:pattern];
                glob_t matches = {0};
                if (glob(pattern.fileSystemRepresentation, 0, NULL, &matches) == 0)
                    for (size_t i = 0; i < matches.gl_pathc; i++)
                        SLReadHosts(@(matches.gl_pathv[i]), sshRoot, hosts, visited, depth+1);
                globfree(&matches);
            }
        }
    }
}
NSArray<NSString *> *SLHosts(NSString *config) {
    NSMutableOrderedSet *hosts = [NSMutableOrderedSet orderedSet];
    SLReadHosts(config, config.stringByDeletingLastPathComponent, hosts, [NSMutableSet set], 0);
    return hosts.array;
}
NSArray<NSString *> *SLRecentFolders(NSString *alias, NSString *storage) {
    NSMutableDictionary *dates = [NSMutableDictionary dictionary];
    NSArray *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:storage error:nil];
    for (NSString *entry in entries) {
        NSString *path = [[storage stringByAppendingPathComponent:entry] stringByAppendingPathComponent:@"workspace.json"];
        NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
        if (attr.fileSize > 1024*1024) continue;
        NSData *data = [NSData dataWithContentsOfFile:path];
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![json isKindOfClass:NSDictionary.class] || ![json[@"folder"] isKindOfClass:NSString.class]) continue;
        NSURLComponents *uri = [NSURLComponents componentsWithString:json[@"folder"]];
        if (![uri.scheme isEqualToString:@"vscode-remote"] ||
            ![uri.host isEqualToString:[@"ssh-remote+" stringByAppendingString:alias]]) continue;
        NSString *folder = uri.percentEncodedPath.stringByRemovingPercentEncoding;
        if (!SLValidFolder(folder)) continue;
        NSDate *date = attr.fileModificationDate ?: NSDate.distantPast;
        if (!dates[folder] || [dates[folder] compare:date] == NSOrderedAscending) dates[folder] = date;
    }
    NSArray *folders = [dates keysSortedByValueUsingComparator:^NSComparisonResult(NSDate *a, NSDate *b) {return [b compare:a];}];
    return folders.count > 30 ? [folders subarrayWithRange:NSMakeRange(0,30)] : folders;
}
// Bounded capture, no raw process diagnostics or credential values in logs.
NSDictionary *SLRun(NSString *path, NSArray *args, NSDictionary *environment, NSTimeInterval timeout) {
    if (!path.length) return @{@"status":@127, @"output":@""};
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:path]; task.arguments = args;
    task.standardInput = NSFileHandle.fileHandleWithNullDevice;
    task.standardError = NSFileHandle.fileHandleWithNullDevice;
    NSPipe *pipe = [NSPipe pipe]; task.standardOutput = pipe;
    if (environment) task.environment = environment;
    NSMutableData *data = [NSMutableData data];
    if (![task launchAndReturnError:nil]) return @{@"status":@127,@"output":@""};
    int fd = pipe.fileHandleForReading.fileDescriptor;
    fcntl(fd, F_SETFL, fcntl(fd,F_GETFL) | O_NONBLOCK);
    void (^drain)(void) = ^{
        char buffer[8192]; ssize_t count;
        while ((count = read(fd,buffer,sizeof(buffer))) > 0)
            if (data.length + count <= 1024*1024) [data appendBytes:buffer length:(NSUInteger)count];
    };
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (task.running && deadline.timeIntervalSinceNow > 0) {drain(); [NSThread sleepForTimeInterval:0.05];}
    BOOL timedOut = task.running;
    if (timedOut) { [task terminate]; [NSThread sleepForTimeInterval:0.2]; if (task.running) kill(task.processIdentifier,SIGKILL); }
    [task waitUntilExit];
    drain();
    [pipe.fileHandleForReading closeFile];
    return @{@"status": timedOut ? @124 : @(task.terminationStatus),
             @"output": [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @""};
}
NSDictionary *SLResolved(NSString *alias) {
    if (!SLValidAlias(alias)) return nil;
    NSDictionary *result = SLRun(@"/usr/bin/ssh", @[@"-G",@"--",alias], nil, 10);
    if ([result[@"status"] intValue] != 0) return nil;
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (NSString *line in [result[@"output"] componentsSeparatedByString:@"\n"]) {
        NSRange space = [line rangeOfString:@" "];
        if (space.location != NSNotFound)
            values[[line substringToIndex:space.location]] = [line substringFromIndex:space.location+1];
    }
    return values[@"hostname"] && values[@"user"] ? values : nil;
}
NSString *SLCredentialID(NSString *alias, NSDictionary *resolved) {
    NSMutableArray *parts = [NSMutableArray arrayWithObject:alias ?: @""];
    for (NSString *key in @[@"hostname",@"user",@"port",@"proxyjump",@"proxycommand"])
        [parts addObject:resolved[key] ?: @""];
    return [@"org.sshlaunch.password." stringByAppendingString:SLHash([parts componentsJoinedByString:@"\n"])];
}
BOOL SLPasswordPromptMatches(NSString *prompt, NSDictionary *resolved) {
    // Never replay a target password into a bastion, key passphrase or MFA prompt.
    NSString *expected = [NSString stringWithFormat:@"%@@%@'s password:",resolved[@"user"],resolved[@"hostname"]];
    return [[prompt stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] isEqualToString:expected];
}
BOOL SLConfigureHost(NSString *alias, NSString *sshDirectory, NSError **error) {
    if (!SLValidAlias(alias) || !SLPrivateDirectory(sshDirectory)) return NO;
    NSString *managed = [sshDirectory stringByAppendingPathComponent:@"ssh-launch.conf"];
    NSString *config = [sshDirectory stringByAppendingPathComponent:@"config"];
    NSString *sockets = [sshDirectory stringByAppendingPathComponent:@"ssh-launch"];
    if (!SLPrivateDirectory(sockets)) return NO;
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *path in @[config,managed]) {
        struct stat st;
        if (lstat(path.fileSystemRepresentation,&st)==0 && (!S_ISREG(st.st_mode) || st.st_uid!=getuid())) return NO;
    }
    NSString *old = [fm fileExistsAtPath:config] ? [NSString stringWithContentsOfFile:config encoding:NSUTF8StringEncoding error:error] : @"";
    NSString *current = [fm fileExistsAtPath:managed] ? [NSString stringWithContentsOfFile:managed encoding:NSUTF8StringEncoding error:error] : @"# Managed by SSO Connect. Only explicitly selected aliases.\n";
    if (!old || !current) return NO;
    NSString *include = @"Include ~/.ssh/ssh-launch.conf\nHost *\n";
    if ([old containsString:@"ssh-launch.conf"] && ![old hasPrefix:include]) return NO;
    NSString *marker = [NSString stringWithFormat:@"Host %@\n",alias];
    if (![current containsString:marker])
        current = [current stringByAppendingFormat:
            @"\nHost %@\n    ControlMaster auto\n    ControlPath ~/.ssh/ssh-launch/%%C\n    ControlPersist 600\n",alias];
    if (![old hasPrefix:include] && [fm fileExistsAtPath:config]) {
        NSString *backup = [config stringByAppendingFormat:@".ssh-launch-backup-%@",NSUUID.UUID.UUIDString];
        if (![fm copyItemAtPath:config toPath:backup error:error]) return NO;
        chmod(backup.fileSystemRepresentation,0600);
    }
    if (![current writeToFile:managed atomically:YES encoding:NSUTF8StringEncoding error:error]) return NO;
    chmod(managed.fileSystemRepresentation,0600);
    if (![old hasPrefix:include] &&
        ![[include stringByAppendingString:old] writeToFile:config atomically:YES encoding:NSUTF8StringEncoding error:error]) return NO;
    chmod(config.fileSystemRepresentation,0600);
    return YES;
}
