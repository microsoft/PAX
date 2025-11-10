# Portable Audit eXporter (PAX) Solution Set
<!-- v1.0.6 -->

**Portable Audit eXporter (PAX)** exports Copilot and AI usage data from Purview and Graph API audit logs via Graph API or EOM methods. Both solutions export to CSV or Excel formats, ready for analysis in Power BI or your preferred data analysis tool.

The **Purview Audit Log Processor** retrieves audit records for Copilot interactions, AI agents, and third-party AI usage using Microsoft Graph API or Exchange Online Management (EOM), with DSPM for AI support including `CopilotInteraction`, `AIInteraction` (custom AI apps from Copilot Studio/Azure AI Studio), `ConnectedAIAppInteraction` (Microsoft and third-party AI apps deployed in your tenant), and `AIAppInteraction` (external third-party AI via network DLP). Includes Copilot user licensing information and AI agent type detection and categorization. 

The **Graph Audit Log Processor** retrieves Copilot usage data and comprehensive audit records directly from Microsoft Graph API, including Entra user and organizational details, along with Copilot licensing information.

<details>
<summary>⚠️ Important Usage & Compliance Disclaimer</summary>

**Please note:**

While this tool helps customers better understand their AI usage data, Microsoft has no visibility into the data that customers input into this script/tool, nor does Microsoft have any control over how customers will use this script/tool in their environment.

Customers are solely responsible for ensuring that their use of the script/tool complies with all applicable laws and regulations, including those related to data privacy and security.

Microsoft disclaims any and all liability arising from or related to customers' use of the script/tool.

**Experimental Script Notice:**

This is an experimental script. On occasion, you may notice small deviations from metrics in the official Copilot and Agent Dashboards. We will continue to iterate based on your feedback. Currently available in English only.

</details>

---

> **🔍 Purview Audit Log Processor:** Download the script → [`PAX_Purview_Audit_Log_Processor_v1.8.0.ps1`](https://github.com/microsoft/PAX/releases/download/purview-v1.8.0/PAX_Purview_Audit_Log_Processor_v1.8.0.ps1)
>
> **📖 Resources:** [Latest Documentation](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md) | [Latest Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.8.0.md)
>
> **📚 Archives:** [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Purview_Audit_Log_Processor) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Purview_Audit_Log_Processor) | [Previous Versions](https://github.com/microsoft/PAX/tree/release/script_archive/Purview_Audit_Log_Processor)

---

> **📊 Graph Audit Log Processor:** Download the script → [`PAX_Graph_Audit_Log_Processor_v1.0.1.ps1`](https://github.com/microsoft/PAX/releases/download/graph-v1.0.1/PAX_Graph_Audit_Log_Processor_v1.0.1.ps1)
>
> **📖 Resources:** [Latest Documentation](https://github.com/microsoft/PAX/blob/release/release_documentation/Graph_Audit_Log_Processor/PAX_Graph_Audit_Log_Processor_Documentation_v1.0.1.md) | [Latest Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/Graph_Audit_Log_Processor/PAX_Graph_Audit_Log_Processor_Release_Note_v1.0.1.md)
>
> **📚 Archives:** [All Documentation](https://github.com/microsoft/PAX/tree/release/release_documentation/Graph_Audit_Log_Processor) | [All Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Graph_Audit_Log_Processor) | [Previous Versions](https://github.com/microsoft/PAX/tree/release/script_archive/Graph_Audit_Log_Processor)

---

<sub><sup>**Keywords:** microsoft-365-copilot, copilot-usage-data, copilot-analytics, m365-copilot-export, microsoft-copilot-audit, copilot-interaction-logs, purview-audit-logs, graph-api-audit, dspm-for-ai, ai-usage-analytics, copilot-studio-export, azure-ai-studio-logs, third-party-ai-monitoring, connected-ai-apps, ai-agent-detection, copilot-licensing-reports, microsoft-365-audit, exchange-online-management, unified-audit-log, copilot-data-export, ai-governance, copilot-compliance, microsoft-purview-dspm, copilot-usage-reports, m365-ai-analytics, copilot-power-bi, tenant-ai-monitoring, enterprise-copilot-analytics, copilot-csv-export, copilot-excel-export</sup></sub>