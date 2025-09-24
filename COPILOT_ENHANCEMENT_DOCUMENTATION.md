# Enhanced Copilot Synthetic Data Documentation

## Overview
This document describes the comprehensive enhancement of synthetic Microsoft Copilot audit and usage data to reflect realistic production deployment scenarios with all available audit fields and usage patterns.

## Research Foundation
The enhancement is based on extensive research of official Microsoft Learn documentation including:

### Primary Sources
1. **Microsoft 365 Copilot Usage Reports**: https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/microsoft-365-copilot-usage
2. **Purview Audit Logs for Copilot**: https://learn.microsoft.com/en-us/purview/audit-copilot  
3. **Audit Log Activities**: https://learn.microsoft.com/en-us/purview/audit-log-activities

### Key Discoveries
- **Agent Usage Fields**: Available starting November 1, 2024 per Microsoft documentation
- **Comprehensive AppHost Values**: 30+ different Copilot entry points documented
- **Audit Field Structure**: Complete CopilotInteraction audit schema with 40+ fields
- **Usage Patterns**: Work vs Web chat distinctions, entry point tracking

## Enhanced Files Created

### 1. CopilotUsageUserDetail_Enhanced.csv
**Location**: `output/CopilotUsageUserDetail_Enhanced.csv`
**Records**: 12,617 (matching original dataset)
**Enhancement**: Added 10 new realistic fields

#### New Fields Added:
- `Agent Last Activity Date` - Overall agent usage tracking
- `Microsoft Teams Agent Last Activity Date` - Teams-specific agent usage
- `Word Agent Last Activity Date` - Word agent interactions
- `Excel Agent Last Activity Date` - Excel agent usage  
- `PowerPoint Agent Last Activity Date` - PowerPoint agent interactions
- `Outlook Agent Last Activity Date` - Outlook agent usage
- `Copilot Chat Work Last Activity Date` - Business chat usage
- `Copilot Chat Web Last Activity Date` - Web-based chat usage
- `Microsoft 365 App Last Activity Date` - M365 app entry point usage
- `Microsoft Edge Last Activity Date` - Edge sidebar usage

### 2. Purview_Enhanced_Sample_CopilotInteractions.csv
**Location**: `output/Purview_Enhanced_Sample_CopilotInteractions.csv`
**Records**: 50 sample records
**Purpose**: Demonstrates complete Copilot audit field structure

#### Complete Audit Field Set:
- **Identity Fields**: RecordId, UserId, UserKey, OrganizationId
- **Temporal Fields**: CreationDate, CreationDateIsoUtc, CreationTime, CreationTimeIsoUtc
- **Classification Fields**: RecordType, Operation, Workload
- **Agent Fields**: AgentId, AgentName, AgentVersion (for custom agents)
- **Application Fields**: AppHost, AppIdentity_AppId, AppIdentity_DisplayName
- **Context Fields**: Context_Id, Context_Type, ThreadId
- **Message Fields**: Message_Id, Message_isPrompt, MessageIds
- **Resource Fields**: AccessedResource_Action, AccessedResource_SiteUrl
- **Plugin Fields**: AISystemPlugin_Id, AISystemPlugin_Name, AISystemPlugin_Version
- **Model Fields**: ModelTransparencyDetails_ModelName, ModelTransparencyDetails_ModelProvider, ModelTransparencyDetails_ModelVersion
- **Network Fields**: ClientIP, ClientRegion
- **Administrative Fields**: AssociatedAdminUnits, AssociatedAdminUnitsNames

## Realistic Data Patterns Implemented

### Agent Usage Patterns
- **Availability**: Only for dates >= November 1, 2024 (per Microsoft documentation)
- **Adoption Rate**: 30% of Copilot users have agent interactions
- **Versioning**: Realistic patterns (25.xxx numeric format, GUID-based IDs)
- **Agent Types**: CopilotStudio.Declarative.*, CopilotStudio.CustomEngine.*

### Chat Usage Distribution
- **Work Chat**: 70% of chat interactions (BizChat, Office, M365App, Teams hosts)
- **Web Chat**: 30% of chat interactions (Bing, Edge hosts)
- **Entry Points**: 
  - Microsoft 365 App: 20% usage rate
  - Microsoft Edge: 20% usage rate

### AppHost Scenarios (30+ documented values)
- **Business Chat**: BizChat, Office, M365App
- **Office Apps**: Word, WordOnCanvas, Excel, PowerPoint, PowerPointOnCanvas
- **Communication**: Teams, Outlook, OutlookOnCanvas, OutlookSidepane
- **Collaboration**: Loop, OneNote, SharePoint, OneDrive, Whiteboard
- **Web Entry**: Edge, Bing
- **Search Integration**: OfficeCopilotSearchAnswer
- **Notebooks**: OfficeCopilotNotebook, OneNoteCopilotNotebook
- **Admin Tools**: M365AdminCenter, TeamsAdminPortal
- **Viva Suite**: VivaEngage, VivaPulse, VivaGoals
- **Additional Apps**: Forms, Planner, Designer, Bookings, Stream

### Model Transparency Details
- **GPT Models**: gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-35-turbo
- **Versioning**: Realistic version dates (2024-08-06, 2024-04-09, etc.)
- **Provider**: Microsoft (for all models in synthetic data)

### Plugin Usage Patterns
- **Core Plugins**: BingWebSearch, GraphConnector, SharePointConnector
- **Enterprise Connectors**: OneDriveConnector, TeamsConnector, OutlookConnector
- **Third-Party**: SalesforceConnector, ServiceNowConnector, JiraConnector
- **Usage Rate**: 40% of interactions include plugin usage

## Licensing Alignment
The enhanced synthetic data maintains the original staggered licensing pattern:
- **April 1, 2025**: 200 users licensed
- **May 1, 2025**: 200 additional users (400 total)
- **June 1, 2025**: 400 additional users (800 total)
- **Never Licensed**: 200 users remain unlicensed

All agent usage respects both the licensing dates AND the November 1, 2024 agent availability date.

## Field Validation
All enhanced fields follow Microsoft's documented specifications:
- **Date Formats**: ISO 8601 UTC (yyyy-MM-ddTHH:mm:ss.fffZ) and local (M/d/yyyy h:mm:ss tt)
- **GUID Formats**: Standard 8-4-4-4-12 hyphenated format
- **Boolean Values**: "true"/"false" strings (not boolean primitives)
- **Enum Values**: Match documented Microsoft AppHost scenarios exactly

## Business Value
This enhancement enables realistic demonstration of:

1. **Agent Adoption Analytics**: Track custom agent deployment and usage
2. **Entry Point Analysis**: Understand how users access Copilot across different interfaces
3. **Work vs Web Usage**: Differentiate between business and consumer chat patterns
4. **Plugin Utilization**: Monitor integration usage across enterprise connectors
5. **Model Performance**: Analyze usage patterns across different AI models
6. **Context Awareness**: Understand document/meeting integration patterns

## Technical Implementation
- **PowerShell Script**: `enhance-copilot-synthetic-data-simple.ps1`
- **Processing Time**: ~30 seconds for 12K+ records
- **Memory Efficient**: Processes records individually without loading large arrays
- **Error Handling**: Robust date parsing and null value management
- **Backwards Compatible**: Preserves all original fields and relationships

## Quality Assurance
- **Data Consistency**: All User Principal Names match across files
- **Temporal Logic**: Agent dates never precede November 1, 2024
- **Realistic Distributions**: Usage patterns match documented Microsoft scenarios
- **Field Completeness**: No missing required fields in audit records
- **Format Compliance**: All fields match Microsoft documentation specifications

## Future Enhancements
Potential areas for further enhancement:
1. **Seasonal Patterns**: Model holiday and business cycle usage variations
2. **Department Correlation**: Align agent usage with department-specific patterns
3. **Geographic Distribution**: Add realistic regional usage variations
4. **Performance Metrics**: Include response times and success rates
5. **Security Events**: Add DLP policy violations and jailbreak attempts

## Files Summary
| File | Purpose | Records | Key Enhancement |
|------|---------|---------|----------------|
| `CopilotUsageUserDetail_Enhanced.csv` | User activity summary with agent fields | 12,617 | 10 new usage tracking columns |
| `Purview_Enhanced_Sample_CopilotInteractions.csv` | Complete audit field demonstration | 50 | Full CopilotInteraction audit schema |

This enhanced synthetic dataset now provides a comprehensive, realistic foundation for demonstrating Microsoft Copilot analytics capabilities that would be available to customers with proper licensing and audit configuration.