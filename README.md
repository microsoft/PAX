# Portable Audit eXporter (PAX) Solution Set

<table>
<tr>
<td bgcolor="#FFF8C5">
<font color="#000000">

<h3>⚠️ Sensitive Data Warning — Customer Responsibility</h3>

**The audit data exported by this script is highly sensitive.** Output may contain user identifiers (UPN, email, GUID), file/site/resource paths, conversation and message IDs, agent identifiers, prompt/response metadata (timestamps, lengths, classifications), and other personally identifiable information drawn directly from your tenant's Unified Audit Log.

- **Data is NOT hashed, masked, redacted, anonymized, or de-identified** in any way. Records are exported in their raw, attributable form exactly as Microsoft Purview returns them.
- Outputs (CSV/Excel/JSON metrics, checkpoint files, logs) may contain confidential business content, regulated data (PII, PHI, financial, IP), and end-user communications.
- **The customer (you / your organization) is solely responsible** for the secure handling, storage, transmission, retention, disclosure, access control, and deletion of all data produced by this script, and for ensuring its use complies with all applicable laws, regulations, contractual obligations, and internal policies — including but not limited to GDPR, HIPAA, CCPA, employee monitoring laws, works-council agreements, and data-residency requirements.
- **Microsoft has no visibility into, control over, or responsibility for** the data customers extract using this tool or how that data is subsequently used, shared, or stored. Microsoft disclaims any and all liability arising from or related to customer use of this script and its output.
- Treat all output files as **Highly Confidential**. Restrict access to authorized personnel with a documented business need. Encrypt at rest and in transit. Apply tenant DLP / sensitivity labels as appropriate.

</font>
</td>
</tr>
</table>

<br>

---

<div align="center">

<a href="https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.11.x.md">
  <img src="assets/pax-logo.png" alt="PAX — Portable Audit eXporter" width="380">
</a>

</div>

## 🔍 Purview Audit Log Processor

> Download the script → [`PAX_Purview_Audit_Log_Processor_v1.11.3.ps1`](https://github.com/microsoft/PAX/releases/download/purview-v1.11.3/PAX_Purview_Audit_Log_Processor_v1.11.3.ps1) | Release Date: 2026-06-01
>
> **📖 Resources:** [Latest Documentation](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.11.x.md) | [Latest Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.11.x.md)
>
> **📚 Archives:** [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Purview_Audit_Log_Processor) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Purview_Audit_Log_Processor) | [Previous Versions](https://github.com/microsoft/PAX/tree/release/script_archive/Purview_Audit_Log_Processor)

---

## What is PAX?

**Portable Audit eXporter (PAX)** is a set of enterprise-grade PowerShell scripts that export Microsoft 365 Copilot, AI agent, and broader workload usage data out of Microsoft Purview and Microsoft Graph into analysis-ready CSV or Excel — ready for Power BI, Microsoft Fabric, or your preferred analysis tool.

The flagship script in the set — and the one most customers will use — is the **Purview Audit Log Processor**. It retrieves Microsoft 365 Copilot, AI agent, and broader workload audit records from the Microsoft Purview Unified Audit Log via Microsoft Graph API (default) or Exchange Online Management (EOM). It is the script designed to power the **Microsoft Copilot Growth ROI Analytics team's Power BI templates** published in the [**Microsoft Analytics Hub**](https://github.com/microsoft/Analytics-Hub) — the central landing page for our team's PBI templates, dashboards, and companion analytics tooling (AI-in-One Dashboard, M365 Usage Analytics Dashboard, Copilot Chat & Agent Intelligence Dashboards, and the broader ROI / adoption / governance visualization library).

Highlights of the Purview Audit Log Processor:

- Microsoft 365 Copilot, Unlicensed Copilot, and AI agent signal coverage
- **Microsoft 365 Usage Bundle** for productivity-workload activity (Teams, Exchange, SharePoint, OneDrive, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, PowerApps) captured in the same run alongside Copilot telemetry
- **Entra ID user + Microsoft 365 Copilot (MAC) licensing enrichment**
- Long-running enterprise exports with checkpoint & resume, append capabilities, rolled up data architecture support to shrink data footprint, parallel processing, adaptive time-slicing, and server record limit detection and override
- Flexible filtering by user, group, agent, activity type, record/service type, and date range
- **Flexible output destinations:** local folder, SharePoint document library, or directly into **Microsoft Fabric (OneLake)** Delta tables — for unattended Azure-hosted runs, paired with Managed Identities

The PAX set also includes two specialized companion scripts for narrower use cases:

- **Copilot Interactions Content Audit Log Processor** — pulls the **actual prompt and response content** of Microsoft 365 Copilot interactions directly from the Graph `aiInteraction` resource type (content-rich analysis with optional body text), with incremental watermark exports and user enrichment. Use this when you specifically need interaction *content*, not just usage telemetry.
- **Graph Audit Log Processor** — a lightweight Graph-API-only export of Copilot usage records together with Entra user/organizational details and Copilot licensing. Use this when you do **not** need Purview Unified Audit Log coverage.

> Most customers only need the Purview Audit Log Processor. The other two scripts are not replacements for it — they target different data sources and narrower scenarios. If you are unsure which to use, start with the Purview Audit Log Processor.

---

<div align="center">

<a href="https://paxcookbook.com">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/pax-cookbook-logo-horizontal-white.png">
    <source media="(prefers-color-scheme: light)" srcset="assets/pax-cookbook-logo-horizontal-blue.png">
    <img src="assets/pax-cookbook-logo-horizontal-blue.png" alt="PAX Cookbook" width="420">
  </picture>
</a>

### PAX is the engine. **PAX Cookbook** is the kitchen around it. 🧑‍🍳

</div>

The scripts above are the **PAX engine** — powerful, but you bring every switch, path, and command yourself. **[PAX Cookbook](https://paxcookbook.com)** is a friendly Windows app that runs that same engine *for* you: guided forms instead of switches, saved recipes instead of copy-paste, and a tidy kitchen instead of a terminal. It's the easiest way to get the most out of PAX — and it's free and open source on Microsoft GitHub.

**Why most people use PAX Cookbook instead of running the script by hand:**

- 🍳 **Recipes** — save a run once (dates, scope, output), reopen and re-run it in a click; no syntax to memorize
- ✅ **Taste Tests** — a preflight check catches missing fields and bad paths *before* you commit to a full run
- 📒 **Bakes & history** — every run is recorded with status, output files, and scrollable logs
- 🔑 **Chef's Keys** — credentials live in Windows Credential Manager, never in recipes, logs, commands, or output
- 📤 **Flexible destinations** — bake straight to a local folder, a **SharePoint** document library, or **Microsoft Fabric (OneLake)** Delta tables — no extra scripting
- ⏰ **Scheduled bakes** — hand any recipe to Windows Task Scheduler for automatic daily/weekly/monthly runs
- 🔄 **Always current** — on install the app fetches the latest PAX engine straight from this repo for you, and it keeps both the app and the engine up to date in place — no return trips to GitHub, no version hunting

<div align="center">

### ⬇️ **[Get PAX Cookbook →](https://paxcookbook.com)**

*Free · open source · local-first · credential-safe · no audit data stored in the app*

</div>

<br>

<div align="center">

### Prefer the command line? Meet **PAX Cookbook Mini-Kitchen**

</div>

Still want to run PAX directly in PowerShell? **[Mini-Kitchen](https://paxcookbook.com/Mini-Kitchen)** is a browser-only companion (no install) whose whole job is to **build a clean, copy-ready PAX command line for you to paste into your own terminal** — so you never hand-write paths and switches again. You point-and-click your options, Mini-Kitchen renders the exact `pwsh` command, you copy it, and **you run it yourself against the PAX script downloaded from this repo.** Mini-Kitchen never runs PAX for you; it only writes the command. It ships ready-made presets for the **AI-in-One** and **M365 Usage Analytics** dashboards (and others), saves recipes right in your browser, and exports portable **`.paxlite`** files you can later import into the full PAX Cookbook app.

**It does not touch your tenant or your data.** Mini-Kitchen uses **no user credentials, app-registration secrets, or certificates**, and it pulls **no audit data and no user/Entra information** — none of that is ever entered into or handled by Mini-Kitchen. It does **not** connect to your Microsoft 365 tenant, Microsoft Graph, Purview, or your SharePoint/Fabric/local storage. The *only* thing it reads or writes is the recipe file you choose to export or import (`.paxlite`) — and that file likewise contains **no user credentials, app-registration secrets, or certificates, and no audit or user data**; it only holds your saved command options and stays entirely on your device. All of the actual authentication and data export happens later, when **you** run the generated command yourself in your terminal.

<div align="center">

### ⌨️ **[Open Mini-Kitchen →](https://paxcookbook.com/Mini-Kitchen)**

*Browser-only · no install · no tenant connection · no credentials or data*

</div>

---

### Companion scripts (specialized use cases only)

#### 💬 Copilot Interactions Content Audit Log Processor

For pulling raw Copilot prompt/response content.

- Download: [`PAX_CopilotInteractions_Content_Audit_Log_Processor_v2.0.0.ps1`](https://github.com/microsoft/PAX/releases/download/copilotinteractions-v2.0.0/PAX_CopilotInteractions_Content_Audit_Log_Processor_v2.0.0.ps1)
- Resources: [Documentation](https://github.com/microsoft/PAX/blob/release/release_documentation/CopilotInteractions_Content_Audit_Log_Processor/PAX_CopilotInteractions_Content_Audit_Log_Processor_Documentation_v2.0.0.md) | [Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/CopilotInteractions_Content_Audit_Log_Processor/PAX_CopilotInteractions_Content_Audit_Log_Processor_Release_Note_v2.0.0.md)
- Archives: [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/CopilotInteractions_Content_Audit_Log_Processor) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/CopilotInteractions_Content_Audit_Log_Processor) | [Previous Versions](https://github.com/microsoft/PAX/tree/release/script_archive/CopilotInteractions_Content_Audit_Log_Processor)

#### 📊 Graph Audit Log Processor

For lightweight Graph-API-only Copilot usage + Entra user/licensing exports.

- Download: [`PAX_Graph_Audit_Log_Processor_v1.0.1.ps1`](https://github.com/microsoft/PAX/releases/download/graph-v1.0.1/PAX_Graph_Audit_Log_Processor_v1.0.1.ps1)
- Resources: [Documentation](https://github.com/microsoft/PAX/blob/release/release_documentation/Graph_Audit_Log_Processor/PAX_Graph_Audit_Log_Processor_Documentation_v1.0.1.md) | [Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Graph_Audit_Log_Processor/PAX_Graph_Audit_Log_Processor_Release_Note_v1.0.1.md)
- Archives: [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Graph_Audit_Log_Processor) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Graph_Audit_Log_Processor) | [Previous Versions](https://github.com/microsoft/PAX/tree/release/script_archive/Graph_Audit_Log_Processor)

---

## Support

For questions or issues, refer to the documentation links next to each script above.

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com) with any feedback.*

---

© Microsoft Corporation — MIT Licensed
