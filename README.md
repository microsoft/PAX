<div align="center">

# Portable Audit eXporter (PAX) Solution Set

<a href="https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.11.x.md"><img src="assets/pax-logo.png" alt="PAX Portable Audit eXporter" height="85" align="middle"></a>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<a href="https://microsoft.github.io/PAX-Cookbook"><picture><source media="(prefers-color-scheme: dark)" srcset="assets/pax-cookbook-logo-horizontal-white.png"><source media="(prefers-color-scheme: light)" srcset="assets/pax-cookbook-logo-horizontal-blue.png"><img src="assets/pax-cookbook-logo-horizontal-blue.png" alt="PAX Cookbook" height="85" align="middle"></picture></a>

<br>

<table>
<tr>
<td>

<h3 align="center">PAX PowerShell Script&nbsp;&nbsp;|&nbsp;&nbsp;PAX Cookbook&nbsp;&nbsp;|&nbsp;&nbsp;PAX Cookbook Mini-Kitchen</h3>

**⬇️ Download the script:** [`PAX_Purview_Audit_Log_Processor_v1.11.9.ps1`](https://github.com/microsoft/PAX/releases/download/purview-v1.11.9/PAX_Purview_Audit_Log_Processor_v1.11.9.ps1) &nbsp;|&nbsp; Release Date: June 25, 2026

**📖 Script Resources:** [Latest Documentation](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.11.x.md) | [Latest Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.11.x.md)

**📚 Script Archives:** [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Purview_Audit_Log_Processor) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Purview_Audit_Log_Processor) | [Previous Versions](https://github.com/microsoft/PAX/tree/release/script_archive/Purview_Audit_Log_Processor)

**🧑‍🍳 PAX Cookbook (Windows App):** [Get PAX Cookbook →](https://microsoft.github.io/PAX-Cookbook)

**⌨️ PAX Cookbook Mini-Kitchen:** [Open Mini-Kitchen →](https://microsoft.github.io/PAX-Cookbook/mini-kitchen)

</td>
</tr>
</table>

</div>

---

## What is PAX?

**Portable Audit eXporter (PAX)** is a solution set for exporting Microsoft 365 Copilot, AI agent, and broader workload usage data into analysis-ready CSV — or straight into **Microsoft Fabric (OneLake) Delta Lake tables** — ready for Power BI or your preferred analysis tool. It uses the **Microsoft Graph API** to pull that data from **Microsoft Purview** (the Unified Audit Log), **Microsoft Entra ID** (user and organizational details), and the **Microsoft 365 Admin Center (MAC)**. It is the toolset designed to power the **Microsoft Copilot Growth ROI Advisory team's Power BI templates** published in the [**Copilot Analytics Lab**](https://microsoft.github.io/CopilotAnalyticsLabs) — frontier analytics for Copilot and agents, offering guided dashboard templates, ready-to-run sample code, and proven playbooks grounded in real customer deployments to help you design and deploy analytics beyond what's available in Viva Insights today (including the AI-in-One Dashboard, AI Business Value Dashboard, M365 Usage Dashboard, and more).

There are three ways to use PAX. They are listed below in the order most customers should consider them.

### 1. 🧑‍🍳 PAX Cookbook — the Windows app (recommended for most people)

> 🏷️ **Coming soon**

**[PAX Cookbook](https://microsoft.github.io/PAX-Cookbook)** is a friendly, free, open-source Windows app that runs the PAX engine *for* you: guided forms instead of switches, saved recipes instead of copy-paste, and a tidy kitchen instead of a terminal. It's the easiest way to get the most out of PAX — no syntax to memorize and no paths to hand-write.

- 🍳 **Recipes** — save a run once (dates, scope, output), reopen and re-run it in a click
- ✅ **Taste Tests** — a preflight check catches missing fields and bad paths *before* you commit to a full run
- 📒 **Bakes & history** — every run is recorded with status, output files, and scrollable logs
- 🔑 **Chef's Keys** — credentials live in Windows Credential Manager, never in recipes, logs, commands, or output
- 📤 **Flexible destinations** — bake straight to a local folder, a **SharePoint** document library, or **Microsoft Fabric (OneLake)** Delta tables — no extra scripting
- ⏰ **Scheduled bakes** — hand any recipe to Windows Task Scheduler for automatic daily/weekly/monthly runs
- 🔄 **Always current** — on install the app fetches the latest PAX engine straight from this repo and keeps both the app and the engine up to date in place — no return trips to GitHub, no version hunting

> **[⬇️ Get PAX Cookbook →](https://microsoft.github.io/PAX-Cookbook)** &nbsp;·&nbsp; *Free · open source · local-first · credential-safe · no audit data stored in the app*

### 2. ⚙️ The PAX PowerShell script — the engine (run it standalone)

Under the hood, every Cookbook bake runs the same **PAX engine**: a set of enterprise-grade PowerShell scripts you can also run **standalone** in your own terminal. The flagship script in the set — and the one most customers will use — is the **Purview Audit Log Processor**. It retrieves Microsoft 365 Copilot, AI agent, and broader workload audit records from the Microsoft Purview Unified Audit Log via Microsoft Graph API (default) or Exchange Online Management (EOM).

Highlights of the Purview Audit Log Processor:

- Microsoft 365 Copilot, Unlicensed Copilot, and AI agent signal coverage
- **Microsoft 365 Usage Bundle** for productivity-workload activity (Teams, Exchange, SharePoint, OneDrive, Word, Excel, PowerPoint, OneNote, Forms, Stream, Planner, PowerApps) captured in the same run alongside Copilot telemetry
- **Entra ID user + Microsoft 365 Copilot (MAC) licensing enrichment**
- Long-running enterprise exports with checkpoint & resume, append capabilities, rolled up data architecture support to shrink data footprint, parallel processing, adaptive time-slicing, and server record limit detection and override
- Flexible filtering by user, group, agent, activity type, record/service type, and date range
- **Flexible output destinations:** local folder, SharePoint document library, or directly into **Microsoft Fabric (OneLake)** Delta tables — for unattended Azure-hosted runs, paired with Managed Identities

Grab the script and its docs from the [**PAX PowerShell Script** links above](#pax-powershell-script--pax-cookbook--pax-cookbook-mini-kitchen).

### 3. ⌨️ PAX Cookbook Mini-Kitchen — build your PAX command line (for standalone runs)

Prefer the command line but don't want to hand-write switches? **[Mini-Kitchen](https://microsoft.github.io/PAX-Cookbook/mini-kitchen)** is a browser-only companion (no install) whose whole job is to **build a clean, copy-ready PAX command line for you to paste into your own terminal.** You point-and-click your options, Mini-Kitchen renders the exact `pwsh` command, you copy it, and **you run it yourself against the PAX script downloaded from this repo.** It ships ready-made presets for the **AI-in-One** and **M365 Usage Analytics** dashboards (and others), saves recipes right in your browser, and exports portable **`.paxlite`** files you can later import into the full PAX Cookbook app.

Mini-Kitchen never runs PAX for you — it only writes the command. **It does not touch your tenant or your data:** it uses **no user credentials, app-registration secrets, or certificates**, pulls **no audit data and no user/Entra information**, and does **not** connect to your Microsoft 365 tenant, Microsoft Graph, Purview, or your SharePoint/Fabric/local storage. The only thing it reads or writes is the `.paxlite` recipe file you choose to export or import — which itself holds only your saved command options and stays entirely on your device. All authentication and data export happen later, when **you** run the generated command yourself.

> **[⌨️ Open Mini-Kitchen →](https://microsoft.github.io/PAX-Cookbook/mini-kitchen)** &nbsp;·&nbsp; *Browser-only · no install · no tenant connection · no credentials or data*

### Other scripts in the set

The PAX set also includes two specialized companion scripts for narrower use cases:

- **Copilot Interactions Content Audit Log Processor** — pulls the **actual prompt and response content** of Microsoft 365 Copilot interactions directly from the Graph `aiInteraction` resource type (content-rich analysis with optional body text), with incremental watermark exports and user enrichment. Use this when you specifically need interaction *content*, not just usage telemetry.
- **Graph Audit Log Processor** — a lightweight Graph-API-only export of Copilot usage records together with Entra user/organizational details and Copilot licensing. Use this when you do **not** need Purview Unified Audit Log coverage.

> Most customers only need the Purview Audit Log Processor. The other two scripts are not replacements for it — they target different data sources and narrower scenarios. If you are unsure which to use, start with the Purview Audit Log Processor.

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

## Support

For questions or issues, refer to the documentation links next to each script above.

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com) with any feedback.*

---

© Microsoft Corporation — MIT Licensed
