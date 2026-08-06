# Black Mamba Cybersecurity — Field Scripts Portfolio

A collection of scripts and tooling built while solving real MSP/IT infrastructure
problems, organized here for portfolio and reference purposes.

**Contact:** hebert@blackmambacyber.com
**Site:** blackmambacybersecurity.com

## ⚠️ A note on provenance

The scripts in this repo were **reconstructed from memory and project notes**,
not copy-pasted from the original client environments. They accurately represent
the approach, logic, and structure of the real solutions, but:

- All company, tenant, and domain names have been replaced with generic
  placeholders (`clientorg-a.onmicrosoft.com`, etc.) or `@blackmambacyber.com`
  examples.
- Any tenant IDs, hostnames, license keys, or internal identifiers are fabricated
  placeholders — not real values.
- Minor implementation details may differ slightly from the originals since they
  are rebuilt from summary notes rather than the live files.

Each project folder has its own README with more specific context on what problem
it solved, where it was used, and how.

## Projects

| Folder | Problem solved | Stack |
|---|---|---|
| [`ninjaone-datto-deployment-tracker`](./ninjaone-datto-deployment-tracker) | Cross-referencing NinjaOne RMM rollout against legacy DattoRMM across ~22 client orgs, with historical progress tracking | Python, pandas, openpyxl |
| [`mfiles-sso-entra-id`](./mfiles-sso-entra-id) | End-to-end SSO for M-Files using Entra ID Dynamic Groups, across a cloud-only and a hybrid (Entra Connect) tenant | PowerShell, Microsoft Graph |
| [`mfiles-msi-customization`](./mfiles-msi-customization) | Silent, pre-configured M-Files desktop client install across multiple tenants, fixing MSI/VBScript packaging issues | VBScript, MSI |
| [`ad-threat-hunting-user-lookup`](./ad-threat-hunting-user-lookup) | During incident response: pull a suspect AD account's effective (direct + nested) group membership and flag privileged access; reverse lookup to expand a group's full membership | PowerShell, Active Directory |

More scripts will be added here as they're reconstructed/organized.
