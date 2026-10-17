#import "Core.h"
int main(int argc,const char *argv[]) {
    @autoreleasepool {
        NSArray *args=NSProcessInfo.processInfo.arguments;
        id result=nil;
        if (argc==5 && [args[1] isEqual:@"plan"]) result=SLConnectionPlan([args[2] boolValue],[args[3] boolValue],[args[4] boolValue]);
        if (argc==3 && [args[1] isEqual:@"vpn-url"]) result=@[SLVPNEndpoint(args[2]) ?: [NSNull null]];
        if (argc==3 && [args[1] isEqual:@"origin"]) result=@[SLHTTPSOrigin(args[2]) ?: [NSNull null]];
        if (argc==3 && [args[1] isEqual:@"cisco-state"]) result=@[@(SLCiscoConnectedOutput(args[2]))];
        if (argc==3 && [args[1] isEqual:@"hosts"]) result=SLHosts(args[2]);
        if (argc==4 && [args[1] isEqual:@"recent"]) result=SLRecentFolders(args[2],args[3]);
        if (argc==4 && [args[1] isEqual:@"configure"]) return SLConfigureHost(args[2],args[3],nil)?0:1;
        if (argc==3 && [args[1] isEqual:@"run"]) result=SLRun(@"/bin/sh",@[@"-c",args[2]],nil,0.4);
        if (argc==7 && [args[1] isEqual:@"credential"])
            result=@[SLCredentialID(args[2],@{@"hostname":args[3],@"user":args[4],@"port":args[5],@"proxyjump":args[6]})];
        if (argc==5 && [args[1] isEqual:@"prompt"])
            result=@[@(SLPasswordPromptMatches(args[2],@{@"hostname":args[3],@"user":args[4]}))];
        if (!result) return 64;
        NSData *data=[NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
        [[NSFileHandle fileHandleWithStandardOutput] writeData:data];
    }
    return 0;
}
