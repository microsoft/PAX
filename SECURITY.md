# Security Guidance

This document complements the README with security posture details and enterprise hardening guidance for the Purview Audit Exporter.

## Threat Model (high level)
- Data sources: Microsoft 365 Purview (Unified Audit Log) via `ExchangeOnlineManagement`.
- Local artifacts: PowerShell stdout/stderr logs and CSV export files.
- Actors: Authorized operators with sufficient tenant permissions; desktop process with user rights.
- Goals: Prevent unauthorized access to audit data, avoid unintended system changes, and minimize leakage through logs/outputs.

## Permissions and Access Control
- Tenant roles: Use least-privilege roles that allow viewing/searching audit logs (e.g., View-Only Audit Logs). Avoid broad admin roles when possible.
- Conditional Access: If Conditional Access policies affect PowerShell logins, prefer `WebLogin` or `DeviceCode` flows that comply with your MFA requirements.
- Service principals: This tool is designed for interactive user auth. For automated service principals, consider building a server-side job with appropriate app permissions.

## Authentication Flows
- `WebLogin` (default): Interactive browser auth; resilient and aligns with most MFA policies.
- `DeviceCode`: Use when embedded browsers are restricted; copy/paste the device code into a separate browser session.
- `Credential`: Uses Windows secure credential prompt; should only be used if policy allows and MFA is accounted for.
- `Silent`: Attempts silent token usage and falls back to web auth if not possible.

## PowerShell Module Installation
- The app/script installs `ExchangeOnlineManagement` if missing. Prefer per-user installation:
  - `Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber`
- Enterprises may preinstall and manage allowed module versions via internal repositories to control provenance and updates.

## Execution Policy
- The backend invokes PowerShell with `-NoProfile -ExecutionPolicy Bypass` to avoid end-user profile interference and ensure predictable execution.
- In locked-down environments:
  - Consider distributing a signed `CopilotAuditExport.ps1` and configuring `AllSigned` policy.
  - Use AppLocker/WDAC to restrict which scripts can run.

## Network Destinations
- Only Microsoft endpoints used by EXO/SCC modules (e.g., `outlook.office365.com`, `ps.compliance.protection.outlook.com`, and regional equivalents).
- No telemetry or third-party network calls are made by this exporter.

## Logging and PII
- Logs can include user identifiers, operation names, counts, and error messages.
- Treat logs as sensitive; store locally and avoid uploading to external systems unless approved.
- Consider enabling PSReadLine transcription or central logging under your security policy if needed, but avoid duplicating sensitive content.

## Data at Rest (CSV Output)
- The CSV contains audit records and can include user IDs, resource URLs, and other metadata.
- Store in protected locations; apply DLP labels or encryption as per your policy.
- CSV injection: If opening in Excel, crafted values might be interpreted as formulas. Consider sanitizing fields (e.g., prefix `=`-leading cells with a `'`) if sharing widely.

## Cancellation Behavior
- The UI cancels exports by terminating the child PowerShell process (`taskkill /T /F` on Windows; `kill -9` on Unix).
- This may leave partial outputs; rerun to generate complete results.

## Integrity and Supply Chain
- Pin module versions where practical and vet updates.
- Prefer signed PowerShell scripts. If you sign `CopilotAuditExport.ps1`, adjust the build to avoid editing the signed script after signing.
- Keep the bundled script/datasets in source control; review diffs during PRs.

## Hardening Checklist (Enterprise)
- Preinstall `ExchangeOnlineManagement` for all operators (CurrentUser scope or managed repository).
- Enforce least-privilege RBAC for audit log access.
- Use `WebLogin`/`DeviceCode` with MFA; avoid `Credential` where policy forbids.
- Distribute a signed exporter script and use `AllSigned` policy.
- Place output in an encrypted or label-enforced folder.
- Add endpoint protection exclusions only if necessary and after review.
- Monitor usage: consider wrapping the desktop app with an enterprise launcher or logging usage events (without exporting sensitive data).

## Reporting Issues
- If you suspect a security issue, avoid posting details in public channels. Use your internal security incident process, or open a private issue with minimal detail and request a secure channel for follow-up.
