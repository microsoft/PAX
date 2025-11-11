# PAX Umbrella Infrastructure – Release Notes v1.0.7

## Release Information

- **Version:** 1.0.7
- **Release Date:** November 10, 2025
- **Scope:** Purview processor v1.8.0 infrastructure coordination
- **Components Included:**
  - Purview Audit Log Processor `purview-v1.8.0` (coordinated only - component-level changes documented separately)
  - Graph Audit Log Processor `graph-v1.0.1` (unchanged from v1.0.6)
  - Infrastructure manifest & documentation link updates
- **Previous Umbrella Version:** 1.0.6

---

## Overview

`PAX-v1.0.7` is a minor infrastructure coordination release that updates repository metadata and documentation links to reflect **Purview Audit Log Processor v1.8.0**. This umbrella release synchronizes the version manifest, updates README links to the latest Purview assets, and maintains documentation consistency across the platform.

The Graph processor remains at v1.0.1 (unchanged from v1.0.6). This release focuses purely on infrastructure coordination - all Purview v1.8.0 feature details are documented in the component-specific release note.

---

## Delta Since v1.0.6

| Area | Change | Impact |
|------|--------|--------|
| Purview Script | Coordinated with `v1.8.0` release | Major feature release (see component release notes) |
| Graph Script | Unchanged at `v1.0.1` | Production analytics platform features retained |
| Manifest (`versions.json`) | Updated to Purview `1.8.0`, PAX `1.0.7` | Single source of truth for component versions |
| README | Updated Purview links to v1.8.0 release assets & documentation | Download tracking + proper blob rendering for docs |
| Historical Archives | (Managed at component level) | Immutable version lineage preserved |

---

## Component Summary

### Purview Audit Log Processor (`purview-v1.8.0`) - COORDINATED RELEASE

**Infrastructure Coordination Only**: This umbrella release updates version references and documentation links. For complete details on Purview v1.8.0 features, changes, and migration guidance, see:
- **Script Download:** [PAX_Purview_Audit_Log_Processor_v1.8.0.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.8.0/PAX_Purview_Audit_Log_Processor_v1.8.0.ps1)
- **Release Notes:** [PAX_Purview_Audit_Log_Processor_Release_Note_v1.8.0.md](https://github.com/microsoft/PAX/blob/release/release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.8.0.md)
- **Documentation:** [PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.8.0.md)

### Graph Audit Log Processor (`graph-v1.0.1`) - NO CHANGES
Stable at v1.0.1 with Excel export, MAC licensing endpoints, and granular endpoint selection. No updates in this umbrella release.

### Umbrella Infrastructure (`PAX-v1.0.7`)
Coordinates Purview v1.8.0 release by updating README download links (release assets for scripts, blob links for documentation) and maintaining version manifest consistency.

---

## Rationale

1. **Version Synchronization**: Update manifest to reflect Purview v1.8.0 coordination
2. **Maintain Link Hygiene**: README updates ensure proper GitHub download tracking (release assets) and documentation rendering (blob links)
3. **Infrastructure Consistency**: Keep umbrella version aligned with component release cadence

---

## Upgrade Guidance

| Scenario | Recommended Action |
|----------|--------------------|
| Using Purview v1.7.4 or earlier | Refer to Purview v1.8.0 release notes for upgrade guidance |
| Using Graph v1.0.1 | No action needed – version unchanged |
| Referencing documentation links | Update bookmarks to v1.8.0 Purview documentation if needed |

**Note**: This is an infrastructure coordination release. For detailed upgrade guidance, breaking changes, and migration steps for Purview v1.8.0, consult the component-specific release note.

---

## Verification Checklist

1. ✅ Tags present: `purview-v1.8.0`, `graph-v1.0.1`, `PAX-v1.0.7`
2. ✅ Root README links point to Purview v1.8.0 release assets (script downloads)
3. ✅ Root README links point to Purview v1.8.0 blob files (documentation/release notes)
4. ✅ `versions.json` reflects Purview `1.8.0`, Graph `1.0.1`, PAX `1.0.7`
5. ✅ Historical archives managed at component level (Purview v1.8.0 assets)

---

## Known Issues

No umbrella-level issues. Component-specific limitations documented in respective release notes:
- **Purview v1.8.0**: See component release notes for details
- **Graph v1.0.1**: Period queries only (no date-based queries), Copilot endpoint period limitation, append mode sheet name conflicts (unchanged from v1.0.6)

---

## License

MIT License – see repository `LICENSE`.

---

## Summary

`PAX-v1.0.7` is a **minor infrastructure coordination release** that updates version references and documentation links to reflect Purview Audit Log Processor v1.8.0 coordination. This release maintains the PAX ecosystem's documentation consistency and version tracking while Graph processor remains stable at v1.0.1.

**Key Achievements**:
✅ **Purview v1.8.0 coordination**: Version manifest and README links updated  
✅ **Documentation synchronized**: README links updated for proper tracking and rendering  
✅ **Graph stability maintained**: v1.0.1 production features unchanged  

This release keeps infrastructure metadata aligned with component versions while maintaining link hygiene and version tracking consistency.

---

**Next Planned Focus:** Continued component development based on enterprise adoption feedback.

---

**Author**: Microsoft Copilot ROI Advisory Team ([copilot-roi-advisory-team-gh@microsoft.com](mailto:copilot-roi-advisory-team-gh@microsoft.com?subject=PAX%20Umbrella%20Infrastructure%20Feedback))
