# PAX - Purview Audit eXporter

Cross-platform desktop wizard (Tauri + React + TypeScript + Vite + Tailwind) that orchestrates the PowerShell script `scripts/CopilotAuditExport.ps1` to export Microsoft Purview (M365) audit logs with a curated Copilot/AI focus.

## 🚀 Quick Start

### Download Pre-built Applications

Go to the [Releases](../../releases) page and download the appropriate version for your platform:

**Windows Users:**
- `PAX-Windows-Portable.exe` - Single executable, no installation required
- `PAX-Windows-Installer.msi` - Traditional Windows installer (if available)

**Mac Users:**
- `PAX-macOS-AppleSilicon.zip` - For Apple Silicon Macs (M1/M2/M3)  
- `PAX-macOS-Intel.zip` - For Intel-based Macs

**Not sure which Mac version?** Click Apple menu → About This Mac. If you see "Apple M1", "Apple M2", or "Apple M3", download AppleSilicon.

### First Run

1. **No installation required** - PAX runs directly from the executable/app
2. **No admin privileges needed** - Runs in your user account
3. **Automatic setup** - The app will guide you through any required PowerShell module installations

## ✨ Features
* 4-step wizard (Parameters → Output → Review → Export)
* Real-time streaming of PowerShell stdout / stderr to a log console
* Percentage progress extraction (parses lines like `[42.5%] Query ...`) and shows a progress bar
* Activity multi-select with curated and full lists (bundled dataset; offline-first)
* CSV export with Open CSV / Open Folder buttons
* Offline bundled PowerShell script and datasets (copied into Tauri resources at build time)
* Friendly guidance if PowerShell 7 (`pwsh`) is missing

## Security
- Auth: Supports `WebLogin` (default), `DeviceCode`, `Credential`, and `Silent` (falls back to web). Connection is made via `ExchangeOnlineManagement` to Microsoft 365 compliance endpoints.
- Permissions: Requires appropriate Microsoft Purview/M365 audit permissions (e.g., View-Only Audit Logs or Audit Logs roles) in the tenant. Least-privilege is recommended.
- Module install scope: On first run, the app can install `ExchangeOnlineManagement`. Prefer per-user install (`-Scope CurrentUser`) to avoid system-wide changes. Enterprises may preinstall the module.
- Execution policy: The backend launches PowerShell with `-NoProfile -ExecutionPolicy Bypass` by default to ensure reliable execution. You can override this at runtime by setting `PURVIEW_EXEC_POLICY` (e.g., `AllSigned`). For enterprise deployments, sign `scripts/CopilotAuditExport.ps1` and configure `AllSigned`.
- Network: Calls Microsoft 365 Purview audit APIs via the EXO/Compliance module. No third-party or telemetry endpoints are contacted by the exporter.
Offline PowerShell script and datasets embedded in release builds (single-file); in dev they are read from the repo
- Data at rest: The CSV contains audit activity records which may include user identifiers and resource metadata. Store outputs in protected locations and handle per your data governance policy.
- CSV safety: If opening in Excel, be aware of CSV formula injection risks. The exporter does not add a leading `'` to fields; consider opening in a safe editor or sanitizing before sharing.
- Cancellation: The app cancels runs by terminating the PowerShell process (`taskkill` on Windows). Partial files may exist; rerun to regenerate a complete export.

For enterprise hardening guidance, see `SECURITY.md`.
## Production Build (A1: single-file EXE)
```pwsh
# Frontend
npm run build
# Backend (Tauri)
npm run tauri build
```
Notes:
- Release builds embed the PowerShell script and datasets into the binary (no external resources required at runtime). The script is extracted to a temp path only when executing and deleted after run.
- Dev builds prefer the repo files for faster iteration.
- Windows requires WebView2 runtime (installed with Edge / Evergreen runtime).
### For IT admins: preinstall EXO module (per-user)
Run this once per operator account to avoid install prompts:

```pwsh
Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -Confirm:$false
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

---

## B1: Create a Source ZIP (VS Code ready)
Produce a clean source archive for IT to inspect and open in VS Code (excludes `node_modules`, `target`, `dist`):

```pwsh
pwsh -File ./scripts/make-source-zip.ps1
```
The ZIP is written under `out/` with a versioned filename, e.g., `purview-audit-exporter_source_1.0.0.zip`.

## B2: Dev Container (optional)
A Dev Container provides a preconfigured environment with Node + Rust. If you use GitHub Codespaces or VS Code Remote Containers, place the following under `.devcontainer/`:

1) `.devcontainer/devcontainer.json`
2) `.devcontainer/Dockerfile`

Then open the folder in a Dev Container. Inside the container:

```bash
npm i
npm run tauri build
```
Note: To run the PowerShell exporter from inside a container against Microsoft 365, you'll need network egress and may need to install PowerShell 7 in the container. Alternatively, build in the container and run the packaged app on your host.
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
```

### Optional: enforce AllSigned and use a signed script
1) Obtain a code-signing cert and note its thumbprint.
2) Sign the exporter script:

```pwsh
powershell -File ./scripts/Sign-CopilotAuditExport.ps1 -CertificateThumbprint <THUMBPRINT>
```

3) Run the app with a stricter execution policy:

```pwsh
$env:PURVIEW_EXEC_POLICY = 'AllSigned'
npm run tauri dev
```

Alternatively, set a build-time default (applies when `PURVIEW_EXEC_POLICY` isn’t set):

```pwsh
# Windows PowerShell / pwsh
$env:PURVIEW_EXEC_POLICY_DEFAULT = 'AllSigned'
npm run tauri build
```

On other platforms:

```bash
PURVIEW_EXEC_POLICY_DEFAULT=AllSigned npm run tauri build
```

### Build-time signing (so customers get a signed script)
You can sign `scripts/CopilotAuditExport.ps1` during `prebuild` so the packaged app embeds the signed script.

Set one of these before running build:

```pwsh
# Using a cert in the user or machine store
$env:SIGN_THUMBPRINT = '<THUMBPRINT>'

# Or, using a PFX file (prefer CI secrets for password)
$env:SIGN_PFX_PATH = 'C:\path\to\codesign.pfx'
$secure = Read-Host -AsSecureString 'PFX Password'
$plain = [Runtime.InteropServices.Marshal]::PtrToStringUni([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
$env:SIGN_PFX_PASSWORD = $plain

# Optional: fail build if signing fails or no signing material is provided
$env:SIGN_STRICT = 'true'

npm run tauri build
```

Dev note: In dev, the app prefers the repo script path for quick iteration. If you want to run against the embedded signed script in dev, unset or rename your local script temporarily, or run a production build and execute the packaged app.

## PowerShell Script Source of Truth
Your existing `scripts/CopilotAuditExport.ps1` defines real parameter names and defaults:
| Parameter | Type      | Notes |
|-----------|-----------|-------|
| `StartDate` | `string` | Format: `yyyy-MM-dd` |
| `EndDate` | `string` | Format: `yyyy-MM-dd` (exclusive end in script loops) |
| `ActivityTypes` | `string[]` | Optional; script has a default list if omitted |
| `OutputFile` | `string` | Defaults to `CopilotMetrics_<timestamp>.csv` |

Invocation style (what the Rust backend does) passes each activity as its own token after `-ActivityTypes` (array binding), e.g.:

```pwsh
pwsh -File .\CopilotAuditExport.ps1 -StartDate 2025-09-01 -EndDate 2025-09-03 -ActivityTypes CopilotChatAccessed FileAccessed MessageSent -OutputFile report.csv
```

Previously a comma-joined list was used; this has been updated for cleaner native PowerShell parameter binding.

## UI Component Structure
Custom lightweight shadcn-style components live in `src/components/ui/` (button, input, checkbox, switch, card, progress, badge, scroll-area, popover, command). These can be replaced with full shadcn generated versions once you run the official generator (see Optional section below).

## Progress Handling
The script outputs lines like:
```
[37.5%] Query 12/32 - CopilotChatAccessed (2025-09-01 08:00 - 12:00)
```
The backend regex extracts the numeric percentage and emits a `ps-progress` event. The frontend displays either an indeterminate bar (until the first percentage arrives) or the numeric percent with one decimal.

## Prerequisites
* Node.js 18+
* Rust toolchain + Tauri prerequisites (https://tauri.app)
* PowerShell 7 (`pwsh` in PATH)

### Installing Prerequisites (Windows Quick Start)
```pwsh
# Install Node.js LTS
winget install OpenJS.NodeJS.LTS -s winget

# Install PowerShell 7 (if not already installed)
winget install Microsoft.Powershell -s winget

# Install Rust toolchain (will prompt; adds cargo, rustc)
winget install Rustlang.Rust.MSVC -s winget

# (Optional) VS Build Tools if prompted by Tauri (needed for native modules)
winget install Microsoft.VisualStudio.2022.BuildTools -s winget
```

After installing, open a **new** PowerShell window so PATH updates apply, then verify:
```pwsh
node -v
npm -v
pwsh -v
rustc -V
cargo -V
```

If `node` or `npm` is still not found, ensure Winget reports a successful install and that `C:\Program Files\nodejs` is in your PATH. You can temporarily add it for the current session:
```pwsh
$env:PATH += ';C:\Program Files\nodejs'
```

### macOS
```bash
brew install node powershell rustup-init
rustup-init -y
```
Launch PowerShell with `pwsh` and verify versions similarly.

### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y curl wget unzip build-essential
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
sudo snap install powershell --classic
curl https://sh.rustup.rs -sSf | sh -s -- -y
```
Reload your shell and verify versions.

## Install Dependencies
```bash
npm i
```

## Activities Catalog
The app loads a bundled merged dataset at startup (no network required). You can also "Load from file…" on Step 1 to use a custom dataset.

## Development
```bash
npm run tauri dev
```
Dev mode prioritizes the local `./scripts/CopilotAuditExport.ps1` so you can iterate on the script without rebuilding.

## Production Build
```bash
npm run build
npm run tauri build
```
`prebuild` runs `scripts/copy-script.cjs` to embed the script and datasets under `src-tauri/resources/scripts/` for offline usage.

## Optional: UI Library
The project includes lightweight UI components under `src/components/ui/` tailored for this app. You can replace them with a UI library of your choice if desired.

## Regenerating Activities (Optional)
Development-only scripts existed to scrape/merge activity datasets, but the published app uses bundled datasets. If you want to rebuild datasets, consider restoring the removed scripts.

## Manual Tests
See `TEST.md` for acceptance scenarios including validation, progress, and error handling.

## Troubleshooting
* Missing `pwsh`: follow the inline error guidance (winget, brew, apt instructions shown in-app).
* No progress numbers: ensure the script still writes percentage lines in the format `[<number>%]` at the start of relevant lines.
* `node` / `npm` not recognized: Install Node.js LTS (see Installing Prerequisites). Open a new shell so PATH refreshes.
* Rust build errors about linker / build tools: Install VS Build Tools (Windows) or Xcode Command Line Tools (macOS: `xcode-select --install`).
* Stale embedded script after changes: Rebuild (`npm run tauri build`) so `prebuild` copies the updated PowerShell script into resources.

## License
MIT
