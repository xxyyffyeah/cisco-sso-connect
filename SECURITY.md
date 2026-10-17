# Security and privacy

## Credential handling

SSH Launch does not ship a password, token, private key, personal server address or account. It never exports an existing credential from another app. Optional target passwords are stored through the macOS Security framework under an endpoint-scoped Keychain service; secrets are not stored in files, command-line arguments, environment variables, clipboard or logs.

Plaintext credentials necessarily exist briefly in app memory and in SSH's askpass response pipe. This is not a secure-memory/zeroization implementation. Do not run the internal helper under a tracing wrapper or capture its output. A compromised local account or trusted local executable is outside this application's protection boundary.

Private key passphrases and MFA remain under the user's SSH agent / manual prompt flow. A recognized target password is never reused for a different alias, host, user, port or proxy route. Unknown/ambiguous prompts require the user.

The local ad-hoc signing identity is not a publisher authentication guarantee. Review source before building. We do not claim hardware-backed or notarized distribution.

## Configuration and local state

The installer does not touch SSH config. First-connection sharing setup is opt-in, scoped to a named alias and backed up. Host-key verification is never disabled.

Application state, session definitions and Terminal launchers contain aliases/paths but no credentials and are private to the local account. They are **personal information** and must not be attached to public issues. Managed sockets grant local-session reuse; protect your account and socket directory.

SSH configuration may contain ProxyCommand or Match exec. Like invoking ssh directly, using that configuration can execute local commands. Only use your own trusted configuration.

Optional VPN hooks execute locally with your privileges. Review them, avoid embedded secrets and do not rely on this app to validate a vendor's authentication flow.

## Reporting

Do not post credentials, full SSH configs, screenshots containing personal endpoints, or unredacted logs in public issues. Use GitHub's private vulnerability reporting if the repository offers it; otherwise open a minimal issue requesting a private contact method **without exploit details or sensitive material**.

There is no guarantee that pattern-based scans detect every secret. The initial publication uses a fresh allowlisted source tree plus a separate secret scan, not the original personal workspace or its history.

If a credential has already been pasted into chat, logs or another untrusted location, rotate it with the issuer. Removing it from a new source repository does not revoke prior exposure.
