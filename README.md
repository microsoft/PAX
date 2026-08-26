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
- **Preview builds are not published as a GitHub release** and are not linked from the main README, so bookmark
  this branch if you want to find your way back to it.
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

### 📦 [PAX_Purview_Audit_Log_Processor_v1.11.16-prerelease-20260825a.ps1](https://github.com/microsoft/PAX/raw/968b15aaf467964b9dc75809128907d31832d563/PAX_Purview_Audit_Log_Processor_v1.11.16-prerelease-20260825a.ps1)

<sub>⬇️ Click the file name above to download this exact build.</sub>

<sub>**SHA256:** `17882ED51E11F6BF8611AA753FF55DB46E8F2E7C53495DAC8957B4A479392899`</sub>

<sub>Verify your download with `Get-FileHash .\PAX_Purview_Audit_Log_Processor_v1.11.16-prerelease-20260825a.ps1 -Algorithm SHA256`</sub>

---

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
