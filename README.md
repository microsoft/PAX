<div align="center">

# PAX — Prerelease Preview

**Portable Audit eXporter (PAX) · Purview Audit Log Processor**

**v2.0.0 prerelease 20261004-09**

**Preview build — not a production release.**

[Download](#download) · [Before you run it](#before-you-run-it) · [Report a problem](#report-a-problem) · [What's changed](#whats-changed) · [Good to know](#good-to-know)

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

### [PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20261004-09.ps1](./PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20261004-09.ps1)

<sub>The file name opens the script in this branch. Use **Download raw file** to save it, or download the script from the matching [GitHub prerelease asset](https://github.com/microsoft/PAX/releases/download/purview-v2.0.0-prerelease-20261004-09/PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20261004-09.ps1). See the [prerelease page](https://github.com/microsoft/PAX/releases/tag/purview-v2.0.0-prerelease-20261004-09) for release details.</sub>

<sub>**SHA256:** `FD1FBB5C82627ADFD5F52D81FD3D8FD80B12BA0CEF4200EF82C7F0C36FCB98A4`</sub>

<sub>Verify your download with `Get-FileHash .\PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20261004-09.ps1 -Algorithm SHA256`</sub>

</td>
</tr>
</table>

Earlier preview builds are kept in [`prerelease_archive`](./prerelease_archive) for reference only.

---

<a id="before-you-run-it"></a>

## Please read before you run it

> [!IMPORTANT]
> **This is a preview, not a production-qualified build.** Validation includes targeted synthetic coverage and limited live AIO/Fabric run reviews, not complete end-to-end qualification across supported modes and destinations.

- **Check the results against your own tenant** before relying on them, sharing them, or publishing them to a dashboard. Confirm row counts, dates and included people.
- **Keep a copy of anything important.** Use a new output folder or destination rather than the files your reporting depends on.
- **Preserve recovery material.** Resume needs the checkpoint and its matching saved data. Missing, changed, contradictory or unverifiable completion evidence stops the run; do not edit a checkpoint to make it pass.
- **Recovery is not de-identified output.** With `-Deidentify`, preserve the checkpoint's owner-only local recovery directory alongside its saved data. Recovery stops if private permissions cannot be enforced. Fabric's existing resume mirror contains identified recovery data too; local private permissions do not establish remote access protection.
- **Treat pending restoration as potentially changed data.** A failure after replacement begins can leave a partially updated destination. Preserve the checkpoint, candidates, originals and recovery markers. An unrelated fresh run does not depend on finishing an older checkpoint; an older resume cannot overwrite newer unrelated destination changes.
- **Choose append to retain activity history.** A non-append Delta run publishes the requested snapshot, not a union with the existing table, and a valid snapshot may contain fewer rows.
- **Keep preview outputs separate from production.** Behavior and file names may change before release. Do not assume checkpoints or histories can be opened by another version.
- **Preview builds are tagged as pre-release, never as the latest release**, and are not linked from the main README.

---

<a id="report-a-problem"></a>

## Found a problem? Something look wrong?

Please reach out — feedback is the point of a preview.

**[pax@microsoft.com](mailto:pax@microsoft.com)**

Include the command, the run log produced beside your output, and a short description of expected versus actual behavior. Please don't send audit data or user details.

---

<a id="whats-changed"></a>

## What's changed since v1.11.15

These are the net changes from the current production release to this **v2.0.0 preview**, grouped by capability rather than by preview build.

<details open>
<summary><strong>At a glance</strong></summary>

One collection can produce multiple dashboard data sets, including the new Cowork Adoption inputs. `-Watermark` adds incremental catch-up for CSV histories, and `-UserHistory` retains observed licensing states. The preview also expands Agent 365 metadata, accelerates large processing jobs, protects retained outputs under de-identification, and verifies collection, append and publication results.

</details>

| | |
|---|---|
| [New capabilities](#new-capabilities) | [Speed and visible progress](#speed) |
| [Protecting existing data](#protection) | [Collection, resume and run results](#collection) |
| [SharePoint, OneDrive and Fabric destinations](#destinations) | [Agent 365 catalog](#agents) |
| [Classification and reporting accuracy](#accuracy) | [Messages, logs and guidance](#messages) |
| [Retired options](#retired) | [Good to know](#good-to-know) |

<a id="new-capabilities"></a>

### New capabilities

**Choose the dashboard before processing.** A fresh `-Rollup` or `-RollupPlusRaw` run without `-Dashboard` asks you to choose **AIO, ValueLens, M365, CoworkAdoption**, or **raw exports only**, in that order. Enter selects AIO; `-Force` selects AIO without prompting. Raw-only selection disables both rollup switches. Explicit dashboard selections, raw-only and directory/Agent-only runs are unchanged; Resume keeps its checkpoint's dashboard and output mode, including CoworkAdoption. Existing compatibility checks still apply: use `-Dashboard M365` with `-IncludeM365Usage` rollups, and supplied audit files still require rollup processing. Unattended rollup runs need an explicit dashboard or `-Force`.

**Multiple dashboards from one collection.** `-Dashboard AIO,M365,ValueLens,CoworkAdoption` generates the requested data sets from one collection. Including M365 includes its usage activities. Each dashboard's files go beneath its own folder on Local, SharePoint and Fabric Files; a single-dashboard run keeps the supplied folder. Tables/Delta uses distinct dashboard-prefixed tables, with shared raw and Agent 365 outputs written once. Each required member must verify before the set is accepted. This is not an atomic cross-table or cross-service transaction.

**Append to multiple dashboard histories.** The existing `-AppendFile`, `-AppendUserInfo` and `-AppendAgent365Info` selectors resolve the corresponding histories for each dashboard. AIO and ValueLens retain their own user, message and conversation keys. Missing, incomplete or ambiguous histories are refused rather than guessed. If an added dashboard lacks history, PAX stops before collection and provides a separate backfill command. Resume cannot change dashboard membership; start a new combined run after preparing compatible histories.

**Cowork Adoption inputs.** `-Dashboard CoworkAdoption` enables rollup and user collection and produces a Purview CSV and a Users CSV, alone or with other dashboards. Supply each file's full path to its matching template input. The Users input uses the collected PAX Copilot license evidence. Scheduled counts describe prompt setup, not independently observed executions; unavailable record-level credits stay blank. These files are not an admin-center usage import or a billing report. See [Good to know](#good-to-know) for qualification limits.

**Incremental catch-up.** `-Watermark` collects missing whole UTC days into a Local, SharePoint or Fabric Files CSV `-AppendFile` target; it does not support Tables/Delta. Supply `-WatermarkStartDate` only for the first run, and do not supply manual start/end dates. The marker advances only after every required output publishes and verifies. A current target finishes without service calls. Resume restores the saved window: do not repeat watermark switches. Supplied audit files, `-UseEOM`, directory-only and Agent-only runs do not support watermark mode.

**Observed user history.** `-UserHistory On` records effective-dated licensing observations for AIO and ValueLens. It retains stable state keys and audit-only Unknown rows without adding duplicate states on unchanged appends. `EffectiveDate` identifies the collection window in which a state was first recorded, not a proven license-assignment date. History is **Off by default**; neither mode reconstructs unobserved past licenses. M365 usage rollup refuses history mode. A compatible history-aware model is required; see [Good to know](#good-to-know).

**Full Microsoft 365 historical collection.** A single command queues the entire requested usage range rather than capping it part-way through. Concurrency limits active work, not the total range.

> **Upgrading an in-progress Microsoft 365 usage collection:** finish it on the version that started it, or start a fresh collection. The new partition layout can cause an old resume to stop or re-collect the requested range. Completed collections and ongoing append histories are unaffected.

<a id="speed"></a>

### Speed and visible progress

**Memory-aware rollup.** Jobs that fit the estimated budget use the in-memory Copilot rollup; larger jobs use disk-backed processing with the same output contract. The log identifies the path and budget. This bounds working buffers, not all process memory.

**Accelerated directory and append processing.** Directory preparation, retained-key matching, seed creation and append reconciliation use scalable processing without sampling history. Unicode identities, quoted delimiters, quotes, embedded newlines and large CSV fields remain supported on the accelerated path, using the executing host's comparison rules. Invalid data fails explicitly; dedicated compatibility paths are identified in the log.

**Faster compatibility sorting.** Shared bounded sorting, CSV serialization and composite-key construction reuse compiled primitives while preserving host comparison rules, stable ordering and output values. Retained histories still require complete scans and merges; this is not a customer-runtime or memory-ceiling guarantee.

**Prerequisites and progress before expensive work.** Accelerated append requires Python 3.10+ and SQLite 3.24+, checked before collection. Allow working-disk space comfortably larger than the histories plus new output. Narrowing audit dates does not avoid reading retained history for key continuity. Long stages report aggregate progress and integrity counts without printing audit rows or personal identifiers; sign-in validity is checked again after directory preparation.

<a id="protection"></a>

### Protecting existing data

**Verified publication and independent recovery.** Candidates are checked before replacement and read back afterward. A refusal before publication leaves the affected targets unchanged. A later failure triggers restoration where possible; an unverified restoration is reported as potentially modified data, with recovery material retained and no affected watermark advance. Failed sets are not retried by the final upload sweep. Logs, raw recovery files or successfully generated local files are not proof of a completed remote dataset.

**Stable identities and complete Users references.** First-run and append output includes minimal Users rows for identities found only in audit activity, including multi-dashboard and history paths. Retained user, message and conversation mappings remain stable. A refused merge reports conflicting keys, people and missing or mismatched references and writes a complete private local conflict list. Resolve conflicts from a known-clean target or validated re-baseline, not a manual blind merge.

**Missing licensing stays Unknown.** Directory collection includes the license assignments needed to retain licensed accounts even when name fields are empty. AIO and ValueLens use `Unknown` for missing or unrecognized evidence in both Users and activity; explicit positive/negative evidence and license-independent agent and Cowork classifications remain distinct. Unknown is not Unlicensed.

**No automatic historical reclassification.** An overlapping append whose stored and new license classifications conflict is refused before replacing either Fact/Users output. Preserve the dataset and reconstruct affected dates separately from original evidence before reviewing a replacement. Disjoint runs and unrelated checkpoints do not require that recovery.

**Microsoft 365 append retains daily history.** Rollup, UserStats, SessionCohort and SessionStats are prepared and checked together. SessionStats is found beside its Rollup anchor, including first-run timestamped companions and remote histories. Re-collected days with new rows replace the corresponding stored days instead of doubling them; days with no new rows retain history. Percentiles use the full retained SessionStats history. A missing required companion stops preparation before replacement. Empty results retain headers and never replace existing history.

**De-identification covers retained raw outputs.** `-Deidentify` protects designated identity fields in retained Purview and Entra Users files as well as dashboard outputs, including `-RollupPlusRaw`. Protected Users CSVs add `PAX_DeidentifyPolicy` and `PAX_DeidentifyDigest` to verify append compatibility. The digest checks logical content consistency, not authenticity against someone replacing both data and digest; it does not make all remaining data anonymous. Older protected histories without valid metadata require regeneration from original identified sources, not manual rehashing.

<a id="collection"></a>

### Collection, resume and run results

**Source-preserving recovery.** Dictionary and object responses retain source identities and audit payloads. All requested operations, record types and service filters survive retries and recovery, including intentionally omitted M365 filters. Snapshots belong to their complete query contract, not just a partition number. Resume and export validate their exact filename, digest and record count.

**Completion is reconciled with saved data.** Collection checks service counts, completed-partition counts and final export counts, accounting for duplicates and date trimming. Incomplete retrieval, unusable records or failed data/checkpoint saves cannot become successful empty results or later false completions. Genuine zero results are valid and still produce requested independent outputs. Missing activity detail is counted separately; a faster-reader rejection is tried with the standard reader before an unreadable-record refusal withholds affected outputs and records the gap.

**Checkpoint-scoped Resume.** Resume follows only the selected checkpoint and its saved publication state; old shared markers do not block unrelated work. Integrity, ownership and concurrent-change checks still apply. Fabric verifies the local checkpoint before backing it up, supports hidden checkpoint names, and retries page writes briefly when backup holds a file. Lock errors report the actual cause and path; foreign-host lock age uses UTC.

**Recovery survives downstream failures.** Current-run checkpoints and required recovery data are retained until processing, required publication and final uploads succeed. CSV finalization uses staged, no-overwrite publication and reports copy or log-finalization failures. With `-Deidentify`, a later finalization failure withdraws the newly created identified CSV into private recovery. Successful Resume cleans the verified selected checkpoint even if renamed; relative checkpoint and lock paths follow the PowerShell location. Supplied inputs and unrelated checkpoints remain protected.

**Accurate monitoring and failure results.** Reused queries are distinguished from newly created ones. Terminal partitions are reconciled with their specific jobs without stopping healthy work merely for taking a long time. Invalid Resume arguments, destination preflight refusals and post-processing failures return nonzero results. An ordinary non-AISID resume is not diverted by empty AISID metadata.

**Scope and dates are explicit.** `pwsh -File` accepts comma-separated `-UserIds "a@contoso.com,b@contoso.com"` and quoted `-GroupNames "Engineering Managers","Product Leads"`. Empty or unresolved effective audit scopes stop rather than widening to the tenant. An intentionally empty directory scope produces a header-only Users file. Date-only live windows use inclusive UTC midnight through exclusive UTC midnight; an empty or reversed range is refused before sign-in.

**Supplied inputs avoid unnecessary audit sign-in.** A fully local run with supplied audit and complete Users files does not contact services. Fabric output still authenticates to Fabric, but needs no audit sign-in when no live directory or Agent collection is required. Resume retains supplied input references and accepts `GRAPH_CLIENT_SECRET` for App Registration. `-StartDate` and `-EndDate` do not filter a supplied audit CSV.

<a id="destinations"></a>

### SharePoint, OneDrive and Fabric destinations

**Predictable filenames and tables.** Generated dashboard-owned filenames begin with `AIO_`, `ValueLens_`, `M365_` or `CoworkAdoption_`; raw inputs, Agent 365 files and logs remain unprefixed. Explicit filenames and append targets keep their names. Entra raw and processed outputs stay distinct, as do all four M365 companions, including when a requested name already ends in `_Rollup`. Supplied-input Facts are published under their produced name even if they carry an older timestamp. Update automation that relies on generated names.

**Stable Fabric dataset names.** Table names omit run timestamps: for example `AIO_CopilotInteractions`, `AIO_Users`, `ValueLens_Users` and `M365_Rollup`. Shared names are `CopilotInteractions_Raw`, `Entra_Users_Raw`, `Audit_Raw`, `Agent365` and `Agent365_Status`; M365's dashboard Users table is separately `M365_Entra_Users_Raw`. Old tables are not renamed or deleted. Update Power BI connections and notebooks.

**Fabric validation and readback.** Lakehouse names, IDs, folders with spaces and physical schema placement are resolved before collection. Required Files/Tables roots and output-specific destinations are checked; missing or ambiguous lakehouses and Warehouse items are refused. Valid nonempty Users and non-append snapshots may shrink; activity-history append, schema and reference safeguards remain. Readback compares full data by column name after verifying names, types and nullability, even if physical column order differs. Failures identify the table, intent, counts or failed comparison.

**Fabric authentication and dependencies.** Az.Accounts runs in a separate process to avoid Graph authentication-library conflicts while preserving supported Azure, managed-identity and app-registration sign-ins. Delta checks both `pyarrow` and `deltalake`; Windows on ARM uses x64 Python, with current-user installation when allowed and no PATH/default-Python change. Failed Delta delivery may retain a recovery CSV in Files, but is not successful table publication.

**Reliable paths and transfers.** SharePoint and OneDrive resolve the correct library, including folders with spaces. CSV sharing links are resolved to the actual item and non-CSV items are refused; logs omit sharing tokens. Linux local paths use the platform separator. Remote runs have separate working folders even when started together. Large SharePoint uploads recover from the service-confirmed offset within network tolerance, including a bounded sign-in renewal when session creation is unauthorized; existing permissions still apply.

**Expected responses are not failures.** Optional missing recovery markers and OneLake directories (`GET 404` with exact `PathNotFound`), and already-existing directories during idempotent creation (`PUT directory 409` with exact `PathAlreadyExists`), do not print misleading errors. Required paths, access refusals and immutable-file conflicts remain errors. Local watermark replacement retries brief file locks and keeps the previous marker if saving fails.

<a id="agents"></a>

### Agent 365 catalog

**Expanded, template-compatible metadata.** The catalog has 44 columns, with existing names/order retained and 16 ValueLens fields added after `Uploaded files`; the retrieval-status file keeps its four-column contract. Descriptions use Graph's long/short descriptions, and `Created in` uses its platform. Supported nested definitions supply instructions, actions, unique bot IDs and declared capabilities. Manifest JSON is data, never executed, and referenced URLs are not fetched. Capabilities describe declarations, not verified permissions or a discovered file inventory.

**Availability, sharing and status mean different things.** `Availability` contains Graph's `availableTo` access policy. `Groups shared` and `Users shared` contain explicitly shared resource IDs as compact JSON, not allowed/acquired audiences or expanded membership. `Status` is `Blocked` or `Not blocked`, not a deployment or activity assertion. Zero, false, empty, null and unavailable values are distinguished rather than guessed.

**Usage is fresh and has its own window.** Every run requests package details in bounded parallel batches, preserving listing order and using the selected Graph module version. Cached package modification dates do not establish usage freshness; detail reuse is disabled, so repeat runs incur fresh requests. `Active Users` and `Total sessions` cover the last 30 days at retrieval, not the audit date range. `Exception rate` retains the service value without an invented percentage; `Last Activity Date` uses its last-used timestamp.

**Agent identities are not interchangeable.** `Entra Agent ID` uses the true `agentIdentityId`, not an application or bot ID. Catalog titles and activity titles use a common bare form; supported compound IDs recognize `P_` or `T_` title segments before a trailing GUID. Ambiguous or malformed identities remain unresolved, and raw Agent IDs are retained. Creator/developer values require explicit evidence, not publisher, display-name or application-owner guesses.

**Retrieval and field coverage are separate.** The status file tracks listing, detail retrieval and row construction; logs report population and source states for every column. A complete listing can publish listing-only rows when details fail, with a gaps result. Incomplete listings or failed row construction withhold the canonical catalog and retain recovery material. Append retains target-only historical rows and supports compatible legacy identifiers. GA Graph reads are preferred with a compatibility fallback; structured throttling retries honor network tolerance and service waits, while genuine permission failures remain explicit.

**Agent privacy protection.** Under `-Deidentify`, names and supported personal creator/sharing IDs are pseudonymized; free-form descriptions, instructions, actions and resource details are withheld. Application join IDs remain usable. Raw detail caches are not written, and logs distinguish privacy withholding from absent, malformed or unretrieved data.

<a id="accuracy"></a>

### Classification and reporting accuracy

**Security Copilot records are trimmed during dashboard preprocessing.** AIO, ValueLens, M365 and Cowork Adoption skip explicit Security Copilot product activity before expansion, activity-key allocation and aggregation. The match includes the bare `SecurityCopilot` host, its `SecurityCopilot-` family, explicit product names and the documented `Copilot.Security.SecurityCopilot` application identity, case-insensitively. That application identity does not depend on a SecurityCopilot-prefixed host. It does not use user names, "General Chat", license status or prompt text. Retained raw exports and the existing directory/licensing population are unchanged.

**No new seed run or append requirement.** Existing histories, seed maps, append, publication and Resume keep their established behavior. There are no new policy receipts, output-folder restrictions or migration gates. The filter applies to raw records processed by this build; it does not retroactively rewrite previously stored historical rows or aggregates.

**Categories follow observed evidence.** A referenced file or app does not alone prove creation, review or summarization. Specific resource families are not displaced by generic links; citations are not automatically web searches, Loop is recognized, and unknown resource types remain visible. A message touching several resources still counts once in overall interaction totals; category counts can overlap.

**Dashboard labels remain compatible.** Published labels, including Email Summarising, Meeting Prep and Presentation Summarising, stay unchanged. Classification improves modeled Human Equivalent Hours for templates consuming producer values; templates calculating their own values are unaffected. These remain assumptions, not measured time savings or a guaranteed tenant uplift. Append preserves existing classifications; use original inputs to rebuild a consistently classified history.

<a id="messages"></a>

### Messages, logs and guidance

**Failures explain the next step.** Audit refusal logs include the returned error, request identifier, service diagnostics and policy challenge. Permanent permission/policy refusals stop promptly; transient failures retain retry behavior. Remote read errors identify the requested destination. SharePoint guidance distinguishes delegated site access, tenant-wide app-only `Sites.ReadWrite.All`, and app-only `Sites.Selected` with a write grant.

**Generation is not publication.** Final messages name accepted physical Delta destinations or identify local processing copies, rather than inventing remote CSVs. Append targets are labeled before work and outcomes afterward. `Departed` means absent from the current window, not deleted from retained history. Current-run distinct identifier counts are separate from all-run reserved counts; `Message_Id_Raw` preserves the original identifier behind the rollup's sequential `Message_Id`.

**Logs and help remain useful across runs.** Logs keep timestamps even with fixed output names. Interruptions are not attributed to Ctrl+C without evidence. Append examples use the full existing-file path without a conflicting output folder. Power BI, permission, retention and Fabric guidance covers the supported input and history options.

<a id="retired"></a>

### Retired options

`-ExplodeArrays`, `-ExplodeDeep`, `-ExportWorkbook` and `-RAWInputCSV` are refused before sign-in with a message naming the switch. Remove them from scheduled jobs and saved commands. Excel workbook output is removed; CSV and Fabric output remain supported. Supplied-input processing with `-PurviewInputFile` is a separate feature and remains supported.

<a id="good-to-know"></a>

### Good to know

- **Graph SDK compatibility:** PAX uses installed Microsoft Graph PowerShell v2.25.0–v2.40.0, or installs v2.40.0 for the current user if none is available. It does not automatically upgrade the SDK; newer installations remain but are not selected. An incompatible version already loaded requires a fresh PowerShell window.
- **Cowork Adoption qualification:** Local output is available to try. Remaining end-to-end coverage gaps concern PAX delivery of CoworkAdoption outputs to SharePoint/OneDrive or Fabric, including existing-history append, de-identified Users, interrupted publication/Resume and dashboard combinations. These are qualification gaps, not newly confirmed defects or restrictions introduced by Security Copilot trimming.
- **Private recovery qualification:** Windows synthetic coverage includes Fabric mirror/restore using mocked transport. Live Fabric recovery and positive Unix owner-only recovery remain unqualified; a fail-closed permission refusal is not successful recovery.
- **History is not reconstructed license truth:** Unknown users/activity remain in outputs, but current dashboard licensed/unlicensed populations may exclude them. The current AI-in-One rollup template expects one row per normalized person, not multi-state history; `-UserHistory On` does not upgrade that template.
- **Long raw audit JSON:** The Lakehouse SQL endpoint exposes Delta strings as `varchar(8000)`, which can truncate long `AuditData` when read through SQL. Complete JSON remains in Delta for Spark or direct Delta readers. Processed AIO tables do not contain raw `AuditData`; this preview does not change the SQL limit.
- **Catalog limits:** Creator, channel, environment, risk and other fields are not universally available. An empty sharing collection differs from unavailable data. A complete catalog listing does not establish active-agent status or a match for every audit Agent ID.

---

<div align="center">

<sub>Preview build · Not a production release · Validate results before relying on them</sub>

<sub>Questions or problems → [pax@microsoft.com](mailto:pax@microsoft.com)</sub>

</div>
