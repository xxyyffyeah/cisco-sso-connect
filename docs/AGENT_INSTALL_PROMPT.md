# Installation prompt for Claude Code and Codex

Copy the following into your local coding agent. No MCP server, API key or special agent plugin is required.

```text
Install SSH Launch from https://github.com/xxyyffyeah/ssh-launch on this Mac. Its primary purpose is Cisco VPN/SSO automation; VS Code and local Terminal are optional.

1. Confirm macOS 13+. Use a fresh checkout, read AGENTS.md, SECURITY.md, docs/INSTALL.md and docs/CISCO_SSO.md, and inspect the build/install scripts.
2. Check Apple Command Line Tools and Python 3 for tests. Discover the installed Cisco Secure Client VPN module and configured endpoint locally without printing/exporting secrets. If several profiles exist, ask me which one to use. Do not guess an endpoint or install/modify organization-managed Cisco software.
3. Run bash scripts/test.sh and python3 scripts/audit.py, then bash scripts/install.sh. Verify the installed signature and --doctor output. Install to ~/Applications without replacing other launchers.
4. Configure the Cisco endpoint only after the choice is clear. Explain SSO Settings: trusted HTTPS login origin, username, optional Keychain-only password, and an optional exact banner I have reviewed. Never retrieve a password into the agent context or ask me to paste it into chat. Let me enter it into the app's secure field. Do not guess a trusted origin or approve a banner for me.
5. Leave Open VS Code and Open local Terminal OFF unless I select them. Ask whether I want neither, either one, or both. VPN-only mode does not require VS Code, SSH config, keys or project paths. Do not install optional dependencies or read remote workspace history when those features are unused.
6. Only for selected remote apps, discover existing SSH aliases/folder history locally. Ask about ambiguous host/folder choices. Preserve existing SSH config and editor settings; connection-sharing edits require consent and a backup. Prefer SSH keys/ssh-agent and never read private keys or export Keychain entries.
7. Explain Accessibility setup in System Settings > Privacy & Security > Accessibility. Let me grant system permissions, verify host fingerprints and approve MFA/Duo. Do not change security databases, disable checks, or approve organization prompts.
8. Prefer a vendor-supported connection method compatible with the actual SSO deployment. Use GUI mode for the built-in embedded-page automation; enable CLI connect only when compatibility is established. Unknown pages/external browsers must be completed by me or my password manager. Do not repeatedly trigger login.
9. Ask before a live connection test that could affect my network. Do not disconnect an existing VPN or terminate SSH/editor sessions. Verify Cisco's state and only the optional clients I enabled. Distinguish an existing connected tunnel from a freshly tested SSO login.
10. Report build/tests, install path, selected options, setup changes, permissions and live checks separately. Explicitly state which SSO steps were not tested and any manual approval still required. Never upload personal configs, logs or screenshots.
```

Codex discovers repository guidance through [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md); Claude Code supports project instructions through [CLAUDE.md](https://code.claude.com/docs/en/memory). Neither file grants OS permissions.
