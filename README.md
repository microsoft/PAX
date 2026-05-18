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

## 🔍 Purview Audit Log Processor — primary script

> Download the script → [`PAX_Purview_Audit_Log_Processor_v1.11.2.ps1`](https://github.com/microsoft/PAX/releases/download/purview-v1.11.2/PAX_Purview_Audit_Log_Processor_v1.11.2.ps1) | Release Date: 2026-05-17
>
> **📖 Resources:** [Latest Documentation](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.11.x.md) | [Latest Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.11.x.md)
>
> **📚 Archives:** [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Purview_Audit_Log_Processor) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Purview_Audit_Log_Processor) | [Previous Versions](https://github.com/microsoft/PAX/tree/release/script_archive/Purview_Audit_Log_Processor)

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
