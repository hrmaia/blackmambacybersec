# M-Files Desktop Client — Silent Install Customization

## What it does
A VBScript wrapper around the M-Files desktop client MSI that:

- Installs silently (no user interaction) for RMM/Intune deployment.
- Pre-configures the default vault connection (server address, vault GUID)
  so users don't have to manually add it on first login.
- Writes a small registry marker so re-deployment/detection logic (RMM,
  Intune Win32 app detection rule) can confirm success without relying on
  MSI exit codes alone.

## Where/how it was used
Deployed across multiple client tenants via RMM/Intune. The trigger for
building this wrapper was a multi-tenant authentication issue: for accounts
provisioned via **Cross-Tenant Sync**, the resource-tenant UPN gets a `#EXT#`
suffix (e.g. `alice_clientorg-a.blackmambacyber.com#EXT#@clientorg-b.onmicrosoft.com`).
The out-of-the-box M-Files desktop client didn't resolve that UPN format
cleanly against the configured vault during SSO, causing repeated auth
prompts/failures — while the M-Files web client handled it fine.

This script's job is purely the deployment/pre-configuration side (silent
install + vault pre-config); the actual `#EXT#` UPN handling was resolved via
M-Files server-side authentication configuration, not in this script — noted
here since both issues surfaced in the same engagement and are easy to
conflate.

## Usage
Intended to run as the install command from an RMM script or Intune Win32 app:

```
cscript.exe //nologo CustomizeInstall.vbs "\\server\share\MFilesClient.msi" "vault.clientorg-a.blackmambacyber.com" "{VAULT-GUID-PLACEHOLDER}"
```

Arguments: `MsiPath`, `VaultServer`, `VaultGuid`

## Notes
- Placeholder server/vault values — replace with real values per tenant.
- Detection registry key: `HKLM\SOFTWARE\BlackMambaCyber\MFilesDeploy`
