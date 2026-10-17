# SSO Connect

Previously SSH Launch. [Upgrade notes](docs/INSTALL.md#upgrading-from-ssh-launch): existing settings and Keychain items keep their stable identifiers.

**One-click Cisco VPN / SSO automation for macOS — with optional VS Code and Terminal launch.**

The main job is to open Cisco Secure Client, connect to your configured VPN endpoint, advance supported SSO steps, and wait for Cisco to confirm the tunnel is connected. Opening a remote workspace is an optional follow-up, not a requirement.

No university-specific VPN address, account, password or project path is built in.

## Connect VPN first; choose what happens next

- **Cisco VPN / SSO:** enabled by default. Select the endpoint, click Connect once, handle supported embedded SSO steps, optionally accept an explicitly approved banner, and wait for connected status.
- **Open VS Code:** optional, off by default. Restore/open a selected Remote SSH workspace.
- **Open local Terminal:** optional, off by default. Connect to the same SSH host and directory, independently of whether VS Code is enabled.

You can use **VPN only**, VPN + either app, or VPN + both apps. Turn Cisco off for SSH-only use. Selections are remembered. VPN-only mode needs neither VS Code nor an SSH configuration.

## What “SSO automation” means

Cisco launches the authentication flow. For supported embedded pages, optional autofill is restricted to an exact trusted HTTPS login origin and explicitly labeled username/password fields. A separately configured SSO password is read from macOS Keychain, never from a script.

Connect, username Next, password submit and approved-banner Accept are each attempted at most once per run. **MFA, unknown banners, external-browser authentication and unrecognized pages remain under your control.** Browser/password-manager autofill can handle external-browser login. This is not a universal unattended SSO or MFA-bypass tool.

See [Cisco / SSO setup](docs/CISCO_SSO.md) for supported behavior and limitations.

## Install with Claude Code or Codex

Paste this into either agent on your Mac:

> Install https://github.com/xxyyffyeah/cisco-sso-connect. Read AGENTS.md, docs/INSTALL.md and docs/AGENT_INSTALL_PROMPT.md, inspect the scripts, then build, run the offline tests and install to ~/Applications. This is primarily a Cisco VPN/SSO automation tool. Discover the installed Cisco client and configured VPN endpoint locally; ask me when ambiguous. Leave Open VS Code and Open local Terminal off unless I choose them. Only inspect SSH aliases/folder history if I enable a remote app. Do not read private keys, export Keychain secrets, upload local configuration, or ask me to paste passwords into chat. Let me enter credentials in the native secure SSO Settings dialog and approve system permissions, fingerprints and MFA myself. Preserve existing VPN/SSH sessions. Verify what is safe, and clearly report anything not tested.

[Full installation prompt](docs/AGENT_INSTALL_PROMPT.md) · [中文说明](README.zh-CN.md)

## Manual install

Requires macOS 13+, Apple Command Line Tools, and Python 3 for tests. Install your organization's Cisco Secure Client VPN module for VPN mode. VS Code + Microsoft's Remote - SSH extension are needed **only if Open VS Code is selected**.

```sh
git clone https://github.com/xxyyffyeah/cisco-sso-connect.git
cd cisco-sso-connect
bash scripts/test.sh
bash scripts/install.sh
open "$HOME/Applications/SSO Connect.app"
```

Installation is user-local, requires no sudo, and does not edit SSH/VS Code settings or collect credentials. A previous SSO Connect app is backed up before updating.

## First connection

1. Enable SSO Connect in **System Settings → Privacy & Security → Accessibility** for Cisco GUI automation.
2. Enter your organization's VPN endpoint. Optional **SSO Settings** configure a trusted login origin, username, Keychain-only password, approved banner and connection method.
3. Leave the optional apps unchecked for VPN-only use, or select VS Code and/or Terminal and choose an SSH host/folder.
4. Click **Start Connection**. Approve MFA and unfamiliar prompts yourself.
5. The optional apps run only after Cisco reports Connected. An existing connected tunnel is retained, not disconnected or switched automatically.

For optional remote workspaces, the app discovers SSH aliases and VS Code history locally, prefers your SSH key/agent policy, scopes saved SSH passwords to the target identity, and reuses an authenticated master connection. Sharing configuration is changed only with consent and a backup.

## Scope and security

This is **0.2.1**, a locally built, ad-hoc-signed source release—not a notarized universal installer. It is not affiliated with Cisco. Embedded SSO accessibility varies by deployment; unknown layouts require manual completion. GUI mode is the default for SSO; CLI mode is available for deployments where you have verified it works. Neither mode retries authentication automatically.

Remote features require OpenSSH-compatible hosts and a POSIX shell. Window reuse is best-effort and depends on VS Code's accessibility UI. [Setup](docs/INSTALL.md) · [Security](SECURITY.md) · [Architecture](docs/ARCHITECTURE.md)

## Development and license

```sh
bash scripts/test.sh
python3 scripts/audit.py
```

Offline tests use synthetic fixtures, not a real VPN, server or Keychain. GitHub Actions builds/tests on macOS and scans Git history with Gitleaks. Passing tests does not certify live SSO compatibility with your organization.

[MIT](LICENSE). Only original geometric icon artwork is distributed; no Cisco or university logos.
