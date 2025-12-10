# Release Notes: v1.9.0

## Release Information

- **Version:** 1.9.0
- **Release Date:** 2025-12-10
- **Released By:** Microsoft Copilot Growth ROI Advisory Team (copilot-roi-advisory-team-gh@microsoft.com)

---

## Overview

Version 1.9.0 introduces a single enhancement: **service principal authentication via `-Auth AppRegistration`**. This release enables fully unattended execution paths for enterprises that need to run the Purview Audit Log Processor in scheduled jobs, CI/CD pipelines, containerized workloads, or privileged access workstations that prohibit interactive logons.

All other functionality remains unchanged from v1.8.0. If you are satisfied with the existing interactive flows (`WebLogin`, `DeviceCode`, `Credential`, `Silent`) you do not need to modify your automation.

---

## What’s New

### AppRegistration Authentication Flow (Graph API Mode Only)

| Area | Details |
| --- | --- |
| **Purpose** | Enable Entra AD app registrations (service principals) to authenticate against Microsoft Graph when running the Purview Audit Log Processor. |
| **Availability** | Graph API mode only (default). The option is blocked when `-UseEOM` is supplied. |
| **New CLI support** | `-Auth AppRegistration` combined with the existing parameters `-TenantId`, `-ClientId`, and either `-ClientSecret`, `-ClientCertificateThumbprint`, or `-ClientCertificatePath` + `-ClientCertificatePassword`. |
| **Secrets & certificates** | Works with traditional client secrets, PFX certificates stored on disk, or certificates stored in the CurrentUser/LocalMachine certificate store. |
| **Fallback behavior** | If any required parameter is missing, the script halts with actionable notes instead of silently failing back to interactive auth. |

#### Why we built it

- Customers wanted **non-interactive** execution for scheduled exports without a standing administrator present.
- Security teams requested **stronger credential isolation** (certificates, Azure Key Vault secret rotation, managed service identities) rather than storing user passwords.
- MSP and multi-tenant operators needed **reliable service accounts** that can run across multiple customers without MFA prompts or cached tokens.

#### Upgrade guidance

1. **Create or reuse an Entra AD app registration** with the same Microsoft Graph application permissions already required by the script (AuditLog.Read.All, Directory.Read.All, etc.).
2. **Collect the credentials** that match your posture:
  - Client secret: store as a secure string and pipe into `-ClientSecret`.
  - Certificate thumbprint: ensure the certificate is installed in `CurrentUser` or `LocalMachine` and pass the thumbprint with `-ClientCertificateStoreLocation` when needed.
  - PFX file: store alongside your automation and protect access; pass the file path and a secure string password.
3. **Update scheduled jobs** to call:
  ```powershell
  $clientSecret = ConvertTo-SecureString "<client-secret>" -AsPlainText -Force
  ./PAX_Purview_Audit_Log_Processor_v1.9.0.ps1 `
     -Auth AppRegistration `
     -TenantId "<tenant-guid>" `
     -ClientId "<app-id>" `
     -ClientSecret $clientSecret `
     -StartDate (Get-Date).AddDays(-1) `
     -EndDate (Get-Date) `
     -ExportWorkbook `
     -CombineOutput `
     -OutputPath "C:\Exports\"
  ```
4. **Retain a fallback interactive run path** (WebLogin or DeviceCode) so operators can refresh cached tokens or troubleshoot if the service principal loses consent.

#### Backward compatibility

- Existing authentication modes continue to work without change.
- Scripts that supply `-Auth Silent` after a WebLogin/DeviceCode session continue to behave exactly as they did in v1.8.0.
- Scheduled tasks that do not pass the new mode will keep using whichever flow they already specify.

---

## Known Issues & Workarounds

- **Certificate trust chain:** If the certificate backing your app registration is not trusted on the host, authentication will fail with an AADSTS700027 error. Install the intermediate/chain certificates or switch to a PFX file loaded by the script.
- **Secret rotation:** The script does not rotate secrets for you. Align the credential lifetime with your enterprise rotation policy and update the automation when new secrets are generated.
- **Managed identities:** Native managed identity support is not included in v1.9.0. Use AppRegistration with certificates today; managed identity support is being evaluated for a future release.

---

## Action Items for Administrators

1. Review your existing scheduled jobs and decide whether a service principal run path is required.
2. If yes, provision the app registration credentials and update your automation as described above.
3. Document the chosen credential storage approach (Key Vault, Windows Credential Manager, etc.) for audit purposes.
4. Keep one interactive admin workflow available to re-consent the app registration when Graph permissions change.

---

## Looking Ahead

Thank you for partnering with the Microsoft Copilot Growth ROI Advisory Team as we continue to modernize the Purview Audit Log Processor.

---

## Release Information

- **Version:** 1.9.0
- **Release Date:** 2025-12-10
- **Released By:** Microsoft Copilot Growth ROI Advisory Team (copilot-roi-advisory-team-gh@microsoft.com)

---

## Support

For questions or issues, refer to the documentation:

- **Documentation v1.9.0 (Markdown):** [PAX_Purview_Audit_Log_Processor_Documentation_v1.9.0.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.9.0.md)

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com) with any feedback.*

---
