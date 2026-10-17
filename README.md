# SSH Launch

A small native macOS launcher for opening the same remote folder in **VS Code Remote SSH and Apple Terminal**.

Bring your own SSH configuration. No university-specific account, VPN endpoint, password, or remote path is built in.

## Install with Claude Code or Codex

Paste this prompt into either coding agent on your Mac:

> Install SSH Launch from https://github.com/xxyyffyeah/ssh-launch. Clone it into a new local folder, read AGENTS.md and docs/INSTALL.md, inspect the build/install scripts, then build, run the offline tests, and install to ~/Applications. Follow docs/AGENT_INSTALL_PROMPT.md. Discover existing SSH aliases and VS Code remote-folder history locally, but do not upload those files or read any private keys or Keychain secrets. Ask me which server/folder to use if ambiguous. Preserve existing SSH configuration, running connections and VS Code settings. Explain any missing dependencies or system permissions; do not bypass them. Let me enter credentials in secure system/app prompts and approve host fingerprints and MFA myself. Verify what you can and clearly report anything requiring my action.

[Full agent installation prompt](docs/AGENT_INSTALL_PROMPT.md) · [中文说明](README.zh-CN.md)

Agents can build and install the app. They **cannot silently grant macOS Accessibility access, approve MFA, or authenticate unknown hosts**.

## Manual install

Requires macOS 13+, Apple Command Line Tools, Visual Studio Code, and Microsoft's Remote - SSH extension. Python 3 is needed for tests, not to run the app.

```sh
git clone https://github.com/xxyyffyeah/ssh-launch.git
cd ssh-launch
bash scripts/test.sh
bash scripts/install.sh
open "$HOME/Applications/SSH Launch.app"
```

The default installation is user-local and needs no sudo. To use a writable system Applications directory: `bash scripts/install.sh /Applications`.

The installer builds locally, signs ad hoc, and does **not** edit SSH/VS Code settings or access credentials. It backs up an existing SSH Launch app before an update.

## What it does

- Discovers named hosts from `~/.ssh/config` and Include files.
- Uses OpenSSH's effective configuration for host, username, port, jump hosts and authentication.
- Suggests folders from VS Code's local remote-workspace history and remembers your last selection per host.
- Prefers your existing SSH key/agent policy; optionally saves a recognizable target-server password in macOS Keychain.
- Reuses an authenticated SSH master for VS Code and Terminal. An on-demand helper keeps it independent of the launcher window.
- Restores a uniquely matching VS Code window and clicks a visible English/Chinese Reload/Reconnect button when available.
- Resolves and checks the remote folder before launching either client.
- Supports an optional **local pre-connect executable** for your VPN or network preparation.

See [setup and permissions](docs/INSTALL.md), [security model](SECURITY.md), and [architecture and limits](docs/ARCHITECTURE.md).

## First connection

1. Add a normal SSH Host entry if you do not already have one; see [examples](examples/ssh-config).
2. Enable **SSH Launch** in **System Settings → Privacy & Security → Accessibility**.
3. Choose the host and folder, then click **Start Connection**.
4. If the host lacks SSH connection sharing, the app asks before adding a managed Include and backing up your config.
5. Approve new host fingerprints after verifying them, and complete MFA yourself.
6. VS Code opens or reconnects; local Terminal opens the same directory after VS Code's connected status is detected.

SSH Launch does not send passwords through GUI keystrokes or the clipboard. Failed authentication stops without an automatic retry loop. A stale saved password can be removed with the documented `--forget-password ALIAS` command.

## Important scope

This is an early **0.1.0** source release, not a notarized universal installer. "Any server" means a user-configured SSH host supported by OpenSSH and VS Code Remote SSH, with a POSIX-compatible remote shell—not every OS or proprietary VPN client.

Window recovery depends on VS Code's accessibility UI and a unique alias/folder title; it is best-effort, not a guarantee across all editor versions and locales. Custom Remote SSH config files/executables must use the same connection-sharing settings. Terminal-only and Windows remote shells are not supported in this release.

The former personal launcher and its school-specific assets/configuration are not included. This repository has fresh history containing only the public source distribution.

## Development

```sh
bash scripts/test.sh
python3 scripts/audit.py
```

Tests use synthetic fixtures and never contact a server, read a real Keychain, or modify your real SSH config. GitHub Actions builds/tests on macOS and scans the published repository with Gitleaks.

## License

[MIT](LICENSE). The original geometric app icon is included under the same license. No university branding is distributed.
