# PAX Graph Audit Log Processor – Release Notes v0.1.2

## Release Information

- **Version:** 0.1.2
- **Release Date:** October 29, 2025
- **Status:** Beta (administrative version alignment)
- **Script:** `PAX_Graph_Audit_Log_Processor_v0.1.2.ps1`
- **Previous Version:** 0.1.1

---

## Overview

Version 0.1.2 is a strictly administrative alignment release. It updates the internal script version constant, documentation top link block, and release artifact references to ensure consistency across repository metadata. **No functional logic, parameters, output schema, or behavioral changes were introduced.**

---

## Delta Since 0.1.1

| Area | Change | Impact |
|------|--------|--------|
| Script Header | Bumped `$ScriptVersion` to `0.1.2` | Reflects correct version tag; no runtime effect |
| Release Assets | Prepared for `graph-v0.1.2` tagging | Ensures download links resolve post-release |
| Documentation Links | Top link block will reference v0.1.2 (body unchanged) | Prevents stale navigation pointers |
| Release Notes | Replaced prior 0.1.1 content with 0.1.2-specific delta only | Avoids duplication / historical noise |
| versions.json (planned umbrella commit) | Will update Graph version to 0.1.2 in later umbrella commit | Central manifest parity |

**No new features, fixes, deprecations, or performance adjustments.**

---

## Rationale

Keeping release artifacts tightly aligned avoids downstream confusion in automation, asset retrieval, and dashboard ingestion that rely on version string parity. This lightweight increment establishes a clean baseline before future functional changes.

---

## Upgrade Guidance

| Scenario | Action |
|----------|--------|
| Running v0.1.1 | Optional – adopt v0.1.2 for metadata consistency |
| Building automations | Prefer v0.1.2 to match upcoming manifest state |
| Evaluating functionality | No retesting required (no code path changes) |

There are no migration steps; all invocation patterns remain valid.

---

## Verification Checklist

You can confirm this release by:
1. Opening the script and locating `# Version: v0.1.2` and `$ScriptVersion = "0.1.2"`.
2. Ensuring download links (post-tag) resolve to `graph-v0.1.2` assets.
3. Observing unchanged execution behavior compared to 0.1.1.

---

## Known Issues

None new. Any previously observed beta constraints remain unchanged (rate limiting, API aggregation latency, privacy obfuscation scenarios).

---

## License

MIT License – refer to root `LICENSE` file.

---

## Summary

`v0.1.2` is a housekeeping release: version string parity and artifact alignment only. Safe to adopt immediately with zero regression risk.

---

**Next Planned Step:** Umbrella manifest commit will record this Graph version alongside Purview v1.7.4 and infrastructure v1.0.5.
