<div align="center">

# PAX — Prerelease Preview

**Portable Audit eXporter (PAX) · Purview Audit Log Processor**

</div>

---

## What this branch is

This branch holds **early preview builds** of the PAX Purview Audit Log Processor — versions published ahead of
general release so that real-world feedback can shape them *before* they ship to everyone. Anyone who finds this
branch is welcome to use what's here; it simply isn't advertised alongside the released version.

A prerelease build is **not** the released product. The current released version always lives on the
[`release`](https://github.com/microsoft/PAX/tree/release) branch, and that is what you should use for anything
you depend on day to day.

---

## Please read before you run it

> [!IMPORTANT]
> **This build has not completed full customer testing.** It has been tested internally and against real tenant
> data, but it has not been through the complete validation that a released version receives.

- **Check the results against your own tenant** before you rely on them, share them, or publish them to a
  dashboard. Confirm the row counts, the date range, and the people included look the way you expect.
- **Keep a copy of anything important.** Point preview runs at a new output folder or a new destination rather
  than at the files your reporting already depends on.
- **Expect the possibility of change.** Behavior, messages, and file names in a preview build can still change
  before the version is released.
- **Preview builds are tagged as a pre-release, never as the latest release**, and are not linked from the main
  README, so bookmark this branch if you want to find your way back to it.
- **Use the released version for production reporting.** If a preview build causes you any trouble, switching
  back to the released version is always a safe fallback.

---

## Found a problem? Something look wrong?

Please reach out — that is the entire point of a preview, and there is no such thing as too small a report.

**📧 [bmiddendorf@microsoft.com](mailto:bmiddendorf@microsoft.com)**

It helps a great deal if you can include the command you ran, the run log file produced beside your output, and
a short description of what you expected versus what you saw. Please don't send audit data or user details.

---

## What's in this preview build

<table>
<tr>
<td>

### 📦 [PAX_Purview_Audit_Log_Processor_v1.11.16-prerelease-20260911a.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.11.16-prerelease-20260911a/PAX_Purview_Audit_Log_Processor_v1.11.16-prerelease-20260911a.ps1)

<sub>⬇️ Click the file name above to download this exact build.</sub>

<sub>**SHA256:** `99E87F4B6116D6EEA406314CB5EEE782865F4DB1107ACB5396B5CF81EE57655A`</sub>

<sub>Verify your download with `Get-FileHash .\PAX_Purview_Audit_Log_Processor_v1.11.16-prerelease-20260911a.ps1 -Algorithm SHA256`</sub>

---

### ✨ Features and enhancements

**🧾 When access is refused, the log now says why.** If Microsoft 365 refuses an audit request, PAX writes down
the reason it was given rather than just noting that the request failed. That includes the error code and
message returned by the service, the Microsoft request identifier for that exact call, the service diagnostic
detail, and any sign-in policy challenge attached to the response. The full response and every response header
are recorded as well, so nothing is left out. If you need to take the problem to your IT or security team, or
to Microsoft support, the log already contains the details they will ask for.

**📊 One command can now produce several dashboard data sets at once.** `-Dashboard` accepts more than one
value, such as `-Dashboard AIO,M365,ValueLens`, so a single collection generates the data for every dashboard
you ask for instead of requiring a separate collection for each. Each data set is written beneath its own
folder, and the whole set publishes together or not at all — if one dashboard cannot be produced, nothing is
published as complete, the collected data is kept for review, and the run reports failure.

> ℹ️ **A multi-dashboard run produces a fresh set of outputs.** Adding to a data set you already have is done
> one dashboard at a time in this build. If you select more than one dashboard together with an append target,
> the run stops and explains why before anything is collected or written, so nothing you already have is
> touched. Running one dashboard at a time supports adding to an existing data set exactly as before.

**💧 Catch up on whatever you missed, without tracking dates by hand.** Point a run at a dataset you already
have and PAX works out which whole UTC days are missing, then collects exactly those in a single run. Local,
SharePoint, and Microsoft Fabric destinations are all supported. The marker only moves forward after every
required output has published and been verified, so an interrupted or failed run simply collects the same
window again next time rather than leaving a hole.

**🤖 A substantially expanded agent catalog.** The export now carries the Entra Agent ID and the additional
contract columns without changing any existing column, explains why a fixed column is blank instead of leaving
it unexplained, and works its way through sustained service throttling rather than giving up.

**🕒 License state is now recorded as it was at the time, not as it is today.** Turn on user history and each
person's licensing state is written once with the date it applied from, and activity is attributed to the state
that was actually in effect when it happened. Without this, historical activity is reported against today's
license state, which makes adoption and trend reporting wrong for anyone whose license changed rather than
simply incomplete. A state is stored once, so repeating a run adds nothing and a new row appears only when
somebody's licensing genuinely changes.

**� A single command can now collect your full Microsoft 365 usage history.** Long historical ranges are no
longer capped part-way through.

> ⚠️ **If a Microsoft 365 usage collection is currently in progress on an older build**, finish it there first.
> This build divides the requested range differently, so an in-flight collection will either stop and tell you
> so, or restart the range from the beginning. Nothing is corrupted or lost either way. Collections that have
> already finished, and ongoing appends to an existing dataset, are unaffected.

**🛡️ Stronger protection for the data you already have.** Results are confirmed complete *before* anything is
merged into your existing files or uploaded. If any part of a run can't be confirmed, the run stops, says why,
leaves your existing files exactly as they were, publishes nothing partial, and doesn't record the period as
collected — so you can simply run it again. A run that finds no activity still produces the other output you
asked for. On a first run, everyone appearing in the activity data is guaranteed a matching user row.

**⚡ Large tenants and large existing datasets process dramatically faster.** Preparing a big user directory,
matching people to the identifiers they were given on previous runs, and folding a new run into an existing
dataset all now run through a much faster, disk-backed path. Steps that could previously take hours on a large
existing dataset now typically complete in minutes. Where data is unusual, the run quietly falls back to the
previous method rather than guessing.

**⏳ You can see what a long run is doing.** The slow steps now report steady progress while they work, roughly
once a minute, instead of appearing to hang with nothing on screen.

**📤 Large uploads and busy services are handled far more gracefully.** A large SharePoint upload now resumes
from where it stopped after a dropped connection instead of starting over, and can recover if your sign-in lapses
while the transfer is being set up. The agent catalog now works its way through sustained service throttling
rather than giving up, including throttling that arrives disguised as a different kind of error.

**🗄️ Microsoft Fabric destinations are checked up front.** Lakehouse destinations are now resolved and verified
*before* collection begins, so a destination problem stops the run early instead of after all the work is done —
including destinations whose names contain spaces. If a table still can't be written, the data is preserved to
`Files/` for recovery and the run truthfully reports *completed with gaps* rather than implying success.

**🔐 Agent catalog reads use the generally available endpoint first**, falling back only when needed, and
permission problems are now reported in plain language that tells you which permission is actually missing.

**📖 Refreshed guidance** on Power BI connectivity, required permissions, and data retention.

---

### 🛠️ Fixes

**🧩 Refusal details are no longer lost, so a genuine access problem is reported instead of retried.** On
PowerShell 7 the details Microsoft returns with a refused audit request were being discarded before they could
be read. Because those details were missing, a refusal caused by permissions or by a sign-in policy looked the
same as a passing glitch, so the run kept retrying it and eventually gave up without saying what happened.
Those runs could take hours and still finish with nothing to act on. PAX now reads the response correctly, so
a real access problem is recognized on the first attempt and the run stops promptly with the reason.

**� Everyone in the activity data has a matching row in the people file.** In a multi-dashboard run, each
dashboard's people file now carries a row for every person appearing in that dashboard's activity data,
including identities that exist only in activity and never in your directory, such as service and agent
accounts. Previously the directory listing was published on its own, so a small number of activity rows
referred to people the accompanying file did not describe, and adding such a run to an existing data set
would stop rather than publish the mismatch. Those runs now complete. Single-dashboard runs already behaved
this way and are unchanged.

**�🗂️ Each Microsoft 365 file keeps its own name in a multi-dashboard run.** The Microsoft 365 Rollup, UserStats,
SessionCohort, and SessionStats outputs are each written under their own distinct file name. Previously a
multi-dashboard run that included `M365` stopped with a duplicate destination error and published nothing at
all. Single-dashboard runs were never affected.

**🔍 A collection that comes up short says so instead of reporting success.** Each part of a collection is now
checked against the number of records the service said it would return. If retrieval ends early, the run reports
a gap and returns a failure result. Previously a short retrieval could be accepted as complete, and the missing
records were never mentioned.

**▶️ Resuming an interrupted collection works again.** An ordinary resume is no longer stopped by an unrelated
internal marker that was being written into every saved progress file. Resumes that were failing immediately now
continue normally.

**⏱️ A run that has finished its work now actually ends.** Monitoring reconciles the state of each part of the
collection against the jobs doing it, so a completed collection no longer waits indefinitely on a job that will
never report back. Genuinely long work is never cut short, and there is still no time limit of any kind.

**💻 A fully local run stays local.** If you supply both your own audit file and your own users file, the run does
not sign in and does not contact any service, because nothing about it needs to.

**🧾 Run logs are never overwritten.** A run log keeps its timestamp even when you specify a fixed output file
name, so a later run cannot quietly replace the log of an earlier one.

**🚦 A run that fails now reports failure.** A destination that cannot be reached before collection starts, and a
post-processing step that does not finish, both return a failure result instead of exiting as though everything
worked.

**💬 Messages describe what actually happened.** An append target is described as a target rather than as a
finished append, internal working files are no longer reported as your destination, the merge summary explains
that "departed" means absent from the window you collected rather than removed from your data, an interruption is
only attributed to you pressing Ctrl+C when that can genuinely be established, and the notice explaining that
dates do not filter an audit file you supplied now appears.

**📄 An output file name you specify is used exactly as you wrote it.** When you point an output at a particular
file name rather than at a folder, the finished file is written under precisely that name, locally and at
SharePoint or Fabric destinations. Previously a folder could be created carrying that name, with the output
placed inside it. Runs that point at a folder rather than a specific file name are unaffected.

**➕ Folding a run into an existing dataset publishes the combined result.** When a run is added to a dataset you
already have, the merged result is written out and the rows you already had are carried through it. If the
combined result cannot be published, the run reports that plainly instead of finishing quietly, and the dataset
you already had is left exactly as it was.

**✏️ The Entra Users file is written under the exact name you ask for.** When you point the Entra Users output at
a specific file name, that is the name the finished file gets — locally and at SharePoint or Fabric destinations
— instead of a variation that had to be renamed by hand afterwards. The raw directory extract is kept separately
under its own name so the two never collide, and if the file can't be published the run says so and leaves
whatever you already had untouched. Runs that point at a folder rather than a specific file name are unaffected.

**📅 Clearer, more accurate reporting.** A date range that covers no time at all is refused immediately with a
plain explanation, before any sign-in. Date-only ranges are treated consistently from midnight to midnight UTC,
so the same command returns the same records wherever it is run. The end-of-run summary reports identifier
counts more clearly.

</td>
</tr>
</table>

---

<div align="center">

<sub>Preview build · Not a released version · Validate results before relying on them</sub>

<sub>Questions or problems → [bmiddendorf@microsoft.com](mailto:bmiddendorf@microsoft.com)</sub>

</div>
