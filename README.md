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

### 📦 [PAX_Purview_Audit_Log_Processor_v1.11.16-prerelease-20260901a.ps1](https://github.com/microsoft/PAX/releases/download/purview-v1.11.16-prerelease-20260901a/PAX_Purview_Audit_Log_Processor_v1.11.16-prerelease-20260901a.ps1)

<sub>⬇️ Click the file name above to download this exact build.</sub>

<sub>**SHA256:** `A20AEBBCC44F09584E93B943B1171F6F65B9C9BDFE74621F3103B4F836EEFD99`</sub>

<sub>Verify your download with `Get-FileHash .\PAX_Purview_Audit_Log_Processor_v1.11.16-prerelease-20260901a.ps1 -Algorithm SHA256`</sub>

---

**🕒 License state is now recorded as it was at the time, not as it is today.** Turn on user history and each
person's licensing state is written once with the date it applied from, and activity is attributed to the state
that was actually in effect when it happened. Without this, historical activity is reported against today's
license state, which makes adoption and trend reporting wrong for anyone whose license changed rather than
simply incomplete. A state is stored once, so repeating a run adds nothing and a new row appears only when
somebody's licensing genuinely changes.

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

**⚡ Large tenants and large existing datasets process dramatically faster.** Preparing a big user directory,
matching people to the identifiers they were given on previous runs, and folding a new run into an existing
dataset all now run through a much faster, disk-backed path. Steps that could previously take hours on a large
existing dataset now typically complete in minutes. Where data is unusual, the run quietly falls back to the
previous method rather than guessing.

**⏳ You can see what a long run is doing.** The slow steps now report steady progress while they work, roughly
once a minute, instead of appearing to hang with nothing on screen.

**🛡️ Stronger protection for the data you already have.** Results are confirmed complete *before* anything is
merged into your existing files or uploaded. If any part of a run can't be confirmed, the run stops, says why,
leaves your existing files exactly as they were, publishes nothing partial, and doesn't record the period as
collected — so you can simply run it again. A run that finds no activity still produces the other output you
asked for. On a first run, everyone appearing in the activity data is guaranteed a matching user row.

**✏️ The Entra Users file is written under the exact name you ask for.** When you point the Entra Users output at
a specific file name, that is the name the finished file gets — locally and at SharePoint or Fabric destinations
— instead of a variation that had to be renamed by hand afterwards. The raw directory extract is kept separately
under its own name so the two never collide, and if the file can't be published the run says so and leaves
whatever you already had untouched. Runs that point at a folder rather than a specific file name are unaffected.

**📤 Large uploads and busy services are handled far more gracefully.** A large SharePoint upload now resumes
from where it stopped after a dropped connection instead of starting over, and can recover if your sign-in lapses
while the transfer is being set up. The agent catalog now works its way through sustained service throttling
rather than giving up, including throttling that arrives disguised as a different kind of error.

**🗄️ Microsoft Fabric destinations are checked up front.** Lakehouse destinations are now resolved and verified
*before* collection begins, so a destination problem stops the run early instead of after all the work is done —
including destinations whose names contain spaces. If a table still can't be written, the data is preserved to
`Files/` for recovery and the run truthfully reports *completed with gaps* rather than implying success.

**📚 A single command can now collect your full Microsoft 365 usage history.** Long historical ranges are no
longer capped part-way through.

> ⚠️ **If a Microsoft 365 usage collection is currently in progress on an older build**, finish it there first.
> This build divides the requested range differently, so an in-flight collection will either stop and tell you
> so, or restart the range from the beginning. Nothing is corrupted or lost either way. Collections that have
> already finished, and ongoing appends to an existing dataset, are unaffected.

**📅 Clearer, more accurate reporting.** A date range that covers no time at all is refused immediately with a
plain explanation, before any sign-in. Date-only ranges are treated consistently from midnight to midnight UTC,
so the same command returns the same records wherever it is run. The end-of-run summary reports identifier
counts more clearly.

**🔐 Agent catalog reads use the generally available endpoint first**, falling back only when needed, and
permission problems are now reported in plain language that tells you which permission is actually missing.

**📖 Refreshed guidance** on Power BI connectivity, required permissions, and data retention.

</td>
</tr>
</table>

---

<div align="center">

<sub>Preview build · Not a released version · Validate results before relying on them</sub>

<sub>Questions or problems → [bmiddendorf@microsoft.com](mailto:bmiddendorf@microsoft.com)</sub>

</div>
