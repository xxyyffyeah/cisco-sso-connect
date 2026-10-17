# Repository guidance

SSO Connect primarily automates Cisco VPN/SSO on macOS. VS Code and local Terminal are independent optional outputs, off by default. Read docs/INSTALL.md and docs/CISCO_SSO.md before installing; use docs/AGENT_INSTALL_PROMPT.md for the workflow.

- Never read or print private keys, passwords, tokens, Keychain values or full personal SSH configuration. Never ask users to paste secrets into agent chat.
- Do not publish local hosts, account names, remote paths, screenshots, logs, application bundles or runtime state. Examples use reserved example.com names.
- Build: bash scripts/build.sh. Test: bash scripts/test.sh. Public-file audit: python3 scripts/audit.py.
- Install to ~/Applications by default. Do not use sudo, bypass Gatekeeper/TCC, reset permissions, or kill existing SSH/VS Code sessions.
- Installing does not authorize remote commands. Ask for the host/folder and consent to a live connection when ambiguous.
- Any SSH configuration edit must be scoped, backed up, and approved. Never set StrictHostKeyChecking=no or disable an organization's authentication policy.
- Use the native secure prompt for credentials. MFA and host-fingerprint approval stay human.
- Do not broaden privileges or spawn agents as an installation shortcut.
- Do not install VS Code or inspect SSH history when optional remote apps are unused. Never disconnect an existing VPN for a test without explicit authorization. Do not guess a trusted SSO origin or automatically approve an unknown banner.
- Preserve the stable bundle identifier/signing requirement across builds.
- Report build, offline tests, installation and live verification separately; do not infer end-to-end success from an open window.
