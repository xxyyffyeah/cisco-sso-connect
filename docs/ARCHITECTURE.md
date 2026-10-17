# Architecture and limits

## Components

- src/Core.m: alias discovery, OpenSSH config resolution, folder history, shell quoting, bounded child processes, credential identities and scoped configuration updates.
- src/Cisco.m: Cisco state verification, one-shot GUI/CLI connection, trusted-origin embedded SSO automation and explicit banner handling.
- src/App.m: AppKit UI, Keychain access, askpass, on-demand launchd SSH session, VS Code accessibility checks, local Terminal launch.
- src/Icon.m: original geometric icon, reproducibly generated during a build.
- scripts: local build/install/test and public-file audit.

No telemetry, analytics, cloud backend, credential export or background auto-login is implemented.

## Connection lifecycle

Select enabled stages → Cisco VPN/SSO (default on) → verify Cisco Connected → optional SSH host/folder preparation → selected VS Code and/or Terminal outputs.

VS Code and Terminal default off, are remembered independently, and can be used with Cisco disabled. With both off, the flow returns immediately after the VPN stage without SSH resolution, credentials or clients. If both are enabled, a VS Code launch/verification failure does not suppress the Terminal launch after SSH/directory preparation succeeds.

Cisco GUI mode sets the configured endpoint and clicks Connect once. SSO automation only operates inside a verified HTTPS-origin AXWebArea in Cisco's embedded browser. Username/password fields must have recognized labels; the password must additionally be an AXSecureTextField. No password keyboard/clipboard fallback is used. Next, password submission and approved-banner Accept are each attempted at most once. CLI mode is explicitly selected and never triggers a GUI retry.

The session helper is an on-demand launchd job outside ~/Library/LaunchAgents. It starts only from a user-requested connection, has KeepAlive disabled, and follows the SSH master's lifetime. Closing the launcher does not own/terminate the authenticated transport.

OpenSSH controls keys, host verification, jumps, port and authentication policy. The app never changes a remote server. The directory check runs a quoted cd and pwd over an authenticated session.

## Supported / not promised

- Custom SSH ports and jump hosts are resolved by OpenSSH, not hard-coded port probes.
- Remote commands require a POSIX-compatible shell; Windows PowerShell/cmd-only hosts are not supported.
- VS Code **stable** is supported; Insiders and other editors are not auto-detected.
- Recent single-folder workspace records are supported; multi-root workspace files are not enumerated.
- Existing-window matching uses the alias and folder basename exposed in VS Code's title. Multiple matching windows stop the flow. Identical basenames on the same server cannot be proven distinct from the title alone: verify or close ambiguous windows before connecting.
- Visible English/Chinese Reload/Reconnect buttons are supported. Stale password widgets, disconnected status menus and other locales may require a manual reload. The public implementation deliberately does not kill VS Code SSH processes or type into generic password fields.
- A VS Code connected indicator is not proof that every extension is ready. Terminal launch success is not proof its interactive shell has finished starting.
- No automatic dependency downloads, login service, remote key installation, or MFA approval.
- Cisco supports only the recognized UI/origin surfaces. External browsers, MFA, unknown banners and unrecognized controls are completed manually. Existing connected tunnels are retained without verifying/switching their gateway.
- A pre-SSH hook is optional, executes with the user's privileges, and is not a universal VPN connector. Its child processes must manage their own cancellation/readiness.

## Validation

Offline tests cover all eight combinations of VPN/VS Code/Terminal stages, VPN URL validation, exact HTTPS origins, Cisco state parsing, shell injection boundaries, missing directories, SSH Include discovery/cycles, workspace history, credential separation, prompt classification, safe config updates and subprocess deadlines. They use synthetic example hosts.

The build and install are tested on the maintainer's Mac, and GitHub Actions independently builds/tests the public checkout. This does not certify every VPN, remote OS, authentication policy or future VS Code accessibility tree.
