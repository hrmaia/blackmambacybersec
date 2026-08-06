# M-Files SSO via Entra ID Dynamic Groups

## What it does
Two PowerShell scripts that implement end-to-end SSO for M-Files using
**Entra ID Dynamic Security Groups**, keyed off `extensionAttribute2` as the
role/vault-assignment flag, rather than manual static group membership.

- `Set-ExtensionAttributeForVaultAccess.ps1` — bulk-tags users with the
  `extensionAttribute2` value M-Files expects, from a CSV list (upn, vault role).
- `New-MFilesDynamicSecurityGroup.ps1` — creates the Entra ID Dynamic Group(s)
  with the correct membership rule, so group membership self-maintains as
  `extensionAttribute2` changes (new hires, role changes, offboarding).

## Where/how it was used
Implemented across two client tenants with different identity setups:

- **Tenant A (cloud-only):** straightforward — attribute set directly in Entra ID.
- **Tenant B (hybrid, Entra Connect):** `extensionAttribute2` had to be set
  on-prem in AD and synced up, since it's a directory-extension attribute that
  Entra Connect owns for synced objects — setting it directly in Entra ID for a
  synced user gets overwritten on the next sync cycle.

A related issue surfaced during rollout: for **cross-tenant synced users**
(via Cross-Tenant Sync), the M-Files desktop client failed to authenticate
because those accounts get a `#EXT#` UPN suffix in the resource tenant, which
the M-Files desktop client didn't handle the same way as the web client. That
was resolved on the M-Files server-side auth configuration, not in these
scripts — noted here for context since it came up during the same engagement.

## Usage
```powershell
# 1. Tag users (run against on-prem AD if hybrid-synced, else directly in Entra ID)
.\Set-ExtensionAttributeForVaultAccess.ps1 -CsvPath .\users.csv -Hybrid

# 2. Create the Dynamic Group once the attribute is populated and synced
.\New-MFilesDynamicSecurityGroup.ps1 -GroupName "MFiles-VaultA-Users" -AttributeValue "VaultA-ReadWrite"
```

`users.csv` format:
```
UserPrincipalName,VaultRole
alice@clientorg-a.blackmambacyber.com,VaultA-ReadWrite
bob@clientorg-a.blackmambacyber.com,VaultA-ReadOnly
```

## Requirements
- `ActiveDirectory` module (hybrid path only)
- `Microsoft.Graph` PowerShell SDK (`Install-Module Microsoft.Graph -Scope CurrentUser`)
- Permissions: `User.ReadWrite.All`, `Group.ReadWrite.All` (Graph); Domain Admin
  or delegated attribute-write rights (on-prem AD path)
