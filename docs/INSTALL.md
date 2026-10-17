# Installation and first-run setup

## Requirements

- macOS 13 or later; build on the target Mac (Apple Silicon or Intel).
- Apple Command Line Tools: if missing, run `xcode-select --install` and complete Apple's installer.
- Python 3 to run the offline tests. The application has no Python runtime dependency.
- Your organization's Cisco Secure Client VPN module for the primary VPN/SSO workflow.
- Only for **Open VS Code**: Visual Studio Code in /Applications or ~/Applications and Microsoft's Remote - SSH extension (`ms-vscode-remote.remote-ssh`).
- Only for either optional remote app: a configured SSH host and a POSIX-compatible remote shell. For VS Code, the remote OS must also meet [Remote SSH requirements](https://code.visualstudio.com/docs/remote/ssh).

No Homebrew, npm, API token, paid agent subscription or GitHub credential is required by the application.

## Build and install

Run `bash scripts/test.sh`, then `bash scripts/install.sh`. The app goes to ~/Applications/SSH Launch.app. An optional absolute destination directory can be passed to install.sh.

The source build is locally ad-hoc signed, not Developer ID signed/notarized. The scripts clean metadata only on their own generated app bundle; they do not change macOS security policy or remove quarantine from downloaded third-party applications.

The installer does not open a network connection, install dependencies, modify your SSH/VS Code settings, collect passwords or start a login agent. Updating creates a dated app backup and replaces the executable atomically.

Verify:

```sh
codesign --verify --deep --strict "$HOME/Applications/SSH Launch.app"
"$HOME/Applications/SSH Launch.app/Contents/MacOS/SSHLaunch" --doctor
```

Doctor reports installed components and a host count, not account names, passwords, or config contents. Missing optional VS Code/SSH configuration does not fail VPN-only setup. It does not verify remote connectivity. The read-only `--cisco-status` command reports whether Cisco currently confirms Connected; it does not trigger login.

## Cisco VPN / SSO first

The default selection is **Connect Cisco VPN / SSO on**, **Open VS Code off**, **Open local Terminal off**. Enter the organization's endpoint and use **SSO Settings** for optional trusted-origin autofill. See [Cisco / SSO setup](CISCO_SSO.md).

VS Code and Terminal are independent follow-up choices. Enabling neither completes after VPN verification without resolving SSH config or opening an app. Enabling only Terminal does not require VS Code or its Accessibility integration. Turning Cisco off permits SSH-only use.

## Permissions

Open **System Settings → Privacy & Security → Accessibility**, add SSH Launch if needed, and enable it. This permits Cisco GUI connection/supported embedded SSO steps and, when selected, VS Code window restoration/status checking. If an OS update invalidates permission, re-enable the installed app. CLI-only VPN and Terminal-only SSH do not themselves require Accessibility.

You must grant this yourself. Do not reset the entire permission database. No Screen Recording permission is required.

## Server configuration and shared sessions

Named aliases are read from ~/.ssh/config and nested Include files. Wildcards, negated patterns and non-simple aliases are omitted; supported alias characters are ASCII letters, digits, underscore, dot and hyphen, without a leading hyphen. Include discovery is bounded and does not evaluate Match conditions. OpenSSH resolves the actual selected alias, so discovery may show aliases unavailable under the current Match condition.

Use the same SSH config and system OpenSSH in VS Code. A custom remote.SSH.configFile or remote.SSH.path may prevent session sharing; SSH Launch does not overwrite those settings.

On first use, if connection sharing is absent, the app asks permission to:

- back up ~/.ssh/config beside the original;
- prepend a managed Include and a Host * context reset;
- add ControlMaster/ControlPath/ControlPersist for only the selected alias in ~/.ssh/ssh-launch.conf;
- create a private socket directory at ~/.ssh/ssh-launch.

This lets VS Code and Terminal reuse the authenticated session without copying passwords. It preserves User, Port, IdentityFile, ProxyJump and authentication directives. Existing sharing configuration is used when available. Authenticated shared sessions are a convenience/security tradeoff: clients on your account can reuse the connection until it expires.

For an explicitly approved agent setup:

```sh
"$HOME/Applications/SSH Launch.app/Contents/MacOS/SSHLaunch" --configure-host demo
```

Only use a real alias selected by the user. Symlinked configs or an existing non-top-level managed Include are refused for manual review. Backups are private; do not commit them.

## Passwords and MFA

OpenSSH's configured keys/agent are tried according to its normal policy. The app does not disable key authentication or MFA.

Recognized target-password prompts offer an unchecked **Save ... in macOS Keychain** option. Keychain items are isolated by alias, effective host, user, port and proxy route. Key passphrases, bastion prompts, generic/ambiguous password prompts and MFA responses are not automatically saved or replayed.

If a saved password is stale, stop and remove that one item before retrying:

```sh
"$HOME/Applications/SSH Launch.app/Contents/MacOS/SSHLaunch" --forget-password demo
```

This removes only the current resolved alias's SSH Launch item, never other apps' credentials. Host/user/port/route changes create a different item; obsolete items can be removed manually in Keychain Access. No cross-host fallback is used. Keychain access can prompt again after a system or signing change.

Never run the internal askpass helper to inspect its output. SSH consumes its response through a private pipe.

## Advanced pre-SSH hook

The built-in Cisco flow does not require a script. For advanced, additional network preparation before optional SSH clients, configure a trusted local executable:

```sh
defaults write org.sshlaunch.app beforeConnectExecutable -string "$HOME/.config/ssh-launch/connect-vpn"
```

The executable receives the selected SSH alias as its only argument. It must be a regular executable owned by you and not group/world writable. It runs once before SSH (after the built-in Cisco stage if enabled), has a 180-second deadline, and must return zero only after network access is ready. It is not run in VPN-only mode. Output is not shown in the UI or persisted. Do not put secrets in it; use the vendor's credential store and leave MFA interactive.

Remove this setting to disable it:

```sh
defaults delete org.sshlaunch.app beforeConnectExecutable
```

The app does not install VPN clients, guess endpoints, accept unknown organization banners, or replay another app's credential.

## Uninstall / rollback

Quit SSH Launch. Move only SSH Launch.app to Trash. Do not terminate shared SSH sessions while other clients need them.

If you enabled the managed Include, remove that exact Include and its immediately following Host * reset from ~/.ssh/config, then remove the selected block from ~/.ssh/ssh-launch.conf (or trash that file only if no aliases remain). Preserve later SSH edits; do not blindly restore an old backup. Keep ~/.ssh/ssh-launch sockets until associated sessions finish.

Application state lives in ~/Library/Application Support/SSH Launch and preferences use org.sshlaunch.app. Keychain items use org.sshlaunch.password. for SSH or org.sshlaunch.sso. for Cisco SSO; uninstalling the app does not delete them automatically. Remove only the desired SSH Launch entries through Keychain Access.
