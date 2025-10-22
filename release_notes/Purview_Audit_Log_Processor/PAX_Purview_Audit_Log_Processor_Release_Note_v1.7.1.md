# Release Notes: v1.7.1

## Release Information
- **Version:** 1.7.1
- **Release Date:** 2025-10-20 (Updated)
- **Released By:** Brian Middendorf (@microsoft)
- **Previous Version:** v1.7.0

---

## Overview

Version 1.7.1 is a **documentation-focused maintenance release** that significantly improves the usability and navigability of the Purview Audit Log Processor documentation. This release introduces 33 strategically placed collapsible sections throughout the 2,100+ line documentation, making it dramatically easier to find specific information without overwhelming users with dense content blocks.

### What Changed
- **Documentation**: Major usability improvements with collapsible sections
- **Script**: Version number updates (v1.7.0 → v1.7.1) in header and examples
- **Infrastructure**: Repository structure and branding enhancements

**No functional changes** to the audit log processing logic - all features from v1.7.0 remain unchanged and fully compatible.

---

## Key Improvements

### 📖 Documentation Enhancements (33 Collapsible Sections Added)

#### **Installation & Quick Start** (4 sections)
Collapsed detailed installation steps and authentication methods to streamline getting-started experience:
- **Prerequisites Checklist**: System requirements, PowerShell version verification, and module dependencies now hidden by default
- **Interactive Authentication**: Step-by-step OAuth flow with screenshots collapsed to reduce visual clutter
- **Certificate Authentication**: Enterprise certificate setup procedures with security considerations  
- **Client Secret Authentication**: App registration and secret management steps
- **Service Principal Authentication**: Automated pipeline configuration for CI/CD scenarios

#### **Usage Examples** (6 sections)
All command examples now collapsed for easier scanning:
- **Basic Export**: Simple date range extraction with default settings
- **Array Explosion**: Conversation message expansion examples
- **Deep Explosion**: Nested array flattening for analysis tools
- **Replay Mode**: Offline CSV re-processing demonstrations
- **Performance Tuning**: Streaming parameter optimization examples
- **Live vs Replay Comparison**: Side-by-side workflow differences

#### **Agent Filtering** (3 sections)
Consolidated agent-related documentation for focused reference:
- **How Agent Filtering Works**: Technical explanation of agent detection logic and filtering mechanics
- **Agent Performance Metrics**: Benchmark data showing filtering efficiency (processed 15,234 records → 8,901 agent-only in 12.3s)
- **AgentsOnly vs ExcludeAgents**: Comparison table with use cases and output expectations

#### **User & Group Filtering** (3 sections)
Organized user/group targeting features for privacy-conscious analysis:
- **How User Filtering Works**: Server-side (Live) vs client-side (Replay) filtering implementation details
- **User/Group Performance Metrics**: Efficiency data for targeting scenarios (10,000 records → 847 user-specific in 8.7s)
- **Group Expansion Process**: Distribution list and security group member resolution workflow

#### **PromptFilter Deep Dive** (4 sections)
Separated conversation turn isolation documentation:
- **How PromptFilter Works**: Two-stage filtering architecture (pre-explosion validation + during-explosion application)
- **PromptFilter Modes Explained**: Detailed breakdown of Prompt/Response/Both/Null modes with conversation examples
- **PromptFilter + Agent Combinations**: Advanced filtering scenarios isolating agent prompts vs human prompts
- **PromptFilter Performance**: Metrics showing conversation turn isolation efficiency (12,450 turns → 6,225 prompts in 14.1s)

#### **Filter Combinations** (5 sections)
Complex multi-filter scenarios now easy to find:
- **UserIds + AgentsOnly**: Isolate specific user's agent interactions
- **GroupNames + PromptFilter**: Analyze team conversation patterns
- **Multiple Filters Together**: Triple/quadruple filter combinations with practical examples
- **Live Mode Filtering**: Server-side efficiency optimizations
- **Replay Mode Filtering**: Client-side flexibility for offline analysis

#### **Performance Tuning** (4 sections)
Advanced optimization guidance separated from basic usage:
- **Streaming Parameters Explained**: StreamingSchemaSample and StreamingChunkSize mechanics
- **Memory vs Speed Trade-offs**: Configuration recommendations for different hardware profiles
- **Large Dataset Strategies**: Handling 100K+ record exports with memory constraints
- **Benchmark Data**: Real-world performance metrics across various configurations

#### **Reference Tables & Lists** (3 sections)
Collapsed dense reference materials:
- **Use Case Matrix**: Comprehensive filtering scenario table (15 common analysis workflows)
- **Known Limitations**: Current constraints and workarounds
- **Troubleshooting Guide**: Common error messages and resolution steps

### 🛠️ Script Updates

**Version Reference Updates** (53 lines changed):
- Updated header comment: `# Portable Audit eXporter (PAX) - Purview Audit Log Processor - v1.7.1`
- Updated all example commands throughout help documentation to reference `PAX_Purview_Audit_Log_Processor_v1.7.1.ps1`
- **No functional code changes** - all processing logic, parameters, and features identical to v1.7.0

**Why Update Script Version?**
Even though no functional changes occurred, the script version was bumped to maintain consistency with the documentation release. This ensures users referencing the v1.7.1 documentation see matching script version numbers in examples, reducing confusion during troubleshooting.

### 🏗️ Repository Infrastructure

**Folder Structure Standardization**:
- Ensured consistent subfolder structure across all three parent folders (`release_documentation/`, `release_notes/`, `script_archive/`)
- Added product-specific branding to `.gitkeep` files:
  - Parent folders: "PAX Solution Set" branding
  - Purview subfolders: "Purview Audit Log Processor" branding
  - Graph subfolders: "Graph Audit Log Processor" branding
- Created missing `release_documentation/Graph_Audit_Log_Processor/PDF/` folder for future Graph releases

**README.md Enhancements**:
- Fixed Purview download link to use new tag format (`purview-v1.7.1` instead of `v1.7.1`)
- Verified all documentation, release notes, and archive links point to correct subfolder structures

---

## Why This Release Matters

### **Problem**: Documentation Overwhelm
The v1.7.0 documentation, while comprehensive, presented all content upfront:
- 2,126 lines of text, code examples, and tables
- No visual hierarchy beyond headers
- Difficult to quickly scan for specific features
- New users overwhelmed by advanced topics mixed with basics

### **Solution**: Strategic Collapsibility
v1.7.1 introduces **progressive disclosure** through collapsible sections:
- **Beginners** see high-level summaries and can expand only what they need
- **Advanced users** can quickly collapse sections they've already mastered
- **Troubleshooters** can jump to specific sections without scrolling past irrelevant content
- **GitHub/Markdown viewers** automatically render `<details>` tags with expand/collapse controls

### **Result**: Improved Discoverability
- **33 collapsible sections** = 33 decision points where users choose their learning path
- **Emoji summaries** (e.g., 🎯 **Basic Export**, ⚡ **Performance Tuning**) provide instant visual cues
- **Preserved searchability** - all content remains in-document for Ctrl+F searching
- **No breaking changes** - documentation content unchanged, just reorganized for better UX

---

## Detailed Changes

### Modified Files (6 files changed)
```
README.md
release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.7.1.md
release_documentation/Purview_Audit_Log_Processor/PDF/PAX_Purview_Audit_Log_Processor_Documentation_v1.7.1.pdf
release_documentation/Graph_Audit_Log_Processor/PDF/.gitkeep (created)
release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.7.1.md
PAX_Purview_Audit_Log_Processor_v1.7.1.ps1
script_archive/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_v1.7.1.ps1
```

### File Statistics
```
Documentation:
- Added 33 <details><summary> block pairs
- Reorganized 800+ lines of content into collapsible sections
- PDF regenerated with updated MD source (4.02 MB)

Script:
- Updated 1 header line (version number)
- Updated 26 example commands (52 lines total) to reference v1.7.1
- Total: 53 lines changed (all cosmetic/version-related)

Infrastructure:
- Created 1 new folder (Graph PDF documentation)
- Updated 10 .gitkeep files with product-specific branding
- Fixed 1 README link (tag format standardization)
```

---

## Installation

### Download v1.7.1 (This Version)
This release note documents **version 1.7.1**. Use the direct download links below to obtain this specific version:

- **Script v1.7.1**: [PAX_Purview_Audit_Log_Processor_v1.7.1.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.7.1/PAX_Purview_Audit_Log_Processor_v1.7.1.ps1)
- **Documentation v1.7.1 (PDF)**: [PAX_Purview_Audit_Log_Processor_Documentation_v1.7.1.pdf](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PDF/PAX_Purview_Audit_Log_Processor_Documentation_v1.7.1.pdf)
- **Documentation v1.7.1 (MD)**: [PAX_Purview_Audit_Log_Processor_Documentation_v1.7.1.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.7.1.md)

### Get Latest Version
For the most recent release, visit:
- **Latest Script Archive**: [Microsoft PAX Repository - Script Archive](https://github.com/microsoft/PAX/tree/release/script_archive/Purview_Audit_Log_Processor)
- **All Release Notes**: [Microsoft PAX Repository - Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Purview_Audit_Log_Processor)

---

## Upgrading from v1.7.0

### Is Upgrade Required?
**No.** v1.7.1 contains no functional changes to the script. If you're already using v1.7.0, the script will behave identically.

### Recommended for:
- **New users**: Start with v1.7.1 for the improved documentation experience
- **Documentation writers**: Reference v1.7.1 docs for better-organized content
- **Teams onboarding**: v1.7.1 docs are more beginner-friendly with collapsible advanced sections

### Not Required if:
- You're already proficient with v1.7.0 and don't need documentation updates
- Your automation scripts reference v1.7.0 specifically (no breaking changes to worry about)

---

## Support

For questions or issues, refer to the documentation:
- **Documentation v1.7.1 (PDF)**: [PAX_Purview_Audit_Log_Processor_Documentation_v1.7.1.pdf](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PDF/PAX_Purview_Audit_Log_Processor_Documentation_v1.7.1.pdf)
- **Documentation v1.7.1 (Markdown)**: [PAX_Purview_Audit_Log_Processor_Documentation_v1.7.1.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.7.1.md)

---

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [Brian Middendorf](mailto:bmiddendorf@microsoft.com?subject=Microsoft%20PAX%3A%20Purview%20Audit%20Log%20Processor%20v1.7.1%20Feedback) with any feedback.*
