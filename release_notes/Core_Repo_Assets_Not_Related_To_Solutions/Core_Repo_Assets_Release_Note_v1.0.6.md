# PAX Umbrella Infrastructure – Release Notes v1.0.6

## Release Information

- **Version:** 1.0.6
- **Release Date:** October 30, 2025
- **Scope:** Major Graph processor feature release coordination
- **Components Included:**
  - Graph Audit Log Processor `graph-v1.0.1` (major feature release: Excel export, MAC licensing, granular endpoints)
  - Purview Audit Log Processor `purview-v1.7.4` (no changes from v1.0.5)
  - Infrastructure manifest & documentation updates
- **Previous Umbrella Version:** 1.0.5

---

## Overview

`PAX-v1.0.6` is a major feature coordination release that brings **Graph Audit Log Processor v1.0.1** production capabilities—including **Excel workbook export**, **MAC licensing endpoints**, and **granular endpoint selection**—into the PAX ecosystem. This umbrella release synchronizes repository metadata, updates README links to the latest Graph assets, and maintains documentation consistency across the platform.

While the Purview processor remains at v1.7.4 (unchanged from v1.0.5), the Graph processor's transformation from a CSV-centric data collector into a comprehensive M365 analytics platform marks a significant milestone for the PAX project.

---

## Delta Since v1.0.5

| Area | Change | Impact |
|------|--------|--------|
| Graph Script | Major upgrade to `v1.0.1` (Excel export, MAC licensing, 10+ new parameters) | Production analytics platform with workbook export & append mode |
| Purview Script | Unchanged at `v1.7.4` | Stable observability & completeness features retained |
| Manifest (`versions.json`) | Updated to Graph `1.0.1`, Purview `1.7.4`, Umbrella `1.0.6` | Single source of truth for component versions |
| README | Updated Graph links to v1.0.1 release assets & documentation | Download tracking + proper blob rendering for docs |
| Graph Documentation | New v1.0.1 comprehensive documentation | Excel workflows, MAC licensing, granular endpoint strategies |
| Graph Release Note | New v1.0.1 production release note | Complete feature changelog from v0.1.2 to v1.0.1 |
| Historical Archives | Graph v1.0.1 + documentation added to archives | Immutable version lineage preserved |

---

## Component Summary

### Graph Audit Log Processor (`graph-v1.0.1`) - MAJOR FEATURE RELEASE

**New Capabilities**:
1. **Excel Workbook Export**: Multi-sheet workbooks with formatted tables, auto-fit columns, and automatic ImportExcel module installation
2. **Append Mode**: Add new data to existing workbooks without overwriting previous sheets (ideal for trend tracking)
3. **MAC Licensing Endpoints**: Per-user Copilot license assignments (MACCopilotLicensing) and tenant-wide license capacity summary (MACLicenseSummary)
4. **Granular Endpoint Selection**: 10+ new parameters for precise data collection control (replaces all-or-nothing `-IncludeCurated`)
5. **Enhanced Usability**: Automatic Graph disconnection, parameter validation, improved logging, workbook conflict detection

**Business Impact**:
- Eliminates CSV → Excel manual conversion workflows
- Enables executive dashboard creation with pre-formatted workbooks
- Supports license optimization by correlating usage with license assignments
- Improves API performance through selective endpoint querying
- Enables fully automated recurring export pipelines

**Technical Changes**:
- Script size: 1785 → 3182 lines (78% increase)
- Endpoints: 15 → 17 (added MACCopilotLicensing, MACLicenseSummary)
- Parameters: 11 → 25+ (granular selection, Excel controls, exclusions)

### Purview Audit Log Processor (`purview-v1.7.4`) - NO CHANGES
Stable at v1.7.4 with structured metrics emission, AutoCompleteness, and deterministic exit codes. No updates in this umbrella release.

### Umbrella Infrastructure (`PAX-v1.0.6`)
Coordinates Graph v1.0.1 production release, updates README download links (release assets for scripts, blob links for documentation), and maintains version manifest consistency.

---

## Rationale

1. **Bring Graph to Production**: v1.0.1 represents production-ready analytics platform (vs. v0.1.2 beta)
2. **Enable Advanced Workflows**: Excel export + append mode supports enterprise dashboard & recurring report requirements
3. **Licensing Intelligence**: MAC endpoints enable cost optimization and license-to-usage correlation
4. **Maintain Link Hygiene**: README updates ensure proper GitHub download tracking (release assets) and documentation rendering (blob links)
5. **Version Synchronization**: Manifest updates provide single source of truth for automation and CI/CD

---

## Upgrade Guidance

| Scenario | Recommended Action |
|----------|--------------------|
| Using Graph v0.1.2 or earlier | **Strongly recommended upgrade** – v1.0.1 is production-ready with major feature enhancements |
| Need Excel output | Upgrade to v1.0.1 and add `-ExportWorkbook` parameter |
| Recurring reports | Use v1.0.1 `-AppendWorkbook` for historical trend tracking |
| License optimization | Add `-IncludeMACCopilotLicensing` and `-IncludeMACLicenseSummary` parameters |
| Performance tuning | Use granular switches (`-IncludeTeamsActivity`, etc.) instead of `-IncludeCurated` |
| Using Purview v1.7.4 | No action needed – version unchanged |

**Backward Compatibility**: Graph v1.0.1 is fully backward-compatible with v0.1.2 commands. Parameter `-IncludeCopilot` renamed to `-IncludeCopilotUsage` (old name still works via alias).

**Migration Example**:
```powershell
# v0.1.2 command
.\PAX_Graph_Audit_Log_Processor_v0.1.2.ps1 -Period D30 -OutputPath "C:\Reports" -Auth DeviceCode -IncludeCopilot

# v1.0.1 equivalent with Excel output
.\PAX_Graph_Audit_Log_Processor_v1.0.1.ps1 -Period D30 -OutputPath "C:\Reports" -Auth DeviceCode -IncludeCopilotUsage -ExportWorkbook
```

---

## Verification Checklist

1. ✅ Tags present: `graph-v1.0.1`, `purview-v1.7.4`, `PAX-v1.0.6`
2. ✅ Root README links point to Graph v1.0.1 release assets (script downloads)
3. ✅ Root README links point to Graph v1.0.1 blob files (documentation/release notes)
4. ✅ `versions.json` reflects Graph `1.0.1`, Purview `1.7.4`, Umbrella `1.0.6`
5. ✅ Historical archives contain Graph v1.0.1 script + documentation
6. ✅ Release page contains Graph v1.0.1 assets (script, documentation, release note)

---

## Known Issues

No new umbrella-level issues. Component-specific limitations documented in respective release notes:
- **Graph v1.0.1**: Period queries only (no date-based queries), Copilot endpoint period limitation, append mode sheet name conflicts
- **Purview v1.7.4**: Performance considerations under high subdivision recursion (unchanged from v1.0.5)

---

## License

MIT License – see repository `LICENSE`.

---

## Summary

`PAX-v1.0.6` represents a **major milestone** for the PAX project: the Graph Audit Log Processor graduates from beta to production with enterprise-grade analytics capabilities. Excel export, MAC licensing endpoints, and granular endpoint selection transform Graph from a data collector into an analytics enabler—critical for organizations scaling Microsoft 365 Copilot deployments.

**Key Achievements**:
✅ **Graph production release**: v1.0.1 with Excel export, append mode, MAC licensing  
✅ **Enterprise workflows enabled**: Dashboard creation, recurring reports, license optimization  
✅ **Documentation synchronized**: README links updated for proper tracking and rendering  
✅ **Backward compatibility maintained**: Seamless upgrade path from v0.1.2  

This release establishes Graph as a comprehensive M365 analytics platform while maintaining Purview's observability and completeness intelligence—a solid foundation for future multi-source aggregation orchestration.

---

**Next Planned Focus:** Potential Purview enhancements and continued refinement of Graph analytics capabilities based on enterprise adoption feedback.

---

**Author**: Microsoft Copilot ROI Advisory Team ([copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com?subject=PAX%20Graph%20Audit%20Log%20Processor%20Feedback))
