<div align="center">

# PAX — Prerelease Preview

**Portable Audit eXporter (PAX) · Purview Audit Log Processor**

**v2.0.0 prerelease 20261101-14**

**Preview build — not a production release.**

[Download](#download) · [Before you run it](#before-you-run-it) · [What's changed](#whats-changed) · [Upgrade checklist](#upgrade-checklist) · [Known limits](#good-to-know) · [Report a problem](#report-a-problem)

</div>

---

## What this branch is

This branch holds **early preview builds** of the PAX Purview Audit Log Processor — versions published ahead of general release so that real-world feedback can shape them *before* they ship to everyone. Anyone who finds this branch is welcome to use what's here; it simply isn't advertised alongside the released version.

A prerelease build is **not** the released product. The current released version always lives on the [`release`](https://github.com/microsoft/PAX/tree/release) branch, and that is what you should use for anything you depend on day to day.

---

<a id="download"></a>

## Download

<table>
<tr>
<td>

### [PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20261101-14.ps1](https://github.com/microsoft/PAX/releases/download/purview-v2.0.0-prerelease-20261101-14/PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20261101-14.ps1)

<sub>Click the file name above to download the script directly.</sub>

<sub>**SHA256:** `AD4E8864FC8A0DC498F7C4550BE59A5BEEA9A581D70074B752ECE6A2DFC3EE86`</sub>

<sub>Verify your download with `Get-FileHash .\PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20261101-14.ps1 -Algorithm SHA256`</sub>

</td>
</tr>
</table>

<details>
<summary><strong>Updates in this preview</strong></summary>

- **Newer installed recovery dependencies are accepted:** pyarrow 25.0.1 and deltalake 1.6.3 are minimum stable versions, not exact-version pins. Both publication-only prerequisite checks accept newer stable releases without installing, upgrading or downgrading packages. This does not claim that every future package combination has been qualified.
- **Recover directly from the original checkpoint:** `-ResumePublishOnly -Resume <original-checkpoint-path>` builds its own recovery plan from supported retained files, current managed identity and read-only destination observations. No hand-built manifest, manually supplied hashes/counts or separate preparation helper is required. Existing destination snapshots need explicit `-ApproveExistingSnapshot` after reviewing the displayed plan; unrelated or changed targets remain protected.
- **Finish eligible Fabric publications without starting over:** publication-only recovery reuses completed AIO/ValueLens outputs, raw exports, augmented Users and Agent 365 snapshots. It does not collect audit data, refresh directory/catalog data or repeat dashboard rollups. Ordinary Resume is unchanged; `-PublishRecoveryManifest` remains optional advanced input.
- **Multiline and large CSV values:** both CSV-to-Delta conversion paths use strict logical-record-aware reading, preserving quoted line breaks, Unicode, empty strings and literal values. Malformed quoting, inconsistent row widths and values beyond the qualified bounds are refused, not silently skipped or altered.
- **Recovery without full CSV duplication or duplicate verification:** publication-only recovery locks retained sources in place and verifies current hashes, schemas, logical counts, temporal UserKeys and destination state. A successful full source proof is reused only after matching source locks, current hashes and its checkpoint/plan/validator bindings are established. Scratch and reserve budgets derive from free space, with optional explicit limits; Parquet and proof working space is still required.
- **Bounded, resumable large local verification:** new automatic recovery plans allow **24 hours per local unit**, rather than one hour for an opaque ten-file job. `-RecoveryOperationSeconds` can set **60–604800 seconds (7 days)** before the plan is saved. Measurement and strict CSV proofs persist completed per-source receipts; temporal/license/UserKey RI persists completed per-profile receipts. Reuse requires current read locks, SHA256 hashes and matching checkpoint/run/path/role/validator/contracts, not file dates or unfinished SQLite. Interrupted or unreferenced work can still require repetition. Local Parquet preparation and snapshot verification use the same finite local limit; verified snapshots remain read-locked through their remote operation. Phase/role/member start, minute heartbeat and deadline messages contain no row values or credentials.
- **Saved budgets and remote safeguards remain authoritative:** finalized plans keep their recorded capacity and runtime, including older one-hour plans; neither their hashes nor their limits are silently rewritten. An owned interrupted initial plan without finalized expectations can safely restart and reuse completed matching units. Lightweight prerequisite/envelope checks remain bounded to **120 seconds**. Remote observe/write/restore work remains limited to the lesser of the saved limit, **3600 seconds** and token lifetime minus **300 seconds**, refusing less than **60 seconds** of safe lifetime. Scratch/reserve checks include retained plan receipts and unfinished artifacts throughout recovery. These changes do not establish customer-scale performance or live managed-identity qualification.
- **Fail-fast worker prerequisites:** before retained-file verification, recovery checks the executing Windows/x64 PowerShell host, actual 64-bit Python/package imports, and supported Az.Accounts discovery/import in a fresh process using that same host and account. Selected versions and paths are reported. This preflight does not sign in, acquire tokens, install packages or establish managed-identity/Fabric access; authentication still follows retained-source proof.
- **Protocol-correct Fabric recovery markers:** marker append no longer sends conditional headers unsupported by the DFS API. Creation, flush, readback and deletion retain the required ownership and version checks.

These targeted recovery and conversion changes are not a general checkpoint migration. Publication-only recovery requires a supported retained run; PAX generates and preserves its matching plan. Preserve the original files and never edit a checkpoint to force compatibility.

</details>

---

<a id="before-you-run-it"></a>

## Please read before you run it

> [!IMPORTANT]
> **This is a preview, not a production-qualified build.** Validation includes targeted synthetic and native local coverage and limited live AIO/ValueLens SharePoint and Fabric run reviews, not complete end-to-end qualification across supported modes and destinations.

- **Check the results against your own tenant** before relying on them, sharing them, or publishing them to a dashboard. Confirm row counts, dates and included people.
- **Keep a copy of anything important.** Use a new output folder or destination rather than the files your reporting depends on.
- **Preserve recovery material.** Resume needs the checkpoint and its matching saved data. Missing, changed, contradictory or unverifiable completion evidence stops the run; do not edit a checkpoint to make it pass.
- **Recovery is not de-identified output.** With `-Deidentify`, preserve the checkpoint's owner-only local recovery directory alongside its saved data. Recovery stops if private permissions cannot be enforced. Fabric's existing resume mirror contains identified recovery data too; local private permissions do not establish remote access protection.
- **Treat pending restoration as potentially changed data.** A failure after replacement begins can leave a partially updated destination. Preserve the checkpoint, candidates, originals and recovery markers. An unrelated fresh run does not depend on finishing an older checkpoint; an older resume cannot overwrite newer unrelated destination changes.
- **Choose append to retain activity history.** A non-append Delta run publishes the requested snapshot, not a union with the existing table, and a valid snapshot may contain fewer rows.
- **Keep preview outputs separate from production.** Behavior and file names may change before release. Do not assume checkpoints or histories can be opened by another version.
- **Preview builds are tagged as pre-release, never as the latest release**, and are not linked from the main README.

---

<a id="whats-changed"></a>

## What's changed since v1.11.15

These are the net changes from the current production release to this **v2.0.0 preview**, grouped by capability rather than by preview build. Start with the highlights and the upgrade checklist; expand any area below for the full detail.

### Highlights

- **Recover completed Fabric work.** Eligible publication-only recovery finishes saving retained outputs without another audit pull, directory/catalog refresh or dashboard rollup.
- **Handle difficult CSV text.** Fabric conversion preserves quoted multiline and large values within explicit qualified bounds, with strict structural checks.
- **Several dashboards from one collection.** `-Dashboard AIO,M365,ValueLens,CoworkAdoption` produces every requested data set from one collection, including the new **Cowork Adoption** inputs, and append works across those histories.
- **Incremental catch-up.** `-Watermark` adds only the missing whole days to a CSV history on Local, SharePoint or Fabric Files.
- **Licensing that reflects access.** `-CopilotAccessGroups` counts a user as licensed only when they also belong to a Copilot access group; `-UserHistory On` keeps observed licensing states over time (off by default).
- **A richer Agent 365 catalog.** 44 template-compatible columns, with developer and creator filled in from explicit evidence.
- **Faster large jobs.** Memory-aware rollup and accelerated directory and append processing.
- **Safer outputs.** Candidates are verified before and after publication, and restoration is attempted if a later step fails; `-Deidentify` also covers retained raw files.
- **Collection that keeps moving.** A full Microsoft 365 history queues in one command, and searches are created as download slots free, so data starts arriving from the first completed search.

<a id="upgrade-checklist"></a>

### Upgrade checklist

- **Publication-only recovery is opt-in, not ordinary Resume.** Supply `-ResumePublishOnly` and the explicit original `-Resume` checkpoint path. PAX derives its plan; you do not author a manifest. It supports retained initial AIO + ValueLens Fabric Tables snapshots with raw exports, UserHistory On and complete directory/Agent snapshots, not append, watermark or de-identified recovery. Existing destination snapshots require review of the displayed plan and a repeat of the same command with `-ApproveExistingSnapshot`; it reuses the saved plan and proofs rather than recollecting or rolling up again. No scope, authentication or destination overrides, checkpoint auto-selection or `-Force` fallback are accepted. `-PublishRecoveryManifest` remains optional advanced input.
- **Check the recovery environment and working space.** Publication-only recovery requires Windows x64, a 64-bit PowerShell 7+ host, existing 64-bit Python 3.10+ on PATH, stable pyarrow 25.0.1 or later, stable deltalake 1.6.3 or later and Az.Accounts 2.12.0 to below 6.0.0. The executing worker's imports, versions and selected paths are checked before retained-file verification, without authentication or dependency installation. The default scratch budget is 85% of current free space after a 10% reserve, with that reserve bounded to 1-8 GiB, and a 32 MiB safety margin. New plans allow 86400 seconds (24 hours) per local unit; explicit local limits range from 60 to 604800 seconds (7 days). Saved plans retain their original limits. Remote operations retain their 3600-second ceiling and token safety margin. `-RecoveryMaxScratchBytes`, `-RecoveryReserveBytes` and `-RecoveryOperationSeconds` can set explicit limits before the plan is saved. Existing input files remain in place; conversion and proofs still need working space.

- **Use PowerShell 7.0 or later for every mode.** Windows PowerShell 5.1 is unsupported; `-UseEOM` remains available under PowerShell 7.
- **Remove retired switches** from scheduled jobs and saved commands: `-ExplodeArrays`, `-ExplodeDeep`, `-ExportWorkbook` and `-RAWInputCSV` are refused before sign-in.
- **Unattended rollup runs** need an explicit `-Dashboard` or `-Force`; otherwise PAX asks which dashboard to build.
- **Update automation and reports that use generated names.** Dashboard files now start with `AIO_`, `ValueLens_`, `M365_` or `CoworkAdoption_`, and Fabric table names no longer carry run timestamps. Point Power BI connections and notebooks at the new names.
- **Check prerequisites.** Accelerated append needs Python 3.10+ and SQLite 3.24+ (checked before collection). PAX uses Microsoft Graph PowerShell v2.25.0–v2.40.0. `-CopilotAccessGroups` needs `GroupMember.Read.All`.
- **For `-Watermark`,** supply `-WatermarkStartDate` only on the first run, and use a CSV append target.
- **In-progress collections:** finish a Microsoft 365 usage collection started on v1.11.15 or earlier on that version, or start fresh.

**Checked recovery launch for an unattended wrapper.** Replace only the two example file paths below with the downloaded script and original checkpoint paths. Run the wrapper on the Windows x64 worker that holds those files, not in an Azure-hosted sandbox. It starts a fresh, noninteractive PowerShell process and turns any nonzero PAX exit into a terminating wrapper error; an outer host's green status alone is not proof of accepted publication.

```powershell
$ErrorActionPreference = 'Stop'
$pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop).Source
& $pwsh -NoLogo -NoProfile -NonInteractive -File 'C:\PAX\PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20261101-14.ps1' -ResumePublishOnly -Resume 'C:\PAX\output\.pax_checkpoint_YYYYMMDD_HHMMSS.json'
$paxExitCode = $LASTEXITCODE
if ($paxExitCode -ne 0) {
    throw "PAX recovery process failed with exit code $paxExitCode."
}
```

Keep the original checkpoint, retained CSVs and recovery directories in place. Do not add ordinary collection switches, clear unfinished state, or add `-ApproveExistingSnapshot` unless PAX requests approval and you have reviewed its displayed saved plan. This wrapper does not establish managed-identity or Fabric access.

### Details by area

<a id="new-capabilities"></a>

<details>
<summary><strong>New capabilities</strong></summary>

**Publication-only recovery from completed outputs.** `-ResumePublishOnly` with an explicit original `-Resume` checkpoint finishes eligible initial AIO + ValueLens Fabric Tables publications without running the collector, directory/group/catalog refresh, raw-file assembly or either dashboard processor. It uses the original run's raw audit and directory exports, completed facts, augmented `.csv.withaudit` Users and Agent catalog/status files. Both dashboards, both shared raw tables and Agent catalog/status form the required eight-table set. PAX derives and retains a strict plan containing run/window/destination/identity bindings, current source hashes, complete headers, logical row and distinct UserKey counts, read-only target observations and capacity limits. These current-byte hashes are a new recovery baseline, not proof of past authenticity. Missing, changed, contradictory or unsupported state stops without ordinary-mode fallback. Existing snapshots are not automatically authorized for replacement; review the displayed plan before using `-ApproveExistingSnapshot`. An optional advanced `-PublishRecoveryManifest` still accepts an explicitly prepared plan. Ordinary collection and Resume keep their established entry points.

**Choose the dashboard before processing.** A fresh `-Rollup` or `-RollupPlusRaw` run without `-Dashboard` asks you to choose **AIO, ValueLens, M365, CoworkAdoption**, or **raw exports only**, in that order. Enter several, separated by commas, to produce more than one from a single collection (for example `1,2` or `AIO, ValueLens`); spaces are ignored and duplicates are removed. Raw exports only can't be combined with a dashboard. Enter selects AIO; `-Force` selects AIO without prompting. Raw-only selection disables both rollup switches. Explicit dashboard selections, raw-only and directory/Agent-only runs are unchanged; Resume keeps its checkpoint's dashboard and output mode, including CoworkAdoption. Existing compatibility checks still apply: use `-Dashboard M365` with `-IncludeM365Usage` rollups, and supplied audit files still require rollup processing. Unattended rollup runs need an explicit dashboard or `-Force`.

**Multiple dashboards from one collection.** `-Dashboard AIO,M365,ValueLens,CoworkAdoption` generates the requested data sets from one collection. Including M365 includes its usage activities. Each dashboard's files go beneath its own folder on Local, SharePoint and Fabric Files; a single-dashboard run keeps the supplied folder. Tables/Delta uses distinct dashboard-prefixed tables, with shared raw and Agent 365 outputs written once. Each required member must verify before the set is accepted. This is not an atomic cross-table or cross-service transaction. `-FillerLabel` is accepted when M365 is one of several dashboards: it applies to the AI-in-One and ValueLens Users output and is ignored for M365. A single-dashboard M365 run still refuses it.

**Append to multiple dashboard histories.** The existing `-AppendFile`, `-AppendUserInfo` and `-AppendAgent365Info` selectors resolve the corresponding histories for each dashboard. AIO and ValueLens retain their own user, message and conversation keys. Missing, incomplete or ambiguous histories are refused rather than guessed. If an added dashboard lacks history, PAX stops before collection and provides a separate backfill command. Resume cannot change dashboard membership; start a new combined run after preparing compatible histories.

**Cowork Adoption inputs.** `-Dashboard CoworkAdoption` enables rollup and user collection and produces a Purview CSV and a Users CSV, alone or with other dashboards. Supply each file's full path to its matching template input. The Users input uses the collected PAX Copilot license evidence. Scheduled counts describe prompt setup, not independently observed executions; unavailable record-level credits stay blank. These files are not an admin-center usage import or a billing report.

**Incremental catch-up.** `-Watermark` collects missing whole UTC days into a Local, SharePoint or Fabric Files CSV `-AppendFile` target; it does not support Tables/Delta. Supply `-WatermarkStartDate` only for the first run, and do not supply manual start/end dates. The marker advances only after every required output publishes and verifies. A current target finishes without service calls. Resume restores the saved window: do not repeat watermark switches. Supplied audit files, `-UseEOM`, directory-only and Agent-only runs do not support watermark mode.

**Copilot access groups.** `-CopilotAccessGroups "Copilot Access - Wave 1","Copilot Access - Wave 2"` names the Entra group(s) that permit Microsoft 365 Copilot use. Use it when a license bundle such as Microsoft 365 E7 assigns the Copilot license to more people than are allowed to use it. `hasLicense` is then TRUE only for users with an enabled Copilot license **and** membership (direct or nested) in at least one listed group. Licensed users outside the groups, and group members without a Copilot license, are FALSE; Unknown stays Unknown. It changes no rows and filters nothing; every dashboard Users input uses the adjusted value. It needs Graph API mode, `GroupMember.Read.All` and the Entra users output, and stops before changing anything if a group can't be resolved. `-Resume` restores the checkpoint's groups; `-Watermark` schedules may add or change them.

**Complete parameter snapshot.** The Parameter Snapshot printed at the start of a run, and saved in the metrics JSON, now includes every customer-facing setting: watermark mode, supplied input files, `-CopilotAccessGroups`, `-ExportProgressInterval` and Graph completeness options. On `-Resume` it shows the restored scope, filters and inputs rather than the resume command's defaults.

**Observed user history.** `-UserHistory On` records effective-dated licensing observations for AIO and ValueLens. It retains stable state keys and audit-only Unknown rows without adding duplicate states on unchanged appends. `EffectiveDate` identifies the collection window in which a state was first recorded, not a proven license-assignment date. History is **Off by default**; neither mode reconstructs unobserved past licenses. An M365-only run refuses history mode; when M365 is one of several dashboards, history applies to the other dashboards' Users output. A compatible history-aware model is required; see [Known limits](#good-to-know).

**Full Microsoft 365 historical collection.** A single command queues the entire requested usage range rather than capping it part-way through. Concurrency limits active work, not the total range.

> **Upgrading an in-progress Microsoft 365 usage collection:** finish it on the version that started it, or start a fresh collection. The new partition layout can cause an old resume to stop or re-collect the requested range. Completed collections and ongoing append histories are unaffected.

</details>

<a id="speed"></a>

<details>
<summary><strong>Speed and visible progress</strong></summary>

**Reuse completed CSVs instead of cloning datasets.** Publication-only recovery holds read-only locks on the original retained files and uses independently owned Parquet/proof working directories. It avoids the complete CSV staging and producer-replay copies, including during accepted replay. A successful full source proof is cached with its checkpoint, source, plan and validator bindings and reused only after the retained sources are locked and their current hashes match; changed receipts or inputs are refused. Strict checks still read the saved data; this is not an instantaneous upload or a zero-scratch operation. Scratch/reserve budgets derive from free space unless explicitly set, and runtime/token limits remain bounded. Invalid initial budgets leave no unowned plan artifacts that would obstruct a corrected retry.

**Memory-aware rollup.** Jobs that fit the estimated budget use the in-memory Copilot rollup; larger jobs use disk-backed processing with the same output contract. The log identifies the path and budget. This bounds working buffers, not all process memory.

**Accelerated directory and append processing.** Directory preparation, retained-key matching, seed creation and append reconciliation use scalable processing without sampling history. Unicode identities, quoted delimiters, quotes, embedded newlines and large CSV fields remain supported on the accelerated path, using the executing host's comparison rules. Invalid data fails explicitly; dedicated compatibility paths are identified in the log.

**Faster compatibility sorting.** Shared bounded sorting, CSV serialization and composite-key construction reuse compiled primitives while preserving host comparison rules, stable ordering and output values. Retained histories still require complete scans and merges; this is not a customer-runtime or memory-ceiling guarantee.

**Prerequisites and progress before expensive work.** Accelerated append requires Python 3.10+ and SQLite 3.24+, checked before collection. Allow working-disk space comfortably larger than the histories plus new output. Narrowing audit dates does not avoid reading retained history for key continuity. Long stages report aggregate progress and integrity counts without printing audit rows or personal identifiers; sign-in validity is checked again after directory preparation.

</details>

<a id="protection"></a>

<details>
<summary><strong>Protecting existing data</strong></summary>

**Retained sources and complete recovery intent stay fixed.** Publication-only recovery keeps the original checkpoint and CSVs unchanged, binds its generated or explicitly supplied plan and full eight-table roster to an owned journal and verifies source hashes across the operation. It retains temporal UserKeys, licensing observations and augmented Users rather than rebuilding them. Read-only target observations are frozen before approval; version/content fences refuse subsequent unrelated destination changes. Accepted replay verifies the stored result without another table commit; interrupted publication retains the existing restoration and potentially-modified-state safeguards. No missing member, malformed record or unknown source is silently substituted.

**Independent processed Users checks.** Verification follows the producer's Unicode normalization and existing de-identification tokens without changing salts, schemas, history keys or analytical rules. A failed isolation attempt is reported as a failure. The protection digest remains a logical-consistency check, not proof of authenticity.

**Verified publication and independent recovery.** Candidates are checked before replacement and read back afterward. A refusal before publication leaves the affected targets unchanged. A later failure triggers restoration where possible; an unverified restoration is reported as potentially modified data, with recovery material retained and no affected watermark advance. Failed sets are not retried by the final upload sweep. Logs, raw recovery files or successfully generated local files are not proof of a completed remote dataset.

**Stable identities and complete Users references.** First-run and append output includes minimal Users rows for identities found only in audit activity, including multi-dashboard and history paths. Retained user, message and conversation mappings remain stable. A refused merge reports conflicting keys, people and missing or mismatched references and writes a complete private local conflict list. Resolve conflicts from a known-clean target or validated re-baseline, not a manual blind merge.

**Missing licensing stays Unknown.** Directory collection includes the license assignments needed to retain licensed accounts even when name fields are empty. AIO and ValueLens use `Unknown` for missing or unrecognized evidence in both Users and activity; explicit positive/negative evidence and license-independent agent and Cowork classifications remain distinct. Unknown is not Unlicensed.

**No automatic historical reclassification.** An overlapping append whose stored and new license classifications conflict is refused before replacing either Fact/Users output. Preserve the dataset and reconstruct affected dates separately from original evidence before reviewing a replacement. Disjoint runs and unrelated checkpoints do not require that recovery.

**Microsoft 365 append retains daily history.** Rollup, UserStats, SessionCohort and SessionStats are prepared and checked together. SessionStats is found beside its Rollup anchor, including first-run timestamped companions and remote histories. Re-collected days with new rows replace the corresponding stored days instead of doubling them; days with no new rows retain history. Percentiles use the full retained SessionStats history. A missing required companion stops preparation before replacement. Empty results retain headers and never replace existing history.

**De-identification covers retained raw outputs.** `-Deidentify` protects designated identity fields in retained Purview and Entra Users files as well as dashboard outputs, including `-RollupPlusRaw`. Protected Users CSVs add `PAX_DeidentifyPolicy` and `PAX_DeidentifyDigest` to verify append compatibility. The digest checks logical content consistency, not authenticity against someone replacing both data and digest; it does not make all remaining data anonymous. Older protected histories without valid metadata require regeneration from original identified sources, not manual rehashing.

</details>

<a id="collection"></a>

<details>
<summary><strong>Collection, resume and run results</strong></summary>

**A separate no-collection recovery route.** Publication-only recovery is dispatched before ordinary sign-in, dependency installation, shard hydration, collection and processing. Its narrow supported contract is a non-append, non-watermark, non-deidentified initial AIO + ValueLens `-RollupPlusRaw` snapshot with retained UserHistory On inputs and managed-identity Fabric Tables output. Automatic planning verifies the original source contract before deriving file proofs, discovers the current storage identity through isolated managed-identity authentication and observes the eight destinations read-only. No directory, group or catalog query supplies recovery data. A missing or unsuitable saved set refuses explicitly; it never becomes a fresh export or a request to approve data loss. It does not turn every older checkpoint into a compatible resume.

**Retained JSONL must complete cleanly.** Malformed or non-object records and read, write, flush, close, combine or final-publication failures refuse completion while preserving original files and recoverable shards. A healthy export retains the existing output semantics.

**Source-preserving recovery.** Dictionary and object responses retain source identities and audit payloads. All requested operations, record types and service filters survive retries and recovery, including intentionally omitted M365 filters. Snapshots belong to their complete query contract, not just a partition number. Resume and export validate their exact filename, digest and record count.

**Completion is reconciled with saved data.** Collection checks service counts, completed-partition counts and final export counts, accounting for duplicates and date trimming. Incomplete retrieval, unusable records or failed data/checkpoint saves cannot become successful empty results or later false completions. Genuine zero results are valid and still produce requested independent outputs. Missing activity detail is counted separately; a faster-reader rejection is tried with the standard reader before an unreadable-record refusal withholds affected outputs and records the gap.

**Checkpoint-scoped Resume.** Resume follows only the selected checkpoint and its saved publication state; old shared markers do not block unrelated work. Integrity, ownership and concurrent-change checks still apply. Fabric verifies the local checkpoint before backing it up, supports hidden checkpoint names, and retries page writes briefly when backup holds a file. Lock errors report the actual cause and path; foreign-host lock age uses UTC.

**Recovery survives downstream failures.** Current-run checkpoints and required recovery data are retained until processing, required publication and final uploads succeed. CSV finalization uses staged, no-overwrite publication and reports copy or log-finalization failures. With `-Deidentify`, a later finalization failure withdraws the newly created identified CSV into private recovery. Successful Resume cleans the verified selected checkpoint even if renamed; relative checkpoint and lock paths follow the PowerShell location. Supplied inputs and unrelated checkpoints remain protected.

**Accurate monitoring and failure results.** Reused queries are distinguished from newly created ones. Terminal partitions are reconciled with their specific jobs without stopping healthy work merely for taking a long time. Invalid Resume arguments, destination preflight refusals and post-processing failures return nonzero results. An ordinary non-AISID resume is not diverted by empty AISID metadata.

**Scope and dates are explicit.** `pwsh -File` accepts comma-separated `-UserIds "a@contoso.com,b@contoso.com"` and quoted `-GroupNames "Engineering Managers","Product Leads"`. Empty or unresolved effective audit scopes stop rather than widening to the tenant. An intentionally empty directory scope produces a header-only Users file. Date-only live windows use inclusive UTC midnight through exclusive UTC midnight; an empty or reversed range is refused before sign-in.

**Search creation keeps pace with downloads.** Purview runs up to 10 audit searches at once per account. PAX creates each partition's search in the background only when a download slot is free, so a large collection starts downloading from the first completed search instead of waiting for every search to be created, and a slow search request holds up only its own partition. A request that drops on the network is confirmed against Purview for up to 5 minutes and then requested again automatically, with a check for the earlier request first, so it never stalls the run or needs a manual resume. A throttled search request while other partitions are downloading is retried later and does not count as a partition failure.

**Supplied inputs avoid unnecessary audit sign-in.** A fully local run with supplied audit and complete Users files does not contact services. Fabric output still authenticates to Fabric, but needs no audit sign-in when no live directory or Agent collection is required. Resume retains supplied input references and accepts `GRAPH_CLIENT_SECRET` for App Registration. `-StartDate` and `-EndDate` do not filter a supplied audit CSV.

</details>

<a id="destinations"></a>

<details>
<summary><strong>SharePoint, OneDrive and Fabric destinations</strong></summary>

**Strict multiline CSV-to-Delta conversion.** Delta preparation and the CSV conversion helper use explicit quoted-newline support with bounded logical-record sizing, rather than assuming records fit an arbitrary read block. String values, empty strings, Unicode and embedded CR/LF remain intact. Invalid structure is reported explicitly, without dropping rows or treating parsing as a successful upload. Recovery marker append follows the DFS protocol without unsupported conditional headers; marker creation, flush, readback and deletion retain their ownership/version checks.

**Verified history downloads and readback.** Interrupted SharePoint reads retry bounded exact byte ranges, refresh download access only for the same item/version, and verify the complete local file before admission. Replacement preserves existing local owner, group and access settings without deleting the destination or relaxing permissions. Failed admission retains verified recovery material; a competing new or changed destination is not overwritten. Complete-set readback distinguishes metadata, range, retry, structure, length, digest and changed-version refusals before accepting required AIO/ValueLens members.

**Predictable filenames and tables.** Generated dashboard-owned filenames begin with `AIO_`, `ValueLens_`, `M365_` or `CoworkAdoption_`; raw inputs, Agent 365 files and logs remain unprefixed. Explicit filenames and append targets keep their names. Entra raw and processed outputs stay distinct, as do all four M365 companions, including when a requested name already ends in `_Rollup`. Supplied-input Facts are published under their produced name even if they carry an older timestamp. Update automation that relies on generated names. M365 outputs carry one timestamp, the run's (for example `M365_Purview_Audit_UsageActivity_CombinedActivityTypes_Rollup_20261007_095129.csv`), and the M365 folder's copy of the Entra users export is named `M365_EntraUsers_MAClicensing_<timestamp>.csv`. Histories written with the earlier names are still found by append and watermark runs.

**Stable Fabric dataset names.** Table names omit run timestamps: for example `AIO_CopilotInteractions`, `AIO_Users`, `ValueLens_Users` and `M365_Rollup`. Shared names are `CopilotInteractions_Raw`, `Entra_Users_Raw`, `Audit_Raw`, `Agent365` and `Agent365_Status`; M365's dashboard Users table is separately `M365_Entra_Users_Raw`. Old tables are not renamed or deleted. Update Power BI connections and notebooks.

**Fabric validation and readback.** Lakehouse names, IDs, folders with spaces and physical schema placement are resolved before collection. Required Files/Tables roots and output-specific destinations are checked; missing or ambiguous lakehouses and Warehouse items are refused. Valid nonempty Users and non-append snapshots may shrink; activity-history append, schema and reference safeguards remain. Readback compares full data by column name after verifying names, types and nullability, even if physical column order differs. Failures identify the table, intent, counts or failed comparison.

**Fabric authentication and dependencies.** Az.Accounts runs in a separate process to avoid Graph authentication-library conflicts while preserving supported Azure, managed-identity and app-registration sign-ins. Delta checks both `pyarrow` and `deltalake`; Windows on ARM uses x64 Python, with current-user installation when allowed and no PATH/default-Python change. Failed Delta delivery may retain a recovery CSV in Files, but is not successful table publication.

**Reliable paths and transfers.** SharePoint and OneDrive resolve the correct library, including folders with spaces. CSV sharing links are resolved to the actual item and non-CSV items are refused; logs omit sharing tokens. Linux local paths use the platform separator. Remote runs have separate working folders even when started together. Large SharePoint uploads recover from the service-confirmed offset within network tolerance, including a bounded sign-in renewal when session creation is unauthorized; existing permissions still apply.

**Expected responses are not failures.** Optional missing recovery markers and OneLake directories (`GET 404` with exact `PathNotFound`), and already-existing directories during idempotent creation (`PUT directory 409` with exact `PathAlreadyExists`), do not print misleading errors. Required paths, access refusals and immutable-file conflicts remain errors. Local watermark replacement retries brief file locks and keeps the previous marker if saving fails.

</details>

<a id="agents"></a>

<details>
<summary><strong>Agent 365 catalog</strong></summary>

**Reuse a completed catalog during publication-only recovery.** The retained catalog, both dashboard aliases and the independently timestamped retrieval-status file are verified as members of the original output set. This recovery path does not list packages or fetch details again. It changes neither the catalog schema nor the existing behavior of a fresh `-IncludeAgent365Info` run.

**Expanded, template-compatible metadata.** The catalog has 44 columns, with existing names/order retained and 16 ValueLens fields added after `Uploaded files`; the retrieval-status file keeps its four-column contract. Descriptions use Graph's long/short descriptions, and `Created in` uses its platform. Supported nested definitions supply instructions, actions, unique bot IDs and declared capabilities. Manifest JSON is data, never executed, and referenced URLs are not fetched. Capabilities describe declarations, not verified permissions or a discovered file inventory.

**Availability, sharing and status mean different things.** `Availability` contains Graph's `availableTo` access policy. `Groups shared` and `Users shared` contain explicitly shared resource IDs as compact JSON, not allowed/acquired audiences or expanded membership. `Status` is `Blocked` or `Not blocked`, not a deployment or activity assertion. Zero, false, empty, null and unavailable values are distinguished rather than guessed.

**Developer and creator are filled in.** `Developer Name` uses the developer declared in the agent's definition, otherwise the package publisher. Generic default text (`Agent Developer`, `Published by your Org`, `Your developer name`) names no developer, so `Developer Name` is left blank for it; `Publisher` keeps the catalog's text unchanged. `Creator Id` is the catalog owner, and `Created by` is that owner's user principal name. When the catalog states no owner, an in-house agent (any type other than Microsoft/`firstParty` or third-party/`thirdParty` store agents, including `lob`, `shared` and `sideloaded`) uses the owner of its Entra agent identity, its app, or the bot app in its definition. Each of those identifier kinds is checked on a spread sample of 40 first, and the rest of that kind is looked up only when the sample finds an owner, so a large catalog is not walked for nothing. A creation audit event within the run's dates takes precedence when one matches. Store agents have no tenant creator and leave `Created by` blank. The log counts owner IDs that no longer match a user (for example, deleted accounts); `Creator Id` still shows them. In the Zava demo tenant (14,888 agents, measured 2026-10-08) the catalog `appId` and bot app IDs of Agent Builder, Copilot Studio and Foundry agents were not registered in the tenant, so most of those agents have no creator the directory can supply and `Created by` stays blank for them. `-AppendAgent365Info` keeps a creator the existing catalog already holds when this run can't resolve one. Owner names need `User.Read.All`; app owners need `Application.Read.All`; either missing leaves those cells blank with a note in the log. Nothing is guessed from who used the agent.

**Usage is fresh and has its own window.** Every run requests package details in bounded parallel batches, preserving listing order and using the selected Graph module version. Cached package modification dates do not establish usage freshness; detail reuse is disabled, so repeat runs incur fresh requests. `Active Users` and `Total sessions` cover the last 30 days at retrieval, not the audit date range. `Exception rate` retains the service value without an invented percentage; `Last Activity Date` uses its last-used timestamp.

**Agent identities are not interchangeable.** `Entra Agent ID` uses the true `agentIdentityId`, not an application or bot ID. Catalog titles and activity titles use a common bare form; supported compound IDs recognize `P_` or `T_` title segments before a trailing GUID. Ambiguous or malformed identities remain unresolved, and raw Agent IDs are retained. Creator/developer values require explicit evidence, not publisher, display-name or application-owner guesses.

**Retrieval and field coverage are separate.** The status file tracks listing, detail retrieval and row construction; logs report population and source states for every column. Every agent retrieved is written. A refused catalog page is retried in place with short backoff (the listing is not restarted), and agents whose details fail are requested again right away; if a first small retry recovers nothing, PAX stops retrying instead of slowing the run, and writes those agents from their catalog fields alone. Agents that still could not be fully retrieved are listed in an **Agent 365 Summary** at the end of the run; they do not change the exit code. Only a run that produces no Agent 365 catalog at all reports exit 40. Append retains target-only historical rows and supports compatible legacy identifiers. GA Graph reads are preferred with a compatibility fallback; structured throttling retries honor network tolerance and service waits, while genuine permission failures remain explicit.

**Agent privacy protection.** Under `-Deidentify`, names and supported personal creator/sharing IDs are pseudonymized; free-form descriptions, instructions, actions and resource details are withheld. Application join IDs remain usable. Raw detail caches are not written, and logs distinguish privacy withholding from absent, malformed or unretrieved data.

</details>

<a id="accuracy"></a>

<details>
<summary><strong>Classification and reporting accuracy</strong></summary>

**Security Copilot records are trimmed during dashboard preprocessing.** AIO, ValueLens, M365 and Cowork Adoption skip explicit Security Copilot product activity before expansion, activity-key allocation and aggregation. The match includes the bare `SecurityCopilot` host, its `SecurityCopilot-` family, explicit product names and the documented `Copilot.Security.SecurityCopilot` application identity, case-insensitively. That application identity does not depend on a SecurityCopilot-prefixed host. It does not use user names, "General Chat", license status or prompt text. Retained raw exports and the existing directory/licensing population are unchanged.

**No new seed run or append requirement.** Existing histories, seed maps, append, publication and Resume keep their established behavior. There are no new policy receipts, output-folder restrictions or migration gates. The filter applies to raw records processed by this build; it does not retroactively rewrite previously stored historical rows or aggregates.

**Categories follow observed evidence.** A referenced file or app does not alone prove creation, review or summarization. Specific resource families are not displaced by generic links; citations are not automatically web searches, Loop is recognized, and unknown resource types remain visible. A message touching several resources still counts once in overall interaction totals; category counts can overlap.

**Dashboard labels remain compatible.** Published labels, including Email Summarising, Meeting Prep and Presentation Summarising, stay unchanged. Classification improves modeled Human Equivalent Hours for templates consuming producer values; templates calculating their own values are unaffected. These remain assumptions, not measured time savings or a guaranteed tenant uplift. Append preserves existing classifications; use original inputs to rebuild a consistently classified history.

</details>

<a id="messages"></a>

<details>
<summary><strong>Messages, logs and guidance</strong></summary>

**Recovery refusals do not prescribe another collection.** Publication-only errors identify the failed run/manifest binding, retained-source proof, capacity or runtime budget, identity/token condition, destination fence or marker operation. A stopped recovery is not reported as accepted publication and never silently switches to collection. The opening and closing version labels identify the downloaded prerelease script consistently.

**Append I/O is distinct from identity conflicts.** Bounded diagnostics identify the stage, operation, file role and native error code. A file read/write failure is not reported as a user-key conflict or an instruction to rebaseline history.

**Failures explain the next step.** Audit refusal logs include the returned error, request identifier, service diagnostics and policy challenge. Permanent permission/policy refusals stop promptly; transient failures retain retry behavior. Remote read errors identify the requested destination. SharePoint guidance distinguishes delegated site access, tenant-wide app-only `Sites.ReadWrite.All`, and app-only `Sites.Selected` with a write grant.

**Generation is not publication.** Final messages name accepted physical Delta destinations or identify local processing copies, rather than inventing remote CSVs. Append targets are labeled before work and outcomes afterward. `Departed` means absent from the current window, not deleted from retained history. Current-run distinct identifier counts are separate from all-run reserved counts; `Message_Id_Raw` preserves the original identifier behind the rollup's sequential `Message_Id`.

**Logs and help remain useful across runs.** Logs keep timestamps even with fixed output names. Interruptions are not attributed to Ctrl+C without evidence. Append examples use the full existing-file path without a conflicting output folder. Power BI, permission, retention and Fabric guidance covers the supported input and history options.

**Messages say what happened to the data.** The console and the log carry the same wording. A page that hits a temporary service error shows when its retry starts and when it recovers, and collection ends with one line stating whether every affected partition completed. Dashboard processing lists every group of input records (other activity, Security Copilot, Copilot records without a user prompt, service accounts, records with prompts, unreadable records) and confirms they add up to the input. Combining rows into dashboard rows, skipping repeat copies of the same audit record, and adding Users rows for people missing from the Entra export are described as such, not as loss. Multi-dashboard runs name the dashboard folders that receive the Agent 365 file. Warnings remain for anything actually missing. Upload lines show sizes in bytes, KB, MB or GB, so a small file never reads as 0.00 MB, and a SharePoint upload that resent chunks says how many, why, and that the complete file was received. The closing summary names the full build, including the prerelease label and date, matching the opening banner.

</details>

<a id="retired"></a>

<details>
<summary><strong>Retired options</strong></summary>

**Windows PowerShell 5.1 is no longer supported.** Use PowerShell 7.0 or later for every mode, including `-UseEOM`.

`-ExplodeArrays`, `-ExplodeDeep`, `-ExportWorkbook` and `-RAWInputCSV` are refused before sign-in with a message naming the switch. Remove them from scheduled jobs and saved commands. Excel workbook output is removed; CSV and Fabric output remain supported. Supplied-input processing with `-PurviewInputFile` is a separate feature and remains supported.

</details>

<a id="good-to-know"></a>

## Known limits

- **Publication-only recovery is deliberately narrow:** only supported retained schema 2.1.0 initial AIO + ValueLens `-RollupPlusRaw` contracts with raw exports, complete directory/Agent snapshots, retained UserHistory On inputs, managed identity and an original GUID OneLake Tables destination are admitted. PAX generates its strict plan automatically, or accepts an optional advanced manifest; it is not general recovery for append, watermark, protected inputs or arbitrary older builds. Where the supported legacy caller omitted the UserHistory setting from its saved parameters, automatic planning selects that known compatibility policy only with complete retained temporal proofs; the checkpoint is never rewritten to force compatibility.
- **Conversion and working-space bounds:** logical CSV records are limited to 128 MiB. Publication-only recovery supports unpartitioned targets and refuses existing Parquet row groups larger than 256 MiB uncompressed before publication. Its scratch budget and free-space reserve are each at least 64 MiB, and each operation has an explicit 60-3600 second limit. Full source and destination proofs remain necessary; avoiding CSV copies does not eliminate Parquet, original-snapshot, SQLite or other proof working space, or guarantee fit on a particular disk.
- **Live qualification boundary:** bounded synthetic testing against OneLake covered eight-table publication, unchanged-version accepted replay, interrupted publication, verified restoration and saved recovery to acceptance. Live storage authentication used an existing delegated sign-in. Automatic no-manifest planning, identity discovery, capacity retry and proof reuse have local coverage, including real local Delta publication/replay; the automatic planner and managed-identity startup have not been qualified live together. This does not establish customer-scale runtime, universal network/crash behavior or production readiness.
- **Windows temporary paths:** an overlong owned temporary path can stall Arrow initialization on Windows. Local native recovery qualification used short retained-run paths; it does not establish support for arbitrary long temporary paths. Preserve retained inputs in place and report an explicit path/runtime refusal rather than moving files or weakening guards to force recovery.
- **Runtime support:** PowerShell 7.0 or later is required for all modes. Windows PowerShell 5.1 is unsupported; `-UseEOM` is retained under PowerShell 7.
- **Graph SDK compatibility:** PAX uses installed Microsoft Graph PowerShell v2.25.0–v2.40.0, or installs v2.40.0 for the current user if none is available. It does not automatically upgrade the SDK; newer installations remain but are not selected. An incompatible version already loaded requires a fresh PowerShell window.
- **Private recovery qualification:** the bounded live publication-only coverage above does not qualify de-identified private recovery, every Fabric mirror/restore path or positive Unix owner-only recovery. Preserve owner-only recovery material; a fail-closed permission refusal is not successful recovery.
- **Older checkpoint recovery:** cross-build recovery outside the explicitly admitted publication-only contracts has not been established. Preserve the checkpoint and its actual matching artifacts; never edit version, fingerprint, count or completion fields to force compatibility. Local download-admission coverage does not establish universal crash, concurrent-writer, network-filesystem or macOS recovery guarantees.
- **History is not reconstructed license truth:** Unknown users/activity remain in outputs, but current dashboard licensed/unlicensed populations may exclude them. The current AI-in-One rollup template expects one row per normalized person, not multi-state history; `-UserHistory On` does not upgrade that template.
- **Long raw audit JSON:** The Lakehouse SQL endpoint exposes Delta strings as `varchar(8000)`, which can truncate long `AuditData` when read through SQL. Complete JSON remains in Delta for Spark or direct Delta readers. Processed AIO tables do not contain raw `AuditData`; this preview does not change the SQL limit.
- **Catalog limits:** Creator, channel, environment, risk and other fields are not universally available. An empty sharing collection differs from unavailable data. A complete catalog listing does not establish active-agent status or a match for every audit Agent ID.

---

<a id="report-a-problem"></a>

## Found a problem? Something look wrong?

Please reach out — feedback is the point of a preview.

**[pax@microsoft.com](mailto:pax@microsoft.com)**

Include the command, the run log produced beside your output, and a short description of expected versus actual behavior. Please don't send audit data or user details.

---

<div align="center">

<sub>Preview build · Not a production release · Validate results before relying on them</sub>

<sub>Questions or problems → [pax@microsoft.com](mailto:pax@microsoft.com)</sub>

</div>
