<div align="center">

# PAX — Prerelease Preview

**Portable Audit eXporter (PAX) · Purview Audit Log Processor**

**Current preview build: v2.0.0 prerelease 20260924-07**

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

### 📦 [PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20260924-07.ps1](https://github.com/microsoft/PAX/releases/download/purview-v2.0.0-prerelease-20260924-07/PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20260924-07.ps1)

<sub>⬇️ Click the file name above to download this exact build.</sub>

<sub>**SHA256:** `22FDA35BC4C1037549DF441BFE2CDDDA5D6BDCC53406B890FB97D2DA0A2E67F1`</sub>

<sub>Verify your download with `Get-FileHash .\PAX_Purview_Audit_Log_Processor_v2.0.0-prerelease-20260924-07.ps1 -Algorithm SHA256`</sub>

</td>
</tr>
</table>

Earlier preview builds are kept in [`prerelease_archive`](https://github.com/microsoft/PAX/tree/prerelease/prerelease_archive) for reference only. Always use the build above.

---

<a id="before-you-run-it"></a>

## Please read before you run it

> [!IMPORTANT]
> **This build has not completed full customer testing.** It has been tested internally and against real tenant data, but it has not been through the complete validation that a released version receives.

- **Check the results against your own tenant** before you rely on them, share them, or publish them to a dashboard. Confirm the row counts, the date range, and the people included look the way you expect.
- **Keep a copy of anything important.** Point preview runs at a new output folder or a new destination rather than at the files your reporting already depends on.
- **Expect the possibility of change.** Behavior, messages, and file names in a preview build can still change before the version is released.
- **Preview builds are tagged as a pre-release, never as the latest release**, and are not linked from the main README, so bookmark this branch if you want to find your way back to it.
- **Use the released version for production reporting.** If a preview build causes you any trouble, switching back to the released version is always a safe fallback.

---

<a id="report-a-problem"></a>

## Found a problem? Something look wrong?

Please reach out — that is the entire point of a preview, and there is no such thing as too small a report.

**📧 [pax@microsoft.com](mailto:pax@microsoft.com)**

It helps a great deal if you can include the command you ran, the run log file produced beside your output, and a short description of what you expected versus what you saw. Please don't send audit data or user details.

---

<a id="whats-changed"></a>

## What's changed since the current release

This preview is the **v2.0.0** line. Everything below is new or changed compared with the current released version. Items marked **🆕** were added to this page with this build.

| | |
|---|---|
| ✨ [New capabilities](#new-capabilities) | ⚡ [Speed and visible progress](#speed) |
| 🛡️ [Protecting the data you already have](#protection) | 🔄 [Collection, resume and run results](#collection) |
| 🗄️ [SharePoint, OneDrive and Fabric destinations](#destinations) | 🤖 [Agent 365 catalog](#agents) |
| 📊 [Classification and reporting accuracy](#accuracy) | 💬 [Messages, logs and guidance](#messages) |
| ⛔ [Retired options](#retired) | ⚠️ [Good to know in this build](#good-to-know) |

<a id="new-capabilities"></a>

### ✨ New capabilities

**🆕 📚 Multi-dashboard runs can now add to the histories you already have.** A run such as `-Dashboard AIO,M365,ValueLens` accepts the same `-AppendFile`, `-AppendUserInfo` and `-AppendAgent365Info` switches as a single-dashboard run, and each one finds the matching history beneath each dashboard's folder. Each dashboard keeps its own user keys and message and conversation identifiers, so a person keeps the same key within each dashboard from run to run. The whole set is checked before anything is replaced; if any part fails, every original file is put back exactly as it was and the catch-up marker does not move. If one dashboard has no existing history while the others do, the run stops before collecting anything and prints the exact command for backfilling that dashboard separately.

**🆕 🕶️ De-identification now covers everything a run keeps.** `-Deidentify` now also protects the raw Purview and Entra Users files a run retains, not only the dashboard outputs, including raw files kept by `-RollupPlusRaw`. Protected Users files carry two added columns, `PAX_DeidentifyPolicy` and `PAX_DeidentifyDigest`, so a later append can confirm that the history it is adding to was protected the same way. The digest is a consistency check that detects changed or stale content; it does not protect against someone deliberately replacing both the data and the digest. Behavior without `-Deidentify` is unchanged.

**📊 One command can now produce several dashboard data sets at once.** `-Dashboard` accepts more than one value, such as `-Dashboard AIO,M365,ValueLens`, so a single collection generates the data for every dashboard you ask for instead of requiring a separate collection for each. Each data set is written beneath its own folder, and the whole set publishes together or not at all — if one dashboard cannot be produced, nothing is published as complete, the collected data is kept for review, and the run reports failure.

**💧 Catch up on whatever you missed, without tracking dates by hand.** Point a run at a dataset you already have and PAX works out which whole UTC days are missing, then collects exactly those in a single run. Local, SharePoint, and Microsoft Fabric destinations are all supported. The marker only moves forward after every required output has published and been verified, so an interrupted or failed run simply collects the same window again next time rather than leaving a hole.

**🕒 License state is now recorded as it was at the time, not as it is today.** Turn on user history and each person's licensing state is written once with the date it applied from, and activity is attributed to the state that was actually in effect when it happened. Without this, historical activity is reported against today's license state, which makes adoption and trend reporting wrong for anyone whose license changed rather than simply incomplete. A state is stored once, so repeating a run adds nothing and a new row appears only when somebody's licensing genuinely changes.

**🗓️ A single command can now collect your full Microsoft 365 usage history.** Long historical ranges are no longer capped part-way through.

> ⚠️ **If a Microsoft 365 usage collection is currently in progress on an older build**, finish it there first. This build divides the requested range differently, so an in-flight collection will either stop and tell you so, or restart the range from the beginning. Nothing is corrupted or lost either way. Collections that have already finished, and ongoing appends to an existing dataset, are unaffected.

<a id="speed"></a>

### ⚡ Speed and visible progress

**🆕 🚀 Copilot rollup keeps its speed, and very large jobs use a memory-bounded path.** Before processing starts, PAX estimates how much memory the job needs. A job that fits uses the original in-memory rollup at its original speed; a job too large for memory switches to a disk-backed rollup designed to keep memory use in check. Both produce identical output, and the run log states which path was chosen and why. The rollup also now reports steady progress while it works instead of going quiet.

**🆕 🤖 Large agent catalogs finish sooner.** Package details are requested in groups rather than one at a time. Every listed package is still requested, and results keep the catalog's own order.

**⚡ Large tenants and large existing datasets process dramatically faster.** Preparing a big user directory, matching people to the identifiers they were given on previous runs, and folding a new run into an existing dataset all now run through a much faster, disk-backed path. Steps that could previously take hours on a large existing dataset now typically complete in minutes. Where data is unusual, the run quietly falls back to the previous method rather than guessing.

**⏳ You can see what a long run is doing.** The slow steps now report steady progress while they work, roughly once a minute, instead of appearing to hang with nothing on screen.

<a id="protection"></a>

### 🛡️ Protecting the data you already have

**🆕 📦 A failed Microsoft 365 append leaves your previous files untouched.** All four Microsoft 365 files are prepared and checked in a separate working area before any of them is published. If any one cannot be prepared, the four files you already have stay exactly as they were and the run reports failure.

**🆕 🧮 Records with no activity detail no longer cost you your rollup.** Records that legitimately arrive with no activity detail are now counted separately rather than as errors, so a short run is no longer pushed over the error allowance and left without its rollup. A record the faster reader rejects is retried with the standard reader first. If a record genuinely cannot be read, the run stops without touching your existing data, uploads nothing, lists every unreadable record for review, and collects the same period again next time.

**🆕 🔎 A refused merge now says what disagreed, and nothing is sent anywhere.** When new data and existing data disagree about who is who, the run reports how many of each kind of disagreement it found and writes a complete local list of the conflicting entries. Nothing is uploaded, every destination file is left exactly as it was, and the guidance points you to restoring a known-good file rather than merging by hand.

**🆕 💾 Local catch-up progress saves reliably in OneDrive-synced folders.** The catch-up marker is now saved in a single step with a short retry, so a sync client, search indexer or antivirus scan briefly holding the file no longer makes the save fail. If the file stays locked, the previous marker is kept and the same window is collected again next time.

**🆕 🧷 Resume protection on Fabric stops rather than silently going without.** When resume information is kept in Fabric, the local checkpoint is verified first. If it is missing or unusable, the run stops and says why instead of carrying on with no recovery point.

**🛡️ Stronger protection for the data you already have.** Results are confirmed complete *before* anything is merged into your existing files or uploaded. If any part of a run can't be confirmed, the run stops, says why, leaves your existing files exactly as they were, publishes nothing partial, and doesn't record the period as collected — so you can simply run it again. A run that finds no activity still produces the other output you asked for. On a first run, everyone appearing in the activity data is guaranteed a matching user row.

**➕ Folding a run into an existing dataset publishes the combined result.** When a run is added to a dataset you already have, the merged result is written out and the rows you already had are carried through it. If the combined result cannot be published, the run reports that plainly instead of finishing quietly, and the dataset you already had is left exactly as it was.

<a id="collection"></a>

### 🔄 Collection, resume and run results

**🆕 🔁 Resume messages say which queries were reused.** Only queries actually carried over from a saved run are labeled as resumed; queries created fresh in the current run are no longer described that way.

**🆕 🔒 Checkpoint lock messages are accurate.** A lock that could not be taken now reports the real error and the lock location instead of guessing that another run got there first, and a lock written on a computer in a different time zone is aged correctly.

**🧾 When access is refused, the log now says why.** If Microsoft 365 refuses an audit request, PAX writes down the reason it was given rather than just noting that the request failed. That includes the error code and message returned by the service, the Microsoft request identifier for that exact call, the service diagnostic detail, and any sign-in policy challenge attached to the response. The full response and every response header are recorded as well, so nothing is left out. If you need to take the problem to your IT or security team, or to Microsoft support, the log already contains the details they will ask for.

**🧩 Refusal details are no longer lost, so a genuine access problem is reported instead of retried.** On PowerShell 7 the details Microsoft returns with a refused audit request were being discarded before they could be read. Because those details were missing, a refusal caused by permissions or by a sign-in policy looked the same as a passing glitch, so the run kept retrying it and eventually gave up without saying what happened. Those runs could take hours and still finish with nothing to act on. PAX now reads the response correctly, so a real access problem is recognized on the first attempt and the run stops promptly with the reason.

**🔍 A collection that comes up short says so instead of reporting success.** Each part of a collection is now checked against the number of records the service said it would return. If retrieval ends early, the run reports a gap and returns a failure result. Previously a short retrieval could be accepted as complete, and the missing records were never mentioned.

**▶️ Resuming an interrupted collection works again.** An ordinary resume is no longer stopped by an unrelated internal marker that was being written into every saved progress file. Resumes that were failing immediately now continue normally.

**⏱️ A run that has finished its work now actually ends.** Monitoring reconciles the state of each part of the collection against the jobs doing it, so a completed collection no longer waits indefinitely on a job that will never report back. Genuinely long work is never cut short, and there is still no time limit of any kind.

**👥 Multiple group names work with the existing `pwsh -File` command.** Supply each name in quotes, for example `-GroupNames "Engineering Managers","Product Leads"`. Names containing spaces are kept together instead of being interpreted as unrelated output or authentication parameters, preventing misleading Agent 365 output-path errors. Single-group inputs and direct PowerShell arrays remain supported. Keep comma separators adjacent to the quoted names in legacy shells.

**💻 A fully local run stays local.** If you supply both your own audit file and your own users file, the run does not sign in and does not contact any service, because nothing about it needs to.

**🚦 A run that fails now reports failure.** A destination that cannot be reached before collection starts, and a post-processing step that does not finish, both return a failure result instead of exiting as though everything worked.

**📅 Clearer, more accurate reporting.** A date range that covers no time at all is refused immediately with a plain explanation, before any sign-in. Date-only ranges are treated consistently from midnight to midnight UTC, so the same command returns the same records wherever it is run. The end-of-run summary reports identifier counts more clearly.

<a id="destinations"></a>

### 🗄️ SharePoint, OneDrive and Fabric destinations

**🆕 🧮 Fabric runs keep every record they collect.** When output goes to Microsoft Fabric, a run could skip some records it had already collected while it was backing up its progress to the lakehouse, and still finish reporting success. Every collected record is now saved, and the finished export is checked against the number of records the service returned. If anything is missing, the run says exactly how many, marks the output as partial and reports completed with gaps instead of success.

**🆕 ☁️ OneDrive destinations resolve correctly.** A destination in a personal OneDrive now reaches the right document library, so an existing file there is found instead of being reported as missing. When a SharePoint or OneDrive read does fail, the run now reports the address it requested, the library and folder it resolved, and the file name it looked for.

**🆕 📁 Folder names with spaces work when catching up existing history.** When a multi-dashboard append checks each dashboard's existing history, a SharePoint, OneDrive or Fabric Files folder whose name contains a space, such as `Copilot Power BI`, is now found correctly instead of being reported as missing.

**🆕 🧱 Fabric tables install everything they need.** Writing Fabric Tables/Delta output now installs and checks both Python packages it depends on before converting anything, so a computer that was missing one no longer fails to write every table. If the packages still cannot be loaded, the data is written to the lakehouse `Files/` area for recovery and the run reports completed with gaps.

**🆕 🔗 SharePoint sharing links work as supplied audit files.** A SharePoint "Copy link" address passed to `-PurviewInputFile` is resolved to the actual item first, and only a genuine CSV file is accepted. Summaries in the log no longer show sharing tokens or other private parts of the address.

**🆕 🐧 Local output paths work on Linux.** A local output folder that needs a trailing separator now uses the correct one for the operating system. Windows behavior is unchanged.

**📤 Large uploads and busy services are handled far more gracefully.** A large SharePoint upload now resumes from where it stopped after a dropped connection instead of starting over, and can recover if your sign-in lapses while the transfer is being set up. The agent catalog now works its way through sustained service throttling rather than giving up, including throttling that arrives disguised as a different kind of error.

**🗄️ Microsoft Fabric destinations are checked up front.** Lakehouse destinations are now resolved and verified *before* collection begins, so a destination problem stops the run early instead of after all the work is done — including destinations whose names contain spaces. If a table still can't be written, the data is preserved to `Files/` for recovery and the run truthfully reports *completed with gaps* rather than implying success.

**📄 An output file name you specify is used exactly as you wrote it.** When you point an output at a particular file name rather than at a folder, the finished file is written under precisely that name, locally and at SharePoint or Fabric destinations. Previously a folder could be created carrying that name, with the output placed inside it. Runs that point at a folder rather than a specific file name are unaffected.

**✏️ The Entra Users file is written under the exact name you ask for.** When you point the Entra Users output at a specific file name, that is the name the finished file gets — locally and at SharePoint or Fabric destinations — instead of a variation that had to be renamed by hand afterwards. The raw directory extract is kept separately under its own name so the two never collide, and if the file can't be published the run says so and leaves whatever you already had untouched. Runs that point at a folder rather than a specific file name are unaffected.

<a id="agents"></a>

### 🤖 Agent 365 catalog

**🆕 🔗 Agent details now join to agent activity.** The activity output and the Agent 365 catalog now identify each agent the same way. Previously they used two different forms of the same identifier, so agent activity could not be matched to its catalog entry and details such as agent type could appear blank in dashboards. No columns, file names or dashboards change.

**🆕 🧾 The agent catalog is only replaced when it is complete, and append keeps older rows.** A catalog file is written only when every listed package was retrieved; otherwise the existing file stays as it was and what was retrieved is kept locally for recovery. When adding to an existing catalog, a row whose current identifier is blank is matched through its earlier identifier instead of being lost.

**🤖 A substantially expanded agent catalog.** The export now carries the Entra Agent ID and the additional contract columns without changing any existing column, explains why a fixed column is blank instead of leaving it unexplained, and works its way through sustained service throttling rather than giving up.

**🔐 Agent catalog reads use the generally available endpoint first**, falling back only when needed, and permission problems are now reported in plain language that tells you which permission is actually missing.

<a id="accuracy"></a>

### 📊 Classification and reporting accuracy

**🆕 🏷️ Behavior categories reflect what the audit record actually shows.** A referenced file or app on its own is no longer treated as proof that something was created, reviewed or summarized. A specific app is no longer overridden by a generic web link, citations no longer automatically count as web searching, Loop content is recognized, and unknown resource types stay visible instead of silently becoming General Chat. A message that touches several resources still counts once in interaction totals. Existing category names used by published dashboards are unchanged, so no dashboard needs to be edited or republished. Corrected classification can legitimately change category distributions compared with earlier runs; appending keeps existing history as it was.

**🆕 ⏱️ More precise modeled Human Equivalent Hours.** The classification correction also fixes an undercount in modeled Human Equivalent Hours. In synthetic examples, the 7 of 10 published ValueLens templates that use these values show roughly a 15–17% increase; the other 3 calculate their own values and are unaffected. Results depend on your data, and the modeled values remain assumptions rather than measured time savings.

**👤 Everyone in the activity data has a matching row in the people file.** In a multi-dashboard run, each dashboard's people file now carries a row for every person appearing in that dashboard's activity data, including identities that exist only in activity and never in your directory, such as service and agent accounts. Previously the directory listing was published on its own, so a small number of activity rows referred to people the accompanying file did not describe, and adding such a run to an existing data set would stop rather than publish the mismatch. Those runs now complete. Single-dashboard runs already behaved this way and are unchanged.

**🗂️ Each Microsoft 365 file keeps its own name in a multi-dashboard run.** The Microsoft 365 Rollup, UserStats, SessionCohort, and SessionStats outputs are each written under their own distinct file name. Previously a multi-dashboard run that included `M365` stopped with a duplicate destination error and published nothing at all. Single-dashboard runs were never affected.

<a id="messages"></a>

### 💬 Messages, logs and guidance

**🆕 🔑 SharePoint permission guidance matches how you sign in.** Guidance and error messages now distinguish delegated sign-in (the signed-in person needs access to the site), app-only access with tenant-wide `Sites.ReadWrite.All`, and app-only `Sites.Selected` with a write grant on the target site, instead of pointing every refusal at the tenant-wide permission.

**🆕 📘 Built-in help matches what the run accepts.** The append examples now show the supported form — the full path or address of the existing file, without a separate output folder — instead of a combination the run refuses. Header guidance also explains that `Message_Id` in rollup output is a sequential key and that `Message_Id_Raw` keeps the original identifier.

**🧾 Run logs are never overwritten.** A run log keeps its timestamp even when you specify a fixed output file name, so a later run cannot quietly replace the log of an earlier one.

**💬 Messages describe what actually happened.** An append target is described as a target rather than as a finished append, internal working files are no longer reported as your destination, the merge summary explains that "departed" means absent from the window you collected rather than removed from your data, an interruption is only attributed to you pressing Ctrl+C when that can genuinely be established, and the notice explaining that dates do not filter an audit file you supplied now appears.

**📖 Refreshed guidance** on Power BI connectivity, required permissions, and data retention. 🆕 The Fabric resources also now describe incremental catch-up, user history and the supplied-input switches.

<a id="retired"></a>

### ⛔ Retired options

**🆕 🗑️ Four switches have been retired.** `-ExplodeArrays`, `-ExplodeDeep`, `-ExportWorkbook` and `-RAWInputCSV` are no longer supported. Supplying any of them now stops the run before sign-in, with a message naming the switch, instead of being quietly ignored. Excel workbook output is removed; CSV and Fabric outputs are unaffected. Supplying your own audit file with `-PurviewInputFile` is a different feature and remains fully supported. If a scheduled job or saved command uses one of these switches, remove it before switching to this build.

<a id="good-to-know"></a>

### ⚠️ Good to know in this build

- **Multi-dashboard output to Microsoft Fabric goes to the lakehouse `Files/` area.** A multi-dashboard run pointed at Fabric Tables/Delta or at a bare lakehouse root stops before anything is collected. Single-dashboard runs continue to write Tables/Delta output.
- **Multi-dashboard append has a few boundaries.** A resumed append cannot change which dashboards are included, and incremental catch-up cannot start a newly added dashboard's history; the run gives you the backfill command instead.
- **Older de-identified Users histories need to be regenerated before appending.** A protected history created before this build does not carry the new verification columns, so appending to it is refused and the file is left unchanged. Regenerate it from the original identified source with a fresh run.
- **User history stays off unless you turn it on.** `-UserHistory` is off by default in this build.

---

<div align="center">

<sub>Preview build · Not a released version · Validate results before relying on them</sub>

<sub>Questions or problems → [pax@microsoft.com](mailto:pax@microsoft.com)</sub>

</div>
