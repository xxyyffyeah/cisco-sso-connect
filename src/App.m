#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Security/Security.h>
#import <sys/file.h>
#import <sys/stat.h>
#import <unistd.h>
#import "Core.h"

static int mainLock = -1;
static NSString *SLSessionRoot(void) {return [SLSupport() stringByAppendingPathComponent:@"Sessions"];}
static NSString *SLLabel(NSString *alias) {return [@"org.sshlaunch.session." stringByAppendingString:SLHash(alias)];}
static NSString *SLState(NSString *alias) {return [SLSessionRoot() stringByAppendingPathComponent:[SLLabel(alias) stringByAppendingString:@".state"]];}
static BOOL SLMaster(NSString *alias) {return [SLRun(@"/usr/bin/ssh",@[@"-O",@"check",@"--",alias],nil,5)[@"status"] intValue]==0;}
static NSDictionary *SLKeyQuery(NSString *service) {
    return @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService:service,(__bridge id)kSecAttrAccount:@"ssh-password"};
}
static NSString *SLPassword(NSString *service) {
    NSMutableDictionary *query = [SLKeyQuery(service) mutableCopy];
    query[(__bridge id)kSecReturnData]=@YES;
    query[(__bridge id)kSecMatchLimit]=(__bridge id)kSecMatchLimitOne;
    CFTypeRef result=NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query,&result)!=errSecSuccess) return nil;
    return [[NSString alloc] initWithData:CFBridgingRelease(result) encoding:NSUTF8StringEncoding];
}
static BOOL SLSavePassword(NSString *service, NSString *value) {
    NSData *data=[value dataUsingEncoding:NSUTF8StringEncoding];
    OSStatus status=SecItemUpdate((__bridge CFDictionaryRef)SLKeyQuery(service),
        (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData:data});
    if (status==errSecSuccess) return YES;
    if (status!=errSecItemNotFound) return NO;
    NSMutableDictionary *item=[SLKeyQuery(service) mutableCopy];
    item[(__bridge id)kSecValueData]=data;
    item[(__bridge id)kSecAttrLabel]=@"SSH Launch — SSH password";
    item[(__bridge id)kSecAttrAccessible]=(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    return SecItemAdd((__bridge CFDictionaryRef)item,NULL)==errSecSuccess;
}
static int SLAskpass(NSString *prompt) {
    NSString *alias=NSProcessInfo.processInfo.environment[@"SSH_LAUNCH_ALIAS"];
    if (!SLValidAlias(alias)) return 1;
    NSDictionary *resolved=SLResolved(alias);
    if (!resolved) return 1;
    NSString *service=SLCredentialID(alias,resolved);
    BOOL reusable=SLPasswordPromptMatches(prompt,resolved);
    NSString *response=reusable ? SLPassword(service) : nil;
    if (!response) {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [NSApp activateIgnoringOtherApps:YES];
        NSAlert *alert=[NSAlert new];
        alert.messageText=@"SSH confirmation";
        alert.informativeText=prompt.length ? prompt : @"Enter the response requested by SSH.";
        [alert addButtonWithTitle:@"Continue"]; [alert addButtonWithTitle:@"Cancel"];
        NSView *view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,410,64)];
        NSSecureTextField *field=[[NSSecureTextField alloc] initWithFrame:NSMakeRect(0,35,410,24)];
        [view addSubview:field];
        NSButton *remember=[NSButton checkboxWithTitle:@"Save this server password in macOS Keychain" target:nil action:nil];
        remember.frame=NSMakeRect(0,0,410,24); remember.hidden=!reusable;
        [view addSubview:remember]; alert.accessoryView=view;
        if ([alert runModal]!=NSAlertFirstButtonReturn) return 1;
        response=[field.stringValue copy]; field.stringValue=@"";
        if (reusable && remember.state==NSControlStateValueOn && response.length &&
            !SLSavePassword(service,response)) {
            NSAlert *warning=[NSAlert new]; warning.messageText=@"Password was not saved";
            warning.informativeText=@"Keychain rejected the update. This attempt will continue without saving.";
            [warning runModal];
        }
    }
    // This stdout is SSH's private askpass pipe, never an application log.
    [[NSFileHandle fileHandleWithStandardOutput] writeData:
        [[response stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    return 0;
}
static int SLSession(NSString *alias) {
    if (!SLValidAlias(alias) || !SLPrivateDirectory(SLSessionRoot())) return 1;
    NSMutableDictionary *env=[NSProcessInfo.processInfo.environment mutableCopy];
    env[@"SSH_ASKPASS"]=NSBundle.mainBundle.executablePath;
    env[@"SSH_ASKPASS_REQUIRE"]=@"force"; env[@"DISPLAY"]=@":0";
    env[@"SSH_LAUNCH_ASKPASS"]=@"1"; env[@"SSH_LAUNCH_ALIAS"]=alias;
    int status=[SLRun(@"/usr/bin/ssh",@[@"-fN",@"-o",@"ConnectTimeout=20",
        @"-o",@"NumberOfPasswordPrompts=1",@"--",alias],env,280)[@"status"] intValue];
    BOOL ready=status==0 && SLMaster(alias);
    [(ready ? @"ready" : @"failed") writeToFile:SLState(alias) atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if (!ready) return 1;
    do {[NSThread sleepForTimeInterval:5];} while (SLMaster(alias));
    [@"ended" writeToFile:SLState(alias) atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return 0;
}
static BOOL SLEnsureSession(NSString *alias) {
    if (SLMaster(alias)) return YES;
    if (!SLPrivateDirectory(SLSupport()) || !SLPrivateDirectory(SLSessionRoot())) return NO;
    NSString *domain=[NSString stringWithFormat:@"gui/%u",getuid()];
    NSString *label=SLLabel(alias);
    // Only this app's on-demand job. No login job and no KeepAlive retry loop.
    SLRun(@"/bin/launchctl",@[@"bootout",[domain stringByAppendingFormat:@"/%@",label]],nil,10);
    [@"starting" writeToFile:SLState(alias) atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSMutableDictionary *job=[@{@"Label":label,
        @"ProgramArguments":@[NSBundle.mainBundle.executablePath,@"--session",alias],
        @"RunAtLoad":@YES,@"KeepAlive":@NO,@"ProcessType":@"Background",
        @"StandardOutPath":@"/dev/null",@"StandardErrorPath":@"/dev/null"} mutableCopy];
    NSString *socket=NSProcessInfo.processInfo.environment[@"SSH_AUTH_SOCK"];
    if (socket.length) job[@"EnvironmentVariables"]=@{@"SSH_AUTH_SOCK":socket};
    NSString *path=[SLSessionRoot() stringByAppendingPathComponent:[label stringByAppendingString:@".plist"]];
    if (![job writeToFile:path atomically:YES]) return NO;
    chmod(path.fileSystemRepresentation,0600);
    if ([SLRun(@"/bin/launchctl",@[@"bootstrap",domain,path],nil,10)[@"status"] intValue]!=0) return NO;
    for (int i=0;i<600;i++) {
        NSString *state=[NSString stringWithContentsOfFile:SLState(alias) encoding:NSUTF8StringEncoding error:nil];
        if ([state isEqualToString:@"failed"] || [state isEqualToString:@"ended"]) return NO;
        if ([state isEqualToString:@"ready"] && SLMaster(alias)) return YES;
        [NSThread sleepForTimeInterval:0.5];
    }
    SLRun(@"/bin/launchctl",@[@"bootout",[domain stringByAppendingFormat:@"/%@",label]],nil,10);
    return NO;
}
static NSString *SLAXString(AXUIElementRef element,CFStringRef attribute) {
    CFTypeRef value=NULL;
    if (AXUIElementCopyAttributeValue(element,attribute,&value)!=kAXErrorSuccess || !value) return nil;
    if (CFGetTypeID(value)!=CFStringGetTypeID()) {CFRelease(value);return nil;}
    return CFBridgingRelease(value);
}
static AXUIElementRef SLFind(AXUIElementRef root,NSArray *labels,int depth) {
    if (depth<0) return NULL;
    if ([SLAXString(root,kAXRoleAttribute) isEqualToString:@"AXButton"])
        for (id attr in @[(id)kAXTitleAttribute,(id)kAXDescriptionAttribute])
            if ([labels containsObject:SLAXString(root,(__bridge CFStringRef)attr)]) return (AXUIElementRef)CFRetain(root);
    CFTypeRef children=NULL;
    AXUIElementCopyAttributeValue(root,kAXChildrenAttribute,&children);
    AXUIElementRef found=NULL;
    if (children && CFGetTypeID(children)==CFArrayGetTypeID())
        for (CFIndex i=0;i<MIN(CFArrayGetCount(children),200) && !found;i++)
            found=SLFind((AXUIElementRef)CFArrayGetValueAtIndex(children,i),labels,depth-1);
    if (children) CFRelease(children);
    return found;
}
// Match only the chosen alias/folder. Ambiguous titles are not auto-clicked.
static int SLCodeWindow(NSString *alias,NSString *folder,BOOL act) {
    if (!AXIsProcessTrusted()) return -1;
    NSArray *apps=[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.microsoft.VSCode"];
    if (!apps.count) return 0;
    NSRunningApplication *code=apps[0];
    AXUIElementRef app=AXUIElementCreateApplication(code.processIdentifier);
    AXUIElementSetAttributeValue(app,CFSTR("AXManualAccessibility"),kCFBooleanTrue);
    CFTypeRef windows=NULL; AXUIElementCopyAttributeValue(app,kAXWindowsAttribute,&windows);
    AXUIElementRef target=NULL; int matches=0;
    if (windows && CFGetTypeID(windows)==CFArrayGetTypeID())
        for (CFIndex i=0;i<CFArrayGetCount(windows);i++) {
            AXUIElementRef window=(AXUIElementRef)CFArrayGetValueAtIndex(windows,i);
            NSString *title=SLAXString(window,kAXTitleAttribute);
            if ([title containsString:[NSString stringWithFormat:@"[SSH: %@]",alias]] &&
                [title containsString:folder.lastPathComponent]) {target=window;matches++;}
        }
    int result=0;
    if (matches==1) {
        result=1;
        AXUIElementRef status=SLFind(target,@[ [@"remote SSH: " stringByAppendingString:alias],
            [@"SSH: " stringByAppendingString:alias]],28);
        if (status) {result=2; CFRelease(status);}
        if (act) {
            AXUIElementSetAttributeValue(target,kAXMinimizedAttribute,kCFBooleanFalse);
            [code activateWithOptions:NSApplicationActivateIgnoringOtherApps];
            AXUIElementPerformAction(target,kAXRaiseAction);
            AXUIElementRef button=SLFind(target,@[@"Reload Window",@"Reconnect",@"重新加载窗口",@"重新连接"],28);
            if (button) {AXUIElementPerformAction(button,kAXPressAction);CFRelease(button);}
        }
    } else if (matches>1) result=-2;
    if (windows) CFRelease(windows); CFRelease(app);
    return result;
}
static BOOL SLOpenTerminal(NSString *alias,NSString *folder) {
    NSString *script=SLTerminalScript(alias,folder);
    NSString *root=[SLSupport() stringByAppendingPathComponent:@"Terminal"];
    if (!script || !SLPrivateDirectory(root)) return NO;
    NSString *path=[root stringByAppendingPathComponent:
        [SLHash([alias stringByAppendingFormat:@"\n%@",folder]) stringByAppendingString:@".command"]];
    if (![script writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) return NO;
    chmod(path.fileSystemRepresentation,0700);
    return [SLRun(@"/usr/bin/open",@[@"-b",@"com.apple.Terminal",path],nil,10)[@"status"] intValue]==0;
}

@interface SLDelegate:NSObject<NSApplicationDelegate>
@property NSWindow *window;
@property NSPopUpButton *server;
@property NSComboBox *folder;
@property NSButton *start;
@property NSTextField *status;
@property NSProgressIndicator *spinner;
@property NSArray *hosts;
@property BOOL busy;
@end
@implementation SLDelegate
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {return YES;}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    NSMenu *menu=[NSMenu new]; NSMenuItem *appItem=[NSMenuItem new]; [menu addItem:appItem];
    NSMenu *submenu=[NSMenu new]; [submenu addItemWithTitle:@"Quit SSH Launch" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu=submenu; NSApp.mainMenu=menu;
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,560,340)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"SSH Launch"; self.window.releasedWhenClosed=NO; [self.window center];
    NSView *view=self.window.contentView;
    NSTextField *title=[NSTextField labelWithString:@"Your server. One launch."];
    title.font=[NSFont systemFontOfSize:26 weight:NSFontWeightSemibold]; title.frame=NSMakeRect(32,280,500,36);[view addSubview:title];
    NSTextField *sub=[NSTextField labelWithString:@"Open a remote folder in VS Code and local Terminal."];
    sub.textColor=NSColor.secondaryLabelColor;sub.frame=NSMakeRect(32,252,500,24);[view addSubview:sub];
    NSTextField *serverLabel=[NSTextField labelWithString:@"SSH server"];serverLabel.frame=NSMakeRect(32,212,110,24);[view addSubview:serverLabel];
    self.server=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(150,208,378,30)];
    self.server.target=self;self.server.action=@selector(selectServer:);[view addSubview:self.server];
    NSTextField *folderLabel=[NSTextField labelWithString:@"Remote folder"];folderLabel.frame=NSMakeRect(32,168,110,24);[view addSubview:folderLabel];
    self.folder=[[NSComboBox alloc] initWithFrame:NSMakeRect(150,164,378,30)];
    self.folder.placeholderString=@"~/project";self.folder.completes=YES;[view addSubview:self.folder];
    self.start=[NSButton buttonWithTitle:@"Start Connection" target:self action:@selector(connect:)];
    self.start.bezelStyle=NSBezelStyleRounded;self.start.keyEquivalent=@"\r";
    self.start.controlSize=NSControlSizeLarge;self.start.frame=NSMakeRect(30,96,500,48);[view addSubview:self.start];
    self.status=[NSTextField wrappingLabelWithString:@"Keys and ssh-agent first. Passwords stay in Keychain."];
    self.status.textColor=NSColor.secondaryLabelColor;self.status.frame=NSMakeRect(62,22,466,58);[view addSubview:self.status];
    self.spinner=[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(32,50,20,20)];
    self.spinner.style=NSProgressIndicatorStyleSpinning;self.spinner.displayedWhenStopped=NO;[view addSubview:self.spinner];
    self.hosts=SLHosts([NSHomeDirectory() stringByAppendingPathComponent:@".ssh/config"]);
    [self.server addItemsWithTitles:self.hosts];
    NSString *last=[NSUserDefaults.standardUserDefaults stringForKey:@"lastAlias"];
    if ([self.hosts containsObject:last]) [self.server selectItemWithTitle:last];
    [self selectServer:nil];
    if (!self.hosts.count) {self.start.enabled=NO;self.status.stringValue=@"Add a named Host entry to ~/.ssh/config, then reopen SSH Launch.";}
    [self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--connect"]) [self connect:nil];
}
- (void)selectServer:(id)sender {
    NSString *alias=self.server.titleOfSelectedItem ?: @"";
    NSMutableOrderedSet *folders=[NSMutableOrderedSet orderedSet];
    NSString *saved=[NSUserDefaults.standardUserDefaults stringForKey:[@"folder." stringByAppendingString:alias]];
    if (saved.length) [folders addObject:saved];
    [folders addObjectsFromArray:SLRecentFolders(alias,[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Code/User/workspaceStorage"])];
    [folders addObject:@"~"];[self.folder removeAllItems];[self.folder addItemsWithObjectValues:folders.array];
    self.folder.stringValue=folders.firstObject;
}
- (void)finish:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(),^{
        self.status.stringValue=message;self.busy=NO;self.start.enabled=YES;self.server.enabled=YES;self.folder.enabled=YES;
        [self.spinner stopAnimation:nil];
    });
}
- (void)message:(NSString *)message {dispatch_async(dispatch_get_main_queue(),^{self.status.stringValue=message;});}
- (void)connect:(id)sender {
    if (self.busy) return;
    NSString *alias=self.server.titleOfSelectedItem;NSString *folder=self.folder.stringValue;
    if (!SLValidAlias(alias)||!SLValidFolder(folder)) {self.status.stringValue=@"Use a named SSH alias and an absolute path, ~, or ~/folder.";return;}
    if (!SLCodeCLI()) {self.status.stringValue=@"Install Visual Studio Code in Applications first.";return;}
    if (!AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge id)kAXTrustedCheckOptionPrompt:@YES})) {
        self.status.stringValue=@"Enable SSH Launch in System Settings > Privacy & Security > Accessibility, then retry.";return;
    }
    self.busy=YES;self.start.enabled=NO;self.server.enabled=NO;self.folder.enabled=NO;[self.spinner startAnimation:nil];
    [NSUserDefaults.standardUserDefaults setObject:alias forKey:@"lastAlias"];
    [NSUserDefaults.standardUserDefaults setObject:folder forKey:[@"folder." stringByAppendingString:alias]];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{[self flow:alias folder:folder];});
}
- (void)flow:(NSString *)alias folder:(NSString *)folder {
    [self message:@"Checking configuration…"];
    NSDictionary *resolved=SLResolved(alias);
    if (!resolved) {[self finish:@"SSH could not resolve this alias. Check ~/.ssh/config."];return;}
    NSString *control=resolved[@"controlpath"];
    if (!control.length || [control isEqualToString:@"none"] || [resolved[@"controlmaster"] isEqualToString:@"false"]) {
        __block BOOL approved=NO;
        dispatch_sync(dispatch_get_main_queue(),^{
            NSAlert *alert=[NSAlert new];alert.messageText=@"Share one authenticated SSH connection?";
            alert.informativeText=@"SSH Launch can add a managed Include to ~/.ssh/config for this alias only. The original file is backed up. Other host settings and authentication methods are preserved.";
            [alert addButtonWithTitle:@"Enable for This Server"];[alert addButtonWithTitle:@"Cancel"];
            approved=[alert runModal]==NSAlertFirstButtonReturn;
        });
        if (!approved || !SLConfigureHost(alias,[NSHomeDirectory() stringByAppendingPathComponent:@".ssh"],nil)) {
            [self finish:@"Connection sharing was not configured. See docs/INSTALL.md."];return;
        }
        resolved=SLResolved(alias);
        if (!resolved[@"controlpath"] || [resolved[@"controlpath"] isEqualToString:@"none"]) {
            [self finish:@"SSH did not load the managed config. Restore/check the backup before retrying."];return;
        }
    }
    // A trusted local executable, opt-in through Preferences. No remote shell text.
    NSString *hook=[NSUserDefaults.standardUserDefaults stringForKey:@"beforeConnectExecutable"];
    if (hook.length) {
        struct stat st;
        if (!hook.isAbsolutePath || lstat(hook.fileSystemRepresentation,&st)!=0 ||
            !S_ISREG(st.st_mode) || st.st_uid!=getuid() || (st.st_mode&0022) ||
            ![NSFileManager.defaultManager isExecutableFileAtPath:hook]) {
            [self finish:@"The VPN/pre-connect hook must be your own executable file, not writable by others."];return;
        }
        [self message:@"Running your local pre-connect hook. Approve MFA yourself if requested."];
        if ([SLRun(hook,@[alias],nil,180)[@"status"] intValue]!=0) {[self finish:@"The pre-connect hook failed or timed out. No SSH retry was started."];return;}
    }
    [self message:@"Authenticating with SSH. Approve host fingerprints and MFA yourself."];
    if (!SLEnsureSession(alias)) {
        [self finish:@"SSH failed; no automatic retry. Check VPN, SSH keys, or the saved password in Keychain Access."];return;
    }
    [self message:@"Checking the remote folder…"];
    NSDictionary *check=SLRun(@"/usr/bin/ssh",@[@"-T",@"-o",@"BatchMode=yes",@"-o",@"ConnectTimeout=10",@"--",alias,
        [SLRemoteCD(folder) stringByAppendingString:@" && pwd -P"]],nil,20);
    NSString *absolute=[check[@"output"] stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
    if ([check[@"status"] intValue]!=0 || ![absolute hasPrefix:@"/"] || !SLValidFolder(absolute)) {
        [self finish:@"Could not verify the remote folder. The server needs a POSIX-compatible shell."];return;
    }
    [self message:@"Opening VS Code…"];
    int existing=SLCodeWindow(alias,absolute,YES);
    if (existing<0) {[self finish:@"Window matching is ambiguous or Accessibility is unavailable. Select the intended VS Code window and retry."];return;}
    if (existing==0 && [SLRun(SLCodeCLI(),@[@"--new-window",@"--remote",
        [@"ssh-remote+" stringByAppendingString:alias],absolute],nil,20)[@"status"] intValue]!=0) {
        [self finish:@"VS Code could not start. Check the Remote - SSH extension."];return;
    }
    BOOL connected=NO;
    for (int i=0;i<90;i++) {
        if (SLCodeWindow(alias,absolute,NO)==2) {connected=YES;break;}
        [NSThread sleepForTimeInterval:0.5];
    }
    if (!connected) {[self finish:@"SSH is ready, but VS Code's connected status was not verified. Reload the selected window; no extra window was opened."];return;}
    if (!SLOpenTerminal(alias,absolute)) {[self finish:@"VS Code connected; Terminal could not be opened."];return;}
    [self finish:@"VS Code is connected. Local Terminal is opening the same folder."];
}
@end

static void SLPrint(NSString *text) {[[NSFileHandle fileHandleWithStandardOutput] writeData:[text dataUsingEncoding:NSUTF8StringEncoding]];}
int main(int argc,const char *argv[]) {
    @autoreleasepool {
        NSArray *args=NSProcessInfo.processInfo.arguments;
        if ([NSProcessInfo.processInfo.environment[@"SSH_LAUNCH_ASKPASS"] isEqualToString:@"1"] && argc==2)
            return SLAskpass(args[1]);
        if (argc==3 && [args[1] isEqualToString:@"--session"]) return SLSession(args[2]);
        if (argc==4 && [args[1] isEqualToString:@"--print-terminal-script"]) {
            NSString *script=SLTerminalScript(args[2],args[3]);if (!script) return 1;SLPrint(script);return 0;
        }
        if (argc==3 && [args[1] isEqualToString:@"--list-hosts"]) {
            for (NSString *host in SLHosts(args[2])) SLPrint([host stringByAppendingString:@"\n"]);return 0;
        }
        if (argc==3 && [args[1] isEqualToString:@"--configure-host"])
            return SLConfigureHost(args[2],[NSHomeDirectory() stringByAppendingPathComponent:@".ssh"],nil)?0:1;
        if (argc==3 && [args[1] isEqualToString:@"--forget-password"]) {
            NSDictionary *resolved=SLResolved(args[2]);if (!resolved) return 1;
            OSStatus status=SecItemDelete((__bridge CFDictionaryRef)SLKeyQuery(SLCredentialID(args[2],resolved)));
            return status==errSecSuccess || status==errSecItemNotFound ? 0:1;
        }
        if (argc==2 && [args[1] isEqualToString:@"--doctor"]) {
            SLPrint([NSString stringWithFormat:@"VS Code: %@\nAccessibility: %@\nSSH aliases: %lu\n",
                SLCodeCLI()?@"available":@"missing",AXIsProcessTrusted()?@"enabled":@"not enabled",
                (unsigned long)SLHosts([NSHomeDirectory() stringByAppendingPathComponent:@".ssh/config"]).count]);
            return SLCodeCLI()?0:2;
        }
        if (argc>1 && !(argc==2 && [args[1] isEqualToString:@"--connect"])) return 64;
        if (!SLPrivateDirectory(SLSupport())) return 1;
        NSString *lockPath=[SLSupport() stringByAppendingPathComponent:@"launcher.lock"];
        mainLock=open(lockPath.fileSystemRepresentation,O_CREAT|O_RDWR|O_NOFOLLOW,0600);
        if (mainLock<0 || flock(mainLock,LOCK_EX|LOCK_NB)!=0) return 0;
        [NSApplication sharedApplication];
        SLDelegate *delegate=[SLDelegate new];NSApp.delegate=delegate;
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];[NSApp run];
    }
    return 0;
}
