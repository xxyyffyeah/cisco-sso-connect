#import "Cisco.h"
#import "Core.h"
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

NSString *SLCiscoCLI(void) {
    for (NSString *path in @[@"/opt/cisco/secureclient/bin/vpn",@"/opt/cisco/anyconnect/bin/vpn"])
        if ([NSFileManager.defaultManager isExecutableFileAtPath:path]) return path;
    return nil;
}
BOOL SLCiscoIsConnected(void) {
    NSString *cli=SLCiscoCLI();if (!cli) return NO;
    NSDictionary *result=SLRun(cli,@[@"state"],nil,5);
    return [result[@"status"] intValue]==0 && SLCiscoConnectedOutput(result[@"output"]);
}
static NSString *AXString(AXUIElementRef root,CFStringRef attr) {
    CFTypeRef value=NULL;AXUIElementCopyAttributeValue(root,attr,&value);
    if (!value) return nil;
    if (CFGetTypeID(value)==CFURLGetTypeID()) return [CFBridgingRelease(value) absoluteString];
    if (CFGetTypeID(value)!=CFStringGetTypeID()) {CFRelease(value);return nil;}
    return CFBridgingRelease(value);
}
static AXUIElementRef Find(AXUIElementRef root,NSString *role,NSArray *labels,NSString *origin,int depth) {
    if (depth<0) return NULL;
    NSString *currentRole=AXString(root,kAXRoleAttribute);
    BOOL match=(!role || [currentRole isEqualToString:role]);
    if (origin) match=match && [SLHTTPSOrigin(AXString(root,CFSTR("AXURL"))) isEqualToString:origin];
    if (labels) {
        BOOL named=NO;
        for (id attr in @[(id)kAXTitleAttribute,(id)kAXDescriptionAttribute])
            if ([labels containsObject:AXString(root,(__bridge CFStringRef)attr)]) named=YES;
        // Never read secure-field values. Static banner text only.
        if ([currentRole isEqualToString:@"AXStaticText"] && [labels containsObject:AXString(root,kAXValueAttribute)]) named=YES;
        match=match && named;
    }
    if (match) return (AXUIElementRef)CFRetain(root);
    CFTypeRef children=NULL;AXUIElementCopyAttributeValue(root,kAXChildrenAttribute,&children);
    AXUIElementRef result=NULL;
    if (children && CFGetTypeID(children)==CFArrayGetTypeID())
        for (CFIndex i=0;i<MIN(CFArrayGetCount(children),200) && !result;i++)
            result=Find((AXUIElementRef)CFArrayGetValueAtIndex(children,i),role,labels,origin,depth-1);
    if (children) CFRelease(children);
    return result;
}
static BOOL Press(AXUIElementRef root,NSArray *names) {
    AXUIElementRef button=Find(root,@"AXButton",names,nil,20);
    if (!button) return NO;
    BOOL ok=AXUIElementPerformAction(button,kAXPressAction)==kAXErrorSuccess;
    CFRelease(button);return ok;
}
static NSRunningApplication *CiscoApp(void) {
    for (NSString *bundle in @[@"com.cisco.secureclient.gui",@"com.cisco.anyconnect.gui"]) {
        NSArray *apps=[NSRunningApplication runningApplicationsWithBundleIdentifier:bundle];
        if (apps.count) return apps.firstObject;
    }
    return nil;
}
NSString *SLConnectCisco(NSDictionary *settings,NSString *(^passwordProvider)(void),void (^progress)(NSString *)) {
    NSString *endpoint=SLVPNEndpoint(settings[@"endpoint"]);
    if (!endpoint) return @"Enter a valid Cisco VPN endpoint (HTTPS, no credentials or query parameters).";
    if (!SLCiscoCLI()) return @"Install your organization's Cisco Secure Client VPN module first.";
    if (SLCiscoIsConnected()) {
        progress(@"Cisco already reports Connected. Keeping the existing tunnel; its gateway has not been re-verified.");
        return nil;
    }
    // SSO uses Cisco's own browser handoff. For sites with a tested CLI flow,
    // select CLI explicitly; never fall back and issue a second auth attempt.
    BOOL cli=[settings[@"method"] isEqualToString:@"cli"];
    if (!cli && !AXIsProcessTrusted()) return @"Enable SSO Connect in Privacy & Security > Accessibility for Cisco GUI automation.";
    NSTask *cliTask=nil;
    if (cli) {
        cliTask=[NSTask new];cliTask.executableURL=[NSURL fileURLWithPath:SLCiscoCLI()];
        cliTask.arguments=@[@"connect",endpoint];
        cliTask.standardInput=NSFileHandle.fileHandleWithNullDevice;
        cliTask.standardOutput=NSFileHandle.fileHandleWithNullDevice;
        cliTask.standardError=NSFileHandle.fileHandleWithNullDevice;
        if (![cliTask launchAndReturnError:nil]) return @"Cisco CLI could not start.";
        progress(@"Cisco CLI connection requested once. Complete the SSO browser/MFA if it appears.");
    } else {
        if (!CiscoApp()) {
            NSString *path=@"/Applications/Cisco/Cisco Secure Client.app";
            if (![NSFileManager.defaultManager fileExistsAtPath:path]) path=@"/Applications/Cisco/Cisco AnyConnect Secure Mobility Client.app";
            if ([SLRun(@"/usr/bin/open",@[path],nil,10)[@"status"] intValue]!=0) return @"Cisco Secure Client could not be opened.";
        }
        NSRunningApplication *app=nil;
        for (int i=0;i<20 && !(app=CiscoApp());i++) [NSThread sleepForTimeInterval:0.25];
        if (!app) return @"Cisco did not become available.";
        [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        BOOL clicked=NO;
        for (int i=0;i<20 && !clicked;i++) {
            AXUIElementRef root=AXUIElementCreateApplication(app.processIdentifier);
            AXUIElementRef combo=Find(root,@"AXComboBox",nil,nil,16);
            if (combo) {
                BOOL set=AXUIElementSetAttributeValue(combo,kAXValueAttribute,(__bridge CFStringRef)endpoint)==kAXErrorSuccess;
                CFRelease(combo);
                if (set) {
                    AXUIElementRef connect=Find(root,@"AXButton",@[@"Connect",@"连接"],nil,16);
                    if (connect) {
                        AXError result=AXUIElementPerformAction(connect,kAXPressAction);
                        CFRelease(connect);CFRelease(root);
                        if (result!=kAXErrorSuccess) return @"Cisco Connect was not confirmed. No automatic retry was made.";
                        clicked=YES;break;
                    }
                }
            }
            CFRelease(root);[NSThread sleepForTimeInterval:0.25];
        }
        if (!clicked) return @"Cisco's endpoint/Connect controls were not recognized. Connect manually or configure a tested CLI flow.";
        progress(@"Cisco Connect clicked. Waiting for SSO and your MFA approval…");
    }
    BOOL nextUsed=NO,passwordUsed=NO,acceptUsed=NO;
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:180];
    while (deadline.timeIntervalSinceNow>0) {
        if (SLCiscoIsConnected()) return nil;
        NSRunningApplication *app=CiscoApp();
        if (!cli && app && AXIsProcessTrusted()) {
            AXUIElementRef root=AXUIElementCreateApplication(app.processIdentifier);
            AXUIElementRef accept=Find(root,@"AXButton",@[@"Accept",@"接受"],nil,20);
            if (accept && !acceptUsed) {
                NSString *banner=settings[@"approvedBanner"];
                CFTypeRef window=NULL;AXUIElementCopyAttributeValue(accept,kAXWindowAttribute,&window);
                AXUIElementRef known=banner.length && window ? Find((AXUIElementRef)window,@"AXStaticText",@[banner],nil,20):NULL;
                if (known) {
                    acceptUsed=YES; // An attempted click is never repeated.
                    AXUIElementPerformAction(accept,kAXPressAction);CFRelease(known);
                } else progress(@"Read and accept the unfamiliar VPN banner yourself. It was not auto-accepted.");
                if (window) CFRelease(window);
            }
            if (accept) CFRelease(accept);
            NSString *origin=SLHTTPSOrigin(settings[@"ssoOrigin"]);
            AXUIElementRef web=origin ? Find(root,@"AXWebArea",nil,origin,20):NULL;
            if (web) {
                // Only this verified embedded origin, never an arbitrary browser/window.
                AXUIElementRef secure=Find(web,@"AXTextField",@[@"Password",@"Password:",@"密码"],nil,20);
                if (secure && !passwordUsed &&
                    [AXString(secure,kAXSubroleAttribute) isEqualToString:@"AXSecureTextField"]) {
                    NSString *value=passwordProvider();
                    passwordUsed=YES;
                    // No keyboard/clipboard fallback if AX refuses the exact secure field.
                    if (value.length && AXUIElementSetAttributeValue(secure,kAXValueAttribute,(__bridge CFStringRef)value)==kAXErrorSuccess)
                        Press(web,@[@"Verify",@"Sign in",@"Sign In",@"Log in",@"登录"]);
                    else progress(@"Enter your password in Cisco/SSO. Secure autofill was unavailable.");
                }
                if (secure) CFRelease(secure);
                if (!nextUsed && !passwordUsed) {
                    NSString *username=settings[@"username"];
                    AXUIElementRef field=Find(web,@"AXTextField",@[@"Username",@"Username:",@"Email",@"Email address",@"用户名"],nil,20);
                    if (field && username.length &&
                        ![AXString(field,kAXSubroleAttribute) isEqualToString:@"AXSecureTextField"]) {
                        if (AXUIElementSetAttributeValue(field,kAXValueAttribute,(__bridge CFStringRef)username)==kAXErrorSuccess) {
                            nextUsed=YES;Press(web,@[@"Next",@"Continue",@"下一步"]);
                        }
                    }
                    if (field) CFRelease(field);
                }
                CFRelease(web);
            }
            CFRelease(root);
        }
        if (cliTask && !cliTask.running && cliTask.terminationStatus!=0)
            return @"Cisco CLI exited without a connection. No GUI retry was started; select GUI mode if your SSO requires it.";
        [NSThread sleepForTimeInterval:1];
    }
    if (cliTask.running) [cliTask terminate];
    return @"Cisco did not report Connected before the timeout. Complete SSO/MFA and retry; no reconnect loop was started.";
}
