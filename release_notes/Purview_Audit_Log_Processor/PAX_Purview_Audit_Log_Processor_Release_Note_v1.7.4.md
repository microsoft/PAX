# Release Notes: v1.7.4

## Release Information

- **Version:** 1.7.4
- **Release Date:** 2025-10-28
- **Released By:** Brian Middendorf (@microsoft)
- **Previous Version:** v1.7.3

---

## Overview

Version 1.7.4 is a **completeness & observability release** building on the v1.7.3 early 10K limit detection. It introduces structured metrics emission, actionable exit codes, recursive AutoCompleteness remediation, and hardened parallel aggregation to ensure accurate telemetry in multi-thread scenarios.

### What Changed

- **Script:** Added `-EmitMetricsJson` and `-MetricsPath` for machine-readable session metrics
- **Script:** Added `-AutoCompleteness` recursive subdivision of saturated windows
- **Script:** Added exit code mapping (0 success, 10 incomplete, 20 circuit breaker)
- **Script:** Parallel metrics aggregation defers emission until all groups finish (prevents duplication)
- **Testing:** Expanded Pester coverage (metrics JSON, AutoCompleteness depth/termination, exit codes, parallel telemetry integrity)
- **Documentation:** Augmented v1.7.3 doc with new sections (Metrics & Exit Codes, AutoCompleteness Strategy, Parallel Metrics, Synthetic Replay Guidance)
- **Help Block:** Updated examples to reflect metrics & remediation workflow

**Backward Compatible:** All prior commands from v1.7.3 continue working unchanged; new switches are additive.

---

## Key Improvements

### ✅ Structured Metrics Emission (`-EmitMetricsJson`)
Provides a single JSON artifact summarizing execution (window counts, explosion stats, subdivision metrics, and final exit code). Enables CI/CD gating, automated completeness tracking, and performance baselining.

**Sample (illustrative):**
```json
{
  "ScriptVersion": "1.7.4",
  "StartTimestampUtc": "2025-10-28T14:05:23Z",
  "EndTimestampUtc": "2025-10-28T14:07:11Z",
  "TotalWindows": 52,
  "SubdividedWindows": 10,
  "Hit10KLimitWindows": 3,
  "AutoCompletenessIterations": 1,
  "ExplodedRows": 28812,
  "ExplosionEvents": 1240,
  "ExplosionRowsFromEvents": 2590,
  "ExitCode": 0
}
```

### 🔁 AutoCompleteness Remediation (`-AutoCompleteness`)
Recursively subdivides any remaining saturated windows (≥10K) after a first pass until below limit or safety guardrails reached. Improves completeness without manual tuning of `-BlockHours`.

**Recommended Flow:**

1. Run without the switch → if exit code 10, saturated windows detected
2. Re-run with `-AutoCompleteness` → script resolves remaining windows or reports those still constrained

### 🚦 Exit Codes for Automation

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success (no saturated windows) | Proceed with analytics pipeline |
| 10 | Incomplete (windows still at cap) | Re-run with `-AutoCompleteness` or narrower `-BlockHours` |
| 20 | Circuit breaker tripped | Investigate throttling / latency; reduce concurrency or add pacing |

### 🤝 Parallel Metrics Integrity
Single metrics JSON emission after all parallel partitions complete; eliminates premature or duplicated telemetry. Internal gating ensures explosion counters reconcile once.

### 🧪 Expanded Test Coverage

Pester test suites extended to validate:

- Metrics JSON atomic single-write behavior
- Parallel aggregation de-duplication
- Recursive window subdivision convergence & depth guard
- Exit code mapping across success, incomplete, breaker states
- Explosion integrity unaffected by new observability features

---

## Why This Release Matters

| Challenge | Prior State (≤1.7.3) | Improvement in 1.7.4 |
|-----------|---------------------|-----------------------|
| Detecting incomplete exports programmatically | Manual log review | Deterministic exit code + metrics flag |
| Quantifying subdivision & explosion effects | No structured artifact | Rich JSON telemetry (counts, iterations) |
| Remediating saturated windows | Manual rerun with smaller blocks | Automated recursive subdivision |
| Parallel metrics accuracy | Risk of duplicate interim counters | Deferred single aggregation |

---

## Detailed Changes

### Modified / Added Files

```text
PAX_Purview_Audit_Log_Processor_v1.7.4.ps1 (new version)
PAX_Purview_Audit_Log_Processor_v1.7.3.ps1 (historical reference)
release_documentation/.../PAX_Purview_Audit_Log_Processor_Documentation_v1.7.4.md (version-aligned, formerly augmented 1.7.3)
release_notes/.../PAX_Purview_Audit_Log_Processor_Release_Note_v1.7.4.md (this file)
versions.json (purview 1.7.4, pax infra 1.0.5)
README.md (script download link updated)
PAX_Purview_Audit_Log_Pester_Test_Summary.md (new test overview)
```

### New Parameters

```text
-EmitMetricsJson   : Emit structured metrics JSON alongside CSV
-MetricsPath       : Override default metrics JSON location
-AutoCompleteness  : Recursive subdivision of saturated windows
```

### Metrics & Observability Counters

```text
Hit10KLimitWindows, SubdividedWindows, AutoCompletenessIterations,
ExplodedRows, ExplosionEvents, ExplosionRowsFromEvents, ExitCode
```

---

## Installation

### Download v1.7.4 (This Version)
Use the direct download link below to obtain this specific version:
- **Script v1.7.4**: [PAX_Purview_Audit_Log_Processor_v1.7.4.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.7.4/PAX_Purview_Audit_Log_Processor_v1.7.4.ps1)

### Related Assets

- **Documentation (v1.7.4)**: [PAX_Purview_Audit_Log_Processor_Documentation_v1.7.4.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Documentation_v1.7.4.md)

---

## Upgrading from v1.7.3

### Is Upgrade Recommended?

**Yes – strongly recommended** if you need automated completeness detection, structured metrics, or CI/CD integration.

### Zero-Risk Adoption

All existing commands work unchanged. New switches are optional.

### Suggested Migration Path

1. Replace script file with v1.7.4
2. Add `-EmitMetricsJson` to baseline command
3. Integrate exit code handling in automation (treat 10/20 as non-success)
4. On incomplete exports (exit code 10), re-run with `-AutoCompleteness`

---

## Support & Feedback

For issues or feature requests:

- Open a GitHub Issue in the repository
- Include metrics JSON + relevant log excerpt when reporting completeness or performance questions

---

## Summary

v1.7.4 elevates the Purview Audit Log Processor from performance-efficient to **observability-driven**, enabling rigorous export quality assurance with minimal manual inspection.

---

**Enjoy the release and keep the feedback coming.**
