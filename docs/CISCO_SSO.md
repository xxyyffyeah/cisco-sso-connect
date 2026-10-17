# Cisco VPN and SSO

Cisco VPN/SSO is the primary workflow. Both downstream app checkboxes are off by default.

## Setup

1. Install the Cisco Secure Client VPN module supplied by your organization. SSO Connect does not install or license Cisco software.
2. Grant SSO Connect Accessibility access for GUI automation.
3. Enter the organization's VPN endpoint (for example, vpn.example.com/group). HTTPS is required; URLs with embedded credentials, queries or fragments are rejected.
4. Click **SSO Settings** only if you want to configure supported embedded-page autofill.

Settings are local to your Mac:

- **SSO origin:** the exact HTTPS origin of the trusted identity provider, such as https://login.example.com. Scheme, hostname and port must match the embedded page. Do not guess the identity provider from a logo or page title.
- **Username:** optional, filled only into recognized username/email fields within that origin.
- **Password:** optional; entered in an NSSecureTextField and saved directly to Keychain. It is scoped to the VPN endpoint, SSO origin and username, separate from SSH credentials. A blank field keeps the existing item. To remove it, use Keychain Access and delete the desired “SSO Connect — Cisco SSO password” item.
- **Approved banner:** optional exact text of a banner you have already reviewed. Blank means no auto-accept. Only a matching static-text element in the Accept button's own window is eligible.
- **Use CLI connect:** opt-in for a deployment whose CLI SSO flow you have tested. GUI is the default for embedded SSO automation.

## Runtime

After upgrading from SSH Launch, existing saved items may retain the old "SSH Launch" label. Their service IDs are unchanged; they do not need to be saved again just for the rename.

The app checks Cisco's CLI-reported state, launches Cisco if needed, selects the configured endpoint, and clicks Connect once. It then polls for Connected for up to 180 seconds.

For recognizable embedded SSO pages, it can set the username and press Next once, populate a specifically labeled secure Password field from Keychain and submit once, and accept a configured banner once. It uses targeted accessibility values/actions, not password keystrokes, clipboard paste, or generic coordinate clicks.

If the trusted page origin is unavailable or the control layout cannot be identified, no credential is inserted. The user completes that step in Cisco. The app never operates arbitrary browser windows.

Cisco supports both embedded and external-browser authentication depending on the deployment. In external-browser mode, Cisco opens the browser; use your browser/password manager or sign in manually. SSO Connect waits for Cisco's connection state and does not automate the external browser. See [Cisco's SAML browser configuration documentation](https://www.cisco.com/c/en/us/td/docs/security/vpn_client/anyconnect/Cisco-Secure-Client-5/admin/guide/b-cisco-secure-client-admin-guide-5-0/configure_VPN.html).

In CLI mode, one connect request is started without injecting credentials into stdin or arguments. Embedded autofill is not run in that mode. On CLI failure, the app stops rather than issuing a second GUI attempt. The CLI interface is documented by [Cisco](https://www.cisco.com/c/en/us/td/docs/security/vpn_client/anyconnect/Cisco-Secure-Client-5/admin/guide/cisco-secure-client-admin-guide-new/customize-secure-client-intro/r_use_the_ac_cli_commands.html).

## Boundaries

- MFA/Duo, certificate warnings, unknown banners and organization policy decisions remain manual.
- The app never disconnects an existing VPN automatically. If Cisco already reports Connected, it retains that tunnel; it does not verify it is the newly entered gateway or switch profiles.
- Connected state confirms Cisco's tunnel, not reachability to every private service. Optional SSH checks independently verify their host/folder.
- User interface wording, secure-field accessibility and origin exposure vary across Cisco/IdP versions. Supported English/Chinese labels are deliberately narrow.
- The app does not record SSO page text, passwords or Cisco CLI output in logs.
- A locally configured pre-connect hook remains available for advanced remote-workspace setup, but it is not required for the built-in Cisco flow.
