# Installation prompt for Claude Code and Codex

Copy the following into your local coding agent. No MCP server, API key or special agent plugin is required.

```text
Install SSH Launch on this Mac from https://github.com/xxyyffyeah/ssh-launch.

1. Confirm this is macOS 13 or later. Use a fresh project directory; never overwrite an unrelated checkout. Read AGENTS.md, SECURITY.md, and docs/INSTALL.md. Inspect scripts/build.sh and scripts/install.sh before running them.
2. Check for Apple Command Line Tools, Python 3 for the tests, Visual Studio Code, and Microsoft's Remote - SSH extension. If a dependency is missing, explain it and ask before installing it. Do not install unrelated packages or request blanket privileges.
3. Run bash scripts/test.sh and python3 scripts/audit.py. Stop on failures and explain them. Install with bash scripts/install.sh to ~/Applications; do not replace other launchers. Verify the app signature and run its --doctor command.
4. Discover existing named SSH aliases and VS Code remote-folder history locally. Show only the minimal choices needed. Never read private key files, export Keychain entries, copy credentials into commands, or upload SSH config/history/logs. Ask which host/folder to use if the choice is ambiguous. Do not invent a hostname or account.
5. Do not edit SSH config during installation. Before any connection-sharing change, explain the specific alias and get consent. The app can perform a backed-up, scoped change on first connection. If explicitly authorized for unattended setup, use the installed binary's --configure-host ALIAS command; never replace the user's config wholesale.
6. Explain how to enable SSH Launch in System Settings > Privacy & Security > Accessibility. This system grant must be made by the user. Do not manipulate the permissions database or disable security checks.
7. Prefer the user's SSH keys and ssh-agent configuration. Never generate/upload a key, enable agent forwarding, change server auth policy, or overwrite a saved credential without specific permission. If a password is required, let the user enter it into the native secure prompt, where saving to Keychain is optional.
8. Ask before configuring a VPN/pre-connect executable. Keep it local, use the actual vendor's supported interface, never put secrets in it, and leave MFA to the user. No VPN is required for ordinary reachable SSH hosts.
9. After the user authorizes a live test, launch SSH Launch once. Verify the selected remote folder and both VS Code and local Terminal if the environment permits. Do not blindly repeat connections, dismiss unknown host fingerprints, approve MFA, or close the user's existing sessions.
10. Report exactly what passed: build, offline tests, signature, installation, config changes/backups, permissions, and live connection. Explicitly state anything blocked or not tested. Give the app's installed path and the next necessary user action.
```

The prompt works as ordinary task instructions in both agents. Codex discovers repository guidance through [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md); Claude Code supports project instructions through [CLAUDE.md](https://code.claude.com/docs/en/memory). Neither instruction file grants OS permissions.
