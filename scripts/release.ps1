# PAX Version Bump and Release Script (PowerShell)
# Automatically updates version numbers in package.json, tauri.conf.json, and Cargo.toml
# Commits changes and triggers GitHub release workflow

param(
    [switch]$Patch,
    [switch]$Minor, 
    [switch]$Major,
    [string]$Message,
    [Parameter(Mandatory=$false)]
    [string]$ReleaseNotes,
    [switch]$Help
)

# Script configuration
$ScriptName = "PAX Release Script"

# Change to repository root (parent of scripts folder)
$ScriptRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ScriptRoot

$PackageJson = "package.json"
$TauriConf = "src-tauri/tauri.conf.json"
$CargoToml = "src-tauri/Cargo.toml"
$ExportScriptPattern = "PAX_Purview_Audit_Log_Processor_v*.ps1"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to get GitHub CLI path (supports both PATH and direct installation)
function Get-GitHubCLI {
    $ghCommand = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghCommand) {
        return "gh"
    }
    
    # Check common installation locations
    $commonPaths = @(
        "C:\Program Files\GitHub CLI\gh.exe",
        "${env:LOCALAPPDATA}\Programs\GitHub CLI\gh.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    Write-Warning "GitHub CLI (gh) not found. Please install from https://cli.github.com/"
    return $null
}

# Function to get VS Code path (supports both PATH and direct installation)
function Get-VSCode {
    $codeCommand = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCommand) {
        return "code"
    }
    
    # Check common installation locations
    $commonPaths = @(
        "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\bin\code.cmd",
        "C:\Program Files\Microsoft VS Code\bin\code.cmd",
        "C:\Program Files (x86)\Microsoft VS Code\bin\code.cmd",
        "${env:LOCALAPPDATA}\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    Write-Warning "VS Code not found. Please ensure VS Code is installed."
    return "code"  # Return 'code' as fallback - user might have it in PATH after restart
}

function Write-Header {
    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "  $ScriptName" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
}

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\release.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Patch          Increment patch version (1.0.21 → 1.0.22) [DEFAULT]"
    Write-Host "  -Minor          Increment minor version (1.0.21 → 1.1.0)"
    Write-Host "  -Major          Increment major version (1.0.21 → 2.0.0)"
    Write-Host "  -Message        Custom commit message (optional)"
    Write-Host "  -ReleaseNotes   Release notes description (required for releases)"
    Write-Host "  -Help           Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\release.ps1 -Patch -ReleaseNotes 'Bug fixes for export script'"
    Write-Host "  .\release.ps1 -Minor -ReleaseNotes 'Added agent filtering feature'"
    Write-Host "  .\release.ps1 -Major -ReleaseNotes 'Major UI overhaul and new features'"
    Write-Host ""
}

# Function to get current version from package.json
function Get-CurrentVersion {
    if (-not (Test-Path $PackageJson)) {
        Write-Error "package.json not found!"
        exit 1
    }
    
    try {
        $packageContent = Get-Content $PackageJson -Raw | ConvertFrom-Json
        return $packageContent.version
    }
    catch {
        Write-Error "Failed to read version from $PackageJson"
        exit 1
    }
}

# Function to increment version based on type
function Step-Version {
    param(
        [string]$CurrentVersion,
        [string]$BumpType
    )
    
    $versionParts = $CurrentVersion.Split('.')
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2]
    
    switch ($BumpType) {
        "major" {
            $major++
            $minor = 0
            $patch = 0
        }
        "minor" {
            $minor++
            $patch = 0
        }
        default {
            # patch
            $patch++
        }
    }
    
    return "$major.$minor.$patch"
}

# Function to update version in JSON file
function Update-JsonVersion {
    param(
        [string]$FilePath,
        [string]$NewVersion
    )
    
    try {
        $content = Get-Content $FilePath -Raw | ConvertFrom-Json
        
        # Handle different JSON structures
        if ($content.PSObject.Properties['version']) {
            # Direct version property (package.json)
            $content.version = $NewVersion
        }
        elseif ($content.PSObject.Properties['package']) {
            # Nested under package (tauri.conf.json)
            $content.package.version = $NewVersion
            
            # Also update window title in tauri.conf.json
            if ($content.PSObject.Properties['tauri'] -and 
                $content.tauri.PSObject.Properties['windows'] -and 
                $content.tauri.windows.Count -gt 0) {
                $currentTitle = $content.tauri.windows[0].title
                # Replace version in title (matches v1.0.xx pattern)
                $newTitle = $currentTitle -replace 'v\d+\.\d+\.\d+', "v$NewVersion"
                $content.tauri.windows[0].title = $newTitle
                Write-Status "Updated window title to: $newTitle"
            }
        }
        else {
            throw "No version property found in $FilePath"
        }
        
        # Convert back to JSON with proper formatting
        $jsonOutput = $content | ConvertTo-Json -Depth 20 -Compress:$false
        $jsonOutput | Set-Content $FilePath -Encoding UTF8
        Write-Success "Updated $FilePath to version $NewVersion"
    }
    catch {
        Write-Error "Failed to update $FilePath`: $($_.Exception.Message)"
        exit 1
    }
}

# Function to update version in Cargo.toml file
function Update-CargoVersion {
    param(
        [string]$FilePath,
        [string]$NewVersion
    )
    
    try {
        $content = Get-Content $FilePath -Raw
        
        # Update ONLY the version in [package] section (not dependencies)
        # Match the [package] section up to the next section or [dependencies]
        # Then replace only the first version = "x.x.x" in that section
        $pattern = '(\[package\][^\[]*?version\s*=\s*")[^"]+(")'
        
        if ($content -match $pattern) {
            # Replace only the first match (the [package] version)
            $content = $content -replace $pattern, "`${1}$NewVersion`${2}"
            $content | Set-Content $FilePath -Encoding UTF8 -NoNewline
            Write-Success "Updated $FilePath to version $NewVersion"
        }
        else {
            throw "Could not find version pattern in [package] section of $FilePath"
        }
    }
    catch {
        Write-Error "Failed to update $FilePath`: $($_.Exception.Message)"
        exit 1
    }
}

# Function to update version in the audit export PowerShell script (both static header and dynamic variable)
function Update-ExportScriptVersion {
    param(
        [string]$NewVersion
    )

    # Find existing versioned script file in root
    $scriptPattern = "PAX_Purview_Audit_Log_Processor_v*.ps1"
    $existingScript = Get-ChildItem -Path $scriptPattern -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $existingScript) {
        Write-Warning "Export script not found matching pattern: $scriptPattern (skipping)"
        return
    }

    $oldPath = $existingScript.FullName
    $oldFilename = $existingScript.Name
    $newFilename = "PAX_Purview_Audit_Log_Processor_v$NewVersion.ps1"
    $newPath = Join-Path (Get-Location) $newFilename
    
    # Extract old version from filename for verification
    if ($oldFilename -match "v([\d\.]+)\.ps1$") {
        $oldVersion = $matches[1]
        Write-Status "Current script version: v$oldVersion"
    }
    
    Write-Status "Updating export script: $oldFilename -> $newFilename"

    try {
        # STEP 1: Archive old version to script_archive/Purview_Audit_Log_Processor folder (PAX branch only)
        if ($oldPath -ne $newPath) {
            $archiveFolder = "script_archive/Purview_Audit_Log_Processor"
            if (-not (Test-Path $archiveFolder)) {
                New-Item -Path $archiveFolder -ItemType Directory -Force | Out-Null
                Write-Success "Created script archive folder"
            }
            
            $archivePath = Join-Path $archiveFolder $oldFilename
            Copy-Item -Path $oldPath -Destination $archivePath -Force
            Write-Success "Archived old version to: $archiveFolder/$oldFilename"
        }
        
        # STEP 2: Read and update content for new version
        $content = Get-Content $oldPath -Raw -ErrorAction Stop
        $updated = $false
        
        # Update static version comment at top of file (line 1)
        # Pattern: # Portable Audit eXporter (PAX) - Purview Audit Log Processor - vX.X.X
        $staticPattern = "(?m)^#\s*Portable Audit eXporter \(PAX\) - Purview Audit Log Processor - v[\d\.]+\s*$"
        if ($content -match $staticPattern) {
            $staticReplacement = "# Portable Audit eXporter (PAX) - Purview Audit Log Processor - v$NewVersion"
            $content = [regex]::Replace($content, $staticPattern, $staticReplacement, 1)
            $updated = $true
            Write-Success "Updated static version header to v$NewVersion"
        }
        else {
            Write-Warning "Could not locate static version header in export script (line 1)"
        }
        
        # Update dynamic $ScriptVersion variable assignment (if it exists)
        $dynamicPattern = "(?m)^\s*\$ScriptVersion\s*=\s*'[^']*'"
        if ($content -match $dynamicPattern) {
            # Use backtick to ensure literal $ScriptVersion is written
            $dynamicReplacement = "`$ScriptVersion = '$NewVersion'"
            $content = [regex]::Replace($content, $dynamicPattern, $dynamicReplacement, 1)
            $updated = $true
            Write-Success "Updated dynamic `$ScriptVersion variable to '$NewVersion'"
        }
        
        # Update all example command references in the script help section
        # Replace PAX_Purview_Audit_Log_Processor_vX.X.X.ps1 with new version
        $scriptNamePattern = "PAX_Purview_Audit_Log_Processor_v[\d\.]+\.ps1"
        if ($content -match $scriptNamePattern) {
            $content = [regex]::Replace($content, $scriptNamePattern, $newFilename)
            Write-Success "Updated script filename references in help examples"
        }
        
        # STEP 3: Save updated content to new versioned filename in root
        if ($updated -or ($oldPath -ne $newPath)) {
            $content | Set-Content -Path $newPath -Encoding UTF8 -NoNewline
            Write-Success "Saved updated script to: $newFilename"
            
            # Remove old file from root (already archived in script_archive/Purview_Audit_Log_Processor)
            if ($oldPath -ne $newPath) {
                Remove-Item -Path $oldPath -Force
                Write-Success "Removed old script from root: $oldFilename (archived in script_archive/Purview_Audit_Log_Processor)"
            }
        }
        else {
            Write-Warning "No version patterns found in export script to update"
        }
    }
    catch {
        Write-Error "Failed to update export script version: $($_.Exception.Message)"
        exit 1
    }
}

# Function to update README header version line and script references
function Update-ReadmeVersion {
    param(
        [string]$FilePath,
        [string]$NewVersion
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "README not found at $FilePath (skipping)"
        return
    }

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        $updated = $false
        
        # Update the Version field line (e.g., **Version:** 1.4.7)
        $versionFieldPattern = "\*\*Version:\*\*\s*[\d\.]+"
        if ($content -match $versionFieldPattern) {
            $newVersionField = "**Version:** $NewVersion"
            $content = [regex]::Replace($content, $versionFieldPattern, $newVersionField, 1)
            $updated = $true
            Write-Success "Updated README version field to $NewVersion"
        }
        
        # Update the script reference line (e.g., Script: `PAX_Purview_Audit_Log_Processor_v1.4.2.ps1`)
        $scriptRefPattern = "Script:\s*``PAX_Purview_Audit_Log_Processor_v[\d\.]+\.ps1``"
        if ($content -match $scriptRefPattern) {
            $newScriptRef = "Script: ``PAX_Purview_Audit_Log_Processor_v$NewVersion.ps1``"
            $content = [regex]::Replace($content, $scriptRefPattern, $newScriptRef, 1)
            $updated = $true
            Write-Success "Updated README script reference to v$NewVersion"
        }
        
        # Update all command examples that reference the script
        $scriptNamePattern = "PAX_Purview_Audit_Log_Processor_v[\d\.]+\.ps1"
        $newScriptName = "PAX_Purview_Audit_Log_Processor_v$NewVersion.ps1"
        if ($content -match $scriptNamePattern) {
            $content = [regex]::Replace($content, $scriptNamePattern, $newScriptName)
            $updated = $true
            Write-Success "Updated README command examples to use v$NewVersion"
        }
        
        # Update Quick Start download link version (keeps full URL structure)
        $quickStartPattern = "(\[``PAX_Purview_Audit_Log_Processor_v)[\d\.]+\.ps1``\]\(https://github\.com/microsoft/PAX/blob/release/script_archive/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_v)[\d\.]+\.ps1\)"
        if ($content -match $quickStartPattern) {
            $newQuickStartLink = "`${1}$NewVersion.ps1``](https://github.com/microsoft/PAX/blob/release/script_archive/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_v$NewVersion.ps1)"
            $content = [regex]::Replace($content, $quickStartPattern, $newQuickStartLink)
            $updated = $true
            Write-Success "Updated Quick Start download link to v$NewVersion"
        }
        
        # Save changes if any updates were made
        if ($updated) {
            $content | Set-Content -Path $FilePath -Encoding UTF8 -NoNewline
            Write-Success "Updated README with version $NewVersion"
        }
        else {
            Write-Warning "No version patterns found in README to update"
        }
    }
    catch {
        Write-Error "Failed to update README version: $($_.Exception.Message)"
        exit 1
    }
}

# Function to create release notes file
function New-ReleaseNotesFile {
    param(
        [string]$NewVersion,
        [string]$ReleaseDescription
    )
    
    Write-Status "Generating release notes for v$NewVersion..."
    
    # Create release_notes folder if it doesn't exist
    $releaseNotesFolder = "release_notes\Purview_Audit_Log_Processor"
    if (-not (Test-Path $releaseNotesFolder)) {
        New-Item -Path $releaseNotesFolder -ItemType Directory -Force | Out-Null
        Write-Success "Created release_notes\Purview_Audit_Log_Processor folder"
    }
    
    # Get GitHub username from git config
    $gitUsername = git config user.name
    $gitHubHandle = git config user.github
    if (-not $gitHubHandle) {
        # Try to get GitHub username from remote URL
        $remoteUrl = git config --get remote.origin.url
        if ($remoteUrl -match "github\.com[:/]([^/]+)") {
            $gitHubHandle = "@" + $matches[1]
        }
        else {
            $gitHubHandle = "Unknown"
        }
    }
    else {
        $gitHubHandle = "@" + $gitHubHandle
    }
    
    if (-not $gitUsername) {
        $gitUsername = "Unknown"
    }
    
    # Get current timestamp (UTC)
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")
    
    # Get the last tag
    $lastTag = git describe --tags --abbrev=0 2>$null
    if (-not $lastTag) {
        Write-Warning "No previous tag found, using initial commit"
        $lastTag = git rev-list --max-parents=0 HEAD
    }
    
    Write-Status "Comparing changes since $lastTag..."
    
    # Get list of modified files since last tag
    $modifiedFiles = git diff --name-only $lastTag HEAD 2>$null
    if (-not $modifiedFiles) {
        $modifiedFiles = @()
    }
    else {
        $modifiedFiles = $modifiedFiles -split "`n" | Where-Object { $_ -ne "" }
    }
    
    # Get commit history since last tag
    $commits = git log "$lastTag..HEAD" --pretty=format:"%h - %s (%an, %ar)" 2>$null
    if (-not $commits) {
        $commits = @("No commits found")
    }
    else {
        $commits = $commits -split "`n" | Where-Object { $_ -ne "" }
    }
    
    # Get detailed file changes with stats
    $fileStats = git diff --stat $lastTag HEAD 2>$null
    if (-not $fileStats) {
        $fileStats = "No file statistics available"
    }
    
    # Generate enhanced overview from git changes
    $enhancedOverview = ""
    if ($modifiedFiles) {
        $categories = @{
            "PowerShell Scripts" = @($modifiedFiles | Where-Object { $_ -match "\.ps1$" })
            "Documentation" = @($modifiedFiles | Where-Object { $_ -match "\.(md|pdf)$" })
            "Configuration Files" = @($modifiedFiles | Where-Object { $_ -match "\.(json|toml|yml|yaml)$" })
            "Source Code" = @($modifiedFiles | Where-Object { $_ -match "src/|src-tauri/" -and $_ -notmatch "\.(md|json|toml)$" })
            "GitHub Workflows" = @($modifiedFiles | Where-Object { $_ -match "\.github/" })
        }
        
        $changesSummary = @()
        foreach ($category in $categories.Keys) {
            $files = $categories[$category]
            if ($files.Count -gt 0) {
                $changesSummary += "- **$category**: $($files.Count) file(s) modified"
            }
        }
        
        if ($changesSummary.Count -gt 0) {
            $enhancedOverview = @"

### What Changed
$($changesSummary -join "`n")

"@
        }
    }
    
    # Build release notes content
    $releaseNotesContent = @"
# Release Notes: v$NewVersion

## Release Information
- **Version:** $NewVersion
- **Release Date:** $timestamp
- **Released By:** $gitUsername ($gitHubHandle)
- **Previous Version:** $lastTag

---

## Overview$enhancedOverview
$ReleaseDescription

---

## Detailed Changes

### Modified Files ($($modifiedFiles.Count) files changed)
``````
$($modifiedFiles -join "`n")
``````

### File Statistics
``````
$fileStats
``````

### Commit History
``````
$($commits -join "`n")
``````

---

## Installation

### Download v$NewVersion (This Version)
This release note documents **version $NewVersion**. Use the direct download links below to obtain this specific version:

- **Script v$NewVersion**: [PAX_Purview_Audit_Log_Processor_v$NewVersion.ps1](https://github.com/microsoft/PAX/blob/release/script_archive/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_v$NewVersion.ps1)
- **Documentation v$NewVersion**: [PAX_Documentation_v$NewVersion.pdf](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PDF/PAX_Documentation_v$NewVersion.pdf)

### Get Latest Version
For the most recent release, visit:
- **Latest Script Archive**: [Microsoft PAX Repository - Script Archive](https://github.com/microsoft/PAX/tree/release/script_archive/Purview_Audit_Log_Processor)
- **All Release Notes**: [Microsoft PAX Repository - Release Notes](https://github.com/microsoft/PAX/tree/release/release_notes/Purview_Audit_Log_Processor)

---

## Support

For questions or issues, refer to the documentation:
- **Documentation v$NewVersion (PDF)**: [PAX_Documentation_v$NewVersion.pdf](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/PDF/PAX_Documentation_v$NewVersion.pdf)
- **Documentation v$NewVersion (Markdown)**: [PAX_Documentation_v$NewVersion.md](https://github.com/microsoft/PAX/blob/release/release_documentation/Purview_Audit_Log_Processor/MD/PAX_Documentation_v$NewVersion.md)

---

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [Brian Middendorf](mailto:bmiddendorf@microsoft.com?subject=Microsoft%20PAX%3A%20Purview%20Audit%20Log%20Processor%20v$NewVersion%20Feedback) with any feedback.*
"@
    
    # Save release notes file
    $releaseNotesFile = Join-Path $releaseNotesFolder "v$NewVersion.md"
    $releaseNotesContent | Set-Content -Path $releaseNotesFile -Encoding UTF8
    Write-Success "Created release notes file: $releaseNotesFile"
    
    # Add to git
    git add $releaseNotesFile 2>$null
    Write-Success "Staged release notes file for commit"
    
    return $releaseNotesFile
}

# Function to validate git status
function Test-GitStatus {
    try {
        git rev-parse --git-dir | Out-Null
    }
    catch {
        Write-Error "Not in a git repository!"
        exit 1
    }
    
    # Check for uncommitted changes and show what will be included in the release
    $status = git status --porcelain
    
    if ($status) {
        Write-Warning "You have uncommitted changes other than version files."
        Write-Host "Files that will be included in this release:" -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        Write-Host ""
        $response = Read-Host "Do you want to continue? [y/N]"
        if ($response -notmatch "^[Yy]$") {
            Write-Error "Aborting due to uncommitted changes"
            exit 1
        }
        Write-Status "Will commit all changes as part of this release"
    }
    else {
        Write-Status "Git working directory is clean"
    }
}

# Function to sync release branch with customer-facing files
function Sync-ReleaseBranch {
    param(
        [string]$NewVersion
    )
    
    Write-Status "Generating PAX_Documentation_v${NewVersion}.pdf from README.md..."
    
    # Generate PDF from README.md using VS Code Markdown PDF extension
    # Create PDF in TEMP folder to avoid OneDrive security policies
    $readmePath = Join-Path (Get-Location) "README.md"
    $pdfFilename = "PAX_Documentation_v${NewVersion}.pdf"
    
    # Use TEMP folder for PDF generation (outside OneDrive)
    $tempFolder = [System.IO.Path]::GetTempPath()
    $tempReadmePath = Join-Path $tempFolder "README_temp_for_pdf.md"
    $tempPdfPath = Join-Path $tempFolder "README_temp_for_pdf.pdf"
    $finalPdfPath = Join-Path (Get-Location) $pdfFilename
    
    if (Test-Path $readmePath) {
        try {
            # Remove old versioned PDFs from repo
            Get-ChildItem -Path "PAX_Documentation_v*.pdf" -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item $_.FullName -Force
                Write-Status "Removed old PDF: $($_.Name)"
            }
            
            # Also remove README.pdf if it exists (legacy name)
            $legacyPdfPath = Join-Path (Get-Location) "README.pdf"
            if (Test-Path $legacyPdfPath) {
                Remove-Item $legacyPdfPath -Force
                Write-Status "Removed legacy README.pdf"
            }
            
            # Clean up any old temp files
            if (Test-Path $tempReadmePath) { Remove-Item $tempReadmePath -Force }
            if (Test-Path $tempPdfPath) { Remove-Item $tempPdfPath -Force }
            
            # Copy README to TEMP folder for PDF generation
            Copy-Item $readmePath $tempReadmePath -Force
            Write-Status "Copied README.md to TEMP folder (avoids OneDrive security policies)"
            
            Write-Status "Attempting to generate PDF using VS Code Markdown PDF extension..."
            
            # Open README.md in VS Code and wait for user to export
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
            Write-Host "║  PDF GENERATION REQUIRED                                       ║" -ForegroundColor Yellow
            Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
            Write-Host "║  Opening README copy in VS Code (TEMP folder)...               ║" -ForegroundColor Yellow
            Write-Host "║                                                                ║" -ForegroundColor Yellow
            Write-Host "║  Please export to PDF:                                         ║" -ForegroundColor Cyan
            Write-Host "║  1. Right-click in the editor                                  ║" -ForegroundColor White
            Write-Host "║  2. Select 'Markdown PDF: Export (pdf)'                        ║" -ForegroundColor White
            Write-Host "║  3. Wait for 'successfully converted!' message                 ║" -ForegroundColor White
            Write-Host "║                                                                ║" -ForegroundColor Yellow
            Write-Host "║  OR use Command Palette (Ctrl+Shift+P):                        ║" -ForegroundColor Cyan
            Write-Host "║  - Type 'Markdown PDF: Export (pdf)'                           ║" -ForegroundColor White
            Write-Host "║                                                                ║" -ForegroundColor Yellow
            Write-Host "║  NOTE: Using TEMP folder to avoid OneDrive security policies   ║" -ForegroundColor Magenta
            Write-Host "║                                                                ║" -ForegroundColor Yellow
            Write-Host "║  Press any key here when PDF export is complete...             ║" -ForegroundColor Green
            Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
            Write-Host ""
            
            # Get VS Code command
            $vscode = Get-VSCode
            
            # Open README copy in VS Code (don't wait for editor to close)
            Start-Process $vscode -ArgumentList $tempReadmePath -NoNewWindow
            
            # Wait for user confirmation
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            # Check if PDF was created
            Start-Sleep -Milliseconds 500  # Brief pause for file system
            
            # Check for the PDF in TEMP folder
            if (Test-Path $tempPdfPath) {
                # Move from TEMP to repo location
                Move-Item $tempPdfPath $finalPdfPath -Force
                $pdfSize = (Get-Item $finalPdfPath).Length / 1KB
                Write-Success "✓ $pdfFilename generated successfully ($([math]::Round($pdfSize, 2)) KB)"
                
                # Clean up temp README
                if (Test-Path $tempReadmePath) { Remove-Item $tempReadmePath -Force }
            } else {
                Write-Warning "$pdfFilename was not found in TEMP folder. Please try again."
                
                # Clean up temp README
                if (Test-Path $tempReadmePath) { Remove-Item $tempReadmePath -Force }
                
                Write-Error "$pdfFilename was not generated. Please generate it manually and re-run the script."
                Write-Host "To generate PDF manually:" -ForegroundColor Yellow
                Write-Host "  1. Copy README.md to a folder outside OneDrive (e.g., C:\Temp)" -ForegroundColor White
                Write-Host "  2. Open the copy in VS Code" -ForegroundColor White
                Write-Host "  3. Right-click → 'Markdown PDF: Export (pdf)'" -ForegroundColor White
                Write-Host "  4. Copy the generated PDF back to the repo as $pdfFilename" -ForegroundColor White
                throw "PDF generation incomplete"
            }
            
            # Archive PDF and README.md to release_documentation folder (before README gets updated)
            Write-Status "Archiving documentation to release_documentation\Purview_Audit_Log_Processor\..."
            $releaseDocFolder = Join-Path (Get-Location) "release_documentation\Purview_Audit_Log_Processor"
            $releaseDocPdfFolder = Join-Path $releaseDocFolder "PDF"
            $releaseDocMdFolder = Join-Path $releaseDocFolder "MD"
            
            # Create folder structure if needed
            if (-not (Test-Path $releaseDocFolder)) {
                New-Item -ItemType Directory -Path $releaseDocFolder -Force | Out-Null
                Write-Status "Created release_documentation\Purview_Audit_Log_Processor folder"
            }
            if (-not (Test-Path $releaseDocPdfFolder)) {
                New-Item -ItemType Directory -Path $releaseDocPdfFolder -Force | Out-Null
                Write-Status "Created PDF subfolder"
            }
            if (-not (Test-Path $releaseDocMdFolder)) {
                New-Item -ItemType Directory -Path $releaseDocMdFolder -Force | Out-Null
                Write-Status "Created MD subfolder"
            }
            
            # Archive the PDF
            $archivePdfPath = Join-Path $releaseDocPdfFolder $pdfFilename
            if (Test-Path $finalPdfPath) {
                Copy-Item -Path $finalPdfPath -Destination $archivePdfPath -Force
                Write-Success "✓ Archived PDF: PDF\$pdfFilename"
            } else {
                Write-Warning "Could not archive PDF - source file not found"
            }
            
            # Archive the current README.md (before it gets updated for new version)
            $readmeMdFilename = "PAX_Documentation_v${NewVersion}.md"
            $archiveMdPath = Join-Path $releaseDocMdFolder $readmeMdFilename
            if (Test-Path $readmePath) {
                Copy-Item -Path $readmePath -Destination $archiveMdPath -Force
                Write-Success "✓ Archived README: MD\$readmeMdFilename"
            } else {
                Write-Warning "Could not archive README.md - source file not found"
            }
        }
        catch {
            # Clean up temp files on error
            if (Test-Path $tempReadmePath) { Remove-Item $tempReadmePath -Force -ErrorAction SilentlyContinue }
            if (Test-Path $tempPdfPath) { Remove-Item $tempPdfPath -Force -ErrorAction SilentlyContinue }
            
            Write-Error "PDF generation failed: $($_.Exception.Message)"
            Write-Host "Please generate $pdfFilename manually before continuing." -ForegroundColor Yellow
            throw
        }
    }
    else {
        Write-Error "README.md not found - cannot generate PDF"
        throw "README.md missing"
    }
    
    Write-Status "Syncing release branch with customer-facing files..."
    
    # Check if we're using worktrees
    $worktrees = git worktree list 2>$null
    $usingWorktrees = $worktrees -match "release"
    
    if ($usingWorktrees) {
        # Worktree approach - no branch switching needed!
        Write-Status "Detected worktree setup - syncing files directly..."
        
        # Find the release worktree path
        $releaseWorktreePath = $null
        $worktrees | ForEach-Object {
            if ($_ -match "^\s*(.+?)\s+[a-f0-9]+\s+\[release\]") {
                $releaseWorktreePath = $matches[1].Trim()
            }
        }
        
        if (-not $releaseWorktreePath -or -not (Test-Path $releaseWorktreePath)) {
            Write-Warning "Release worktree not found. Run: git worktree add `"..\PAX App-release`" release"
            return
        }
        
        Write-Status "Release worktree location: $releaseWorktreePath"
        
        # Find the current versioned script file dynamically in root
        $scriptPattern = "PAX_Purview_Audit_Log_Processor_v*.ps1"
        $currentScript = Get-ChildItem -Path $scriptPattern -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if (-not $currentScript) {
            Write-Error "Could not find export script matching pattern: $scriptPattern"
            throw "Export script not found"
        }
        
        $scriptFilename = $currentScript.Name
        Write-Status "Found script to sync: $scriptFilename"
        
        # Set versioned PDF filename
        $pdfFilename = "PAX_Documentation_v${NewVersion}.pdf"
        Write-Status "PDF file to sync: $pdfFilename"
        
        # Define customer-facing files to sync (excluding scripts/ folder entirely)
        $filesToSync = @{
            ".gitattributes" = ".gitattributes"
            ".github/workflows/build-release.yml" = ".github/workflows/build-release.yml"
            "CODE_OF_CONDUCT.md" = "CODE_OF_CONDUCT.md"
            "CONTRIBUTORS.md" = "CONTRIBUTORS.md"
            "LICENSE" = "LICENSE"
            "README.md" = "README.md"
            $pdfFilename = $pdfFilename
            "SECURITY.md" = "SECURITY.md"
            $scriptFilename = $scriptFilename
        }
        
        # Copy files from PAX to release worktree
        $copiedFiles = @()
        foreach ($sourceFile in $filesToSync.Keys) {
            $destFile = $filesToSync[$sourceFile]
            $sourcePath = Join-Path (Get-Location) $sourceFile
            $destPath = Join-Path $releaseWorktreePath $destFile
            
            if (Test-Path $sourcePath) {
                # Create destination directory if needed
                $destDir = Split-Path $destPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                
                # Copy file
                Copy-Item -Path $sourcePath -Destination $destPath -Force
                $copiedFiles += $destFile
                Write-Success "✓ Synced $destFile"
            }
            else {
                Write-Warning "Source file not found: $sourceFile (skipping)"
            }
        }
        
        # Sync release_documentation folder (entire directory with all PDFs)
        Write-Status "Syncing release_documentation\Purview_Audit_Log_Processor folder..."
        $sourceDocFolder = Join-Path (Get-Location) "release_documentation\Purview_Audit_Log_Processor"
        $destDocFolder = Join-Path $releaseWorktreePath "release_documentation\Purview_Audit_Log_Processor"
        if (Test-Path $sourceDocFolder) {
            if (-not (Test-Path $destDocFolder)) {
                New-Item -ItemType Directory -Path $destDocFolder -Force | Out-Null
            }
            # Copy all files from source to destination
            Get-ChildItem -Path $sourceDocFolder -File | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $destDocFolder -Force
                Write-Success "✓ Synced release_documentation\Purview_Audit_Log_Processor\$($_.Name)"
            }
        }
        
        # Sync release_notes folder (entire directory with all release notes)
        Write-Status "Syncing release_notes\Purview_Audit_Log_Processor folder..."
        $sourceNotesFolder = Join-Path (Get-Location) "release_notes\Purview_Audit_Log_Processor"
        $destNotesFolder = Join-Path $releaseWorktreePath "release_notes\Purview_Audit_Log_Processor"
        if (Test-Path $sourceNotesFolder) {
            if (-not (Test-Path $destNotesFolder)) {
                New-Item -ItemType Directory -Path $destNotesFolder -Force | Out-Null
            }
            # Copy all files from source to destination
            Get-ChildItem -Path $sourceNotesFolder -File | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $destNotesFolder -Force
                Write-Success "✓ Synced release_notes\Purview_Audit_Log_Processor\$($_.Name)"
            }
        }
        
        # Clean up old versioned scripts in release worktree root (keep only current version)
        $releaseRootPath = $releaseWorktreePath
        if (Test-Path $releaseRootPath) {
            Get-ChildItem -Path "$releaseRootPath/PAX_Purview_Audit_Log_Processor_v*.ps1" | 
                Where-Object { $_.Name -ne $scriptFilename } | 
                ForEach-Object {
                    Remove-Item $_.FullName -Force
                    Write-Status "Removed old script version: $($_.Name)"
                }
            
            # Clean up old versioned PDFs in release worktree root (keep only current version)
            Get-ChildItem -Path "$releaseRootPath/PAX_Documentation_v*.pdf" | 
                Where-Object { $_.Name -ne $pdfFilename } | 
                ForEach-Object {
                    Remove-Item $_.FullName -Force
                    Write-Status "Removed old PDF version: $($_.Name)"
                }
        }
        
        # Navigate to release worktree and commit changes
        Push-Location $releaseWorktreePath
        try {
            # Create .gitkeep files in all parent directories to ensure they're tracked with current version
            Write-Status "Updating parent directory timestamps in release branch..."
            $parentDirs = @(
                '.github',
                '.github\workflows',
                'release_documentation',
                'release_documentation\Purview_Audit_Log_Processor',
                'release_documentation\Purview_Audit_Log_Processor\MD',
                'release_documentation\Purview_Audit_Log_Processor\PDF',
                'release_notes',
                'release_notes\Purview_Audit_Log_Processor',
                'script_archive',
                'script_archive\Purview_Audit_Log_Processor'
            )
            foreach ($dir in $parentDirs) {
                $gitkeepPath = Join-Path $dir ".gitkeep"
                if (Test-Path $dir) {
                    New-Item -Path $gitkeepPath -ItemType File -Force | Out-Null
                }
            }
            
            # Touch all root-level files to update their commit timestamp
            Write-Status "Updating root-level file timestamps in release branch..."
            Get-ChildItem -File | ForEach-Object {
                $_.LastWriteTime = Get-Date
            }
            Write-Success "✓ Updated directory and file timestamps in release branch"
            
            # Check if there are changes
            $changes = git status --porcelain
            if ($changes) {
                Write-Status "Changes detected in release worktree:"
                $changes | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
                
                # Stage and commit changes with version number
                git add .
                git commit -m "v${NewVersion}"
                Write-Success "Committed changes to release branch"
                
                # Push release branch to Rance9/PAX (backup) - no protection
                Write-Status "Pushing release branch to Rance9/PAX..."
                git push backup release 2>$null
                Write-Success "Pushed release branch to Rance9/PAX"
                
                # For microsoft/PAX, create PR due to branch protection
                Write-Status "Creating PR for microsoft/PAX release branch..."
                $tempBranch = "release-sync-v${NewVersion}"
                
                # Get GitHub CLI command
                $gh = Get-GitHubCLI
                if (-not $gh) {
                    Write-Error "Cannot create PR - GitHub CLI not found"
                    Write-Status "Skipping PR creation (manual PR required)"
                } else {
                    # Clean up old temporary branches before creating new one
                    Write-Status "Checking for old temporary branches..."
                    $oldTempBranches = git ls-remote --heads origin | Where-Object { $_ -match "release-sync-v" -and $_ -notmatch $tempBranch }
                    if ($oldTempBranches) {
                        $oldTempBranches | ForEach-Object {
                            if ($_ -match "refs/heads/(.+)$") {
                                $oldBranch = $matches[1]
                                # Check if there's a merged or closed PR for this branch
                                $prState = & $gh pr list --repo microsoft/PAX --head $oldBranch --state all --json state,number --jq '.[0] | "\(.state)|\(.number)"' 2>$null
                                if ($prState) {
                                    $state, $prNum = $prState -split '\|'
                                    if ($state -eq "MERGED" -or $state -eq "CLOSED") {
                                        Write-Status "Deleting old temporary branch: $oldBranch (PR #$prNum was $state)"
                                        git push origin --delete $oldBranch 2>$null
                                    }
                                }
                            }
                        }
                    }
                    
                    # Push to temporary branch on microsoft/PAX only (not Rance9)
                    git push origin release:$tempBranch -f 2>$null
                    
                    # Check if PR already exists
                    $existingPR = & $gh pr list --repo microsoft/PAX --base release --head $tempBranch --json number --jq '.[0].number' 2>$null
                    
                    if ($existingPR) {
                        Write-Status "PR already exists: https://github.com/microsoft/PAX/pull/$existingPR"
                    } else {
                        # Create new PR
                        $prUrl = & $gh pr create --repo microsoft/PAX --base release --head $tempBranch --title "v${NewVersion}" --body "Automated release sync for v${NewVersion}`n`nSynced files from PAX branch to release branch." 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "PR created: $prUrl"
                            Write-Host "`n⚠️  ACTION REQUIRED: Please approve and merge the PR at: $prUrl" -ForegroundColor Yellow
                        } else {
                            Write-Error "Failed to create PR: $prUrl"
                        }
                    }
                }
                
                Write-Status "Release branch updates complete (microsoft/PAX requires PR approval)"
            }
            else {
                Write-Status "No changes detected in release worktree (already up to date)"
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        # Legacy approach - branch switching (for backward compatibility)
        Write-Warning "Not using worktrees - consider setting up worktree for better workflow"
        Write-Status "To set up worktree, run: git worktree add `"..\PAX App-release`" release"
        
        $currentBranch = git rev-parse --abbrev-ref HEAD
        
        try {
            # Switch to release branch
            git checkout release 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Release branch doesn't exist locally, skipping sync"
                return
            }
            Write-Status "Switched to release branch"
            
            # Pull latest
            git pull origin release 2>$null
            
            # Find the current versioned script file dynamically in root
            $scriptPattern = "PAX_Purview_Audit_Log_Processor_v*.ps1"
            git checkout $currentBranch -- $scriptPattern 2>$null
            $currentScript = Get-ChildItem -Path $scriptPattern -ErrorAction SilentlyContinue | Select-Object -First 1
            
            if (-not $currentScript) {
                Write-Error "Could not find export script on PAX branch"
                throw "Export script not found"
            }
            
            $scriptFilename = $currentScript.Name
            
            # Set versioned PDF filename
            $pdfFilename = "PAX_Documentation_v${NewVersion}.pdf"
            
            # Copy customer-facing files from PAX branch (excluding scripts/ folder)
            Write-Status "Copying customer-facing files from PAX branch..."
            
            # Create .github/workflows directory
            New-Item -ItemType Directory -Path ".github/workflows" -Force | Out-Null
            
            # Copy files (script is now in root, not scripts/)
            git checkout $currentBranch -- ".gitattributes" 2>$null
            git checkout $currentBranch -- ".github/workflows/build-release.yml" 2>$null
            git checkout $currentBranch -- "CODE_OF_CONDUCT.md" 2>$null
            git checkout $currentBranch -- "CONTRIBUTORS.md" 2>$null
            git checkout $currentBranch -- "LICENSE" 2>$null
            git checkout $currentBranch -- "README.md" 2>$null
            git checkout $currentBranch -- "$pdfFilename" 2>$null
            git checkout $currentBranch -- "SECURITY.md" 2>$null
            git checkout $currentBranch -- "$scriptFilename" 2>$null
            
            # Copy release_documentation folder
            Write-Status "Copying release_documentation folder..."
            git checkout $currentBranch -- "release_documentation" 2>$null
            
            Write-Success "✓ Copied customer-facing files"
            
            # Clean up old script versions from root
            Get-ChildItem -Path "PAX_Purview_Audit_Log_Processor_v*.ps1" | 
                Where-Object { $_.Name -ne $scriptFilename } | 
                ForEach-Object {
                    Remove-Item $_.FullName -Force
                    Write-Status "Removed old script version: $($_.Name)"
                }
            
            # Clean up old PDF versions from root
            Get-ChildItem -Path "PAX_Documentation_v*.pdf" | 
                Where-Object { $_.Name -ne $pdfFilename } | 
                ForEach-Object {
                    Remove-Item $_.FullName -Force
                    Write-Status "Removed old PDF version: $($_.Name)"
                }
            
            # Create .gitkeep files in all parent directories to ensure they're tracked with current version
            Write-Status "Updating parent directory timestamps in release branch..."
            $parentDirs = @(
                '.github',
                '.github\workflows',
                'release_documentation',
                'release_documentation\Purview_Audit_Log_Processor',
                'release_documentation\Purview_Audit_Log_Processor\MD',
                'release_documentation\Purview_Audit_Log_Processor\PDF',
                'release_notes',
                'release_notes\Purview_Audit_Log_Processor',
                'script_archive',
                'script_archive\Purview_Audit_Log_Processor'
            )
            foreach ($dir in $parentDirs) {
                $gitkeepPath = Join-Path $dir ".gitkeep"
                if (Test-Path $dir) {
                    New-Item -Path $gitkeepPath -ItemType File -Force | Out-Null
                }
            }
            
            # Touch all root-level files to update their commit timestamp
            Write-Status "Updating root-level file timestamps in release branch..."
            Get-ChildItem -File | ForEach-Object {
                $_.LastWriteTime = Get-Date
            }
            Write-Success "✓ Updated directory and file timestamps in release branch"
            
            # Stage and commit
            git add . 2>$null
            $changes = git diff --cached --name-only
            if ($changes) {
                git commit -m "v${NewVersion}"
                Write-Success "Committed changes to release branch"
                
                # Push release branch to Rance9/PAX (backup) - no protection
                Write-Status "Pushing release branch to Rance9/PAX..."
                git push backup release 2>$null
                Write-Success "Pushed release branch to Rance9/PAX"
                
                # For microsoft/PAX, create PR due to branch protection
                Write-Status "Creating PR for microsoft/PAX release branch..."
                $tempBranch = "release-sync-v${NewVersion}"
                
                # Get GitHub CLI command
                $gh = Get-GitHubCLI
                if (-not $gh) {
                    Write-Error "Cannot create PR - GitHub CLI not found"
                    Write-Status "Skipping PR creation (manual PR required)"
                } else {
                    # Clean up old temporary branches before creating new one
                    Write-Status "Checking for old temporary branches..."
                    $oldTempBranches = git ls-remote --heads origin | Where-Object { $_ -match "release-sync-v" -and $_ -notmatch $tempBranch }
                    if ($oldTempBranches) {
                        $oldTempBranches | ForEach-Object {
                            if ($_ -match "refs/heads/(.+)$") {
                                $oldBranch = $matches[1]
                                # Check if there's a merged or closed PR for this branch
                                $prState = & $gh pr list --repo microsoft/PAX --head $oldBranch --state all --json state,number --jq '.[0] | "\(.state)|\(.number)"' 2>$null
                                if ($prState) {
                                    $state, $prNum = $prState -split '\|'
                                    if ($state -eq "MERGED" -or $state -eq "CLOSED") {
                                        Write-Status "Deleting old temporary branch: $oldBranch (PR #$prNum was $state)"
                                        git push origin --delete $oldBranch 2>$null
                                    }
                                }
                            }
                        }
                    }
                    
                    # Push to temporary branch on microsoft/PAX only (not Rance9)
                    git push origin release:$tempBranch -f 2>$null
                    
                    # Check if PR already exists
                    $existingPR = & $gh pr list --repo microsoft/PAX --base release --head $tempBranch --json number --jq '.[0].number' 2>$null
                    
                    if ($existingPR) {
                        Write-Status "PR already exists: https://github.com/microsoft/PAX/pull/$existingPR"
                    } else {
                        # Create new PR
                        $prUrl = & $gh pr create --repo microsoft/PAX --base release --head $tempBranch --title "v${NewVersion}" --body "Automated release sync for v${NewVersion}`n`nSynced files from PAX branch to release branch." 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Success "PR created: $prUrl"
                            Write-Host "`n⚠️  ACTION REQUIRED: Please approve and merge the PR at: $prUrl" -ForegroundColor Yellow
                        } else {
                            Write-Error "Failed to create PR: $prUrl"
                        }
                    }
                }
                
                Write-Status "Release branch updates complete (microsoft/PAX requires PR approval)"
            }
            else {
                Write-Status "No changes detected (already up to date)"
            }
            
            # Switch back
            git checkout $currentBranch
            Write-Status "Switched back to $currentBranch branch"
        }
        catch {
            Write-Error "Failed to sync release branch: $($_.Exception.Message)"
            git checkout $currentBranch 2>$null
            throw
        }
    }
}

# Function to create commit and tag
function New-CommitAndTag {
    param(
        [string]$NewVersion,
        [string]$BumpType,
        [string]$CustomMessage
    )
    
    # Create .gitkeep files in directories to track them with current version (PAX branch)
    Write-Status "Updating directory timestamps in PAX branch..."
    
    # Get all root-level directories (excluding .git, node_modules, and temporary folders)
    $rootDirs = Get-ChildItem -Directory | Where-Object { 
        $_.Name -notmatch '^(\.git|node_modules)$' 
    } | Select-Object -ExpandProperty Name
    
    # Get all subdirectories within specific folders
    $detailedDirs = @()
    $foldersToExpand = @('release_documentation', 'release_notes', 'script_archive', 'scripts', '.github')
    foreach ($folder in $foldersToExpand) {
        if (Test-Path $folder) {
            $detailedDirs += Get-ChildItem -Path $folder -Directory -Recurse | 
                ForEach-Object { $_.FullName.Replace((Get-Location).Path + '\', '') }
        }
    }
    
    # Combine all directories and create .gitkeep files
    $allDirs = $rootDirs + $detailedDirs | Select-Object -Unique
    foreach ($dir in $allDirs) {
        if (Test-Path $dir) {
            $gitkeepPath = Join-Path $dir ".gitkeep"
            New-Item -Path $gitkeepPath -ItemType File -Force | Out-Null
        }
    }
    
    # Touch all root-level files to update their commit timestamp
    Write-Status "Updating root-level file timestamps..."
    Get-ChildItem -File | ForEach-Object {
        $_.LastWriteTime = Get-Date
    }
    Write-Success "✓ Updated directory and file timestamps"
    
    # Add all uncommitted changes to ensure GitHub workflow has access to everything
    git add .
    Write-Status "Staged all uncommitted changes for release"
    
    # Create commit message - simple version number only
    $commitMsg = "v${NewVersion}"
    
    # Commit the changes
    git commit -m $commitMsg
    Write-Success "Created commit: $commitMsg"
    
    # Create and push tag
    git tag "v$NewVersion"
    Write-Success "Created tag: v$NewVersion"
    
    # Push changes and tag to both repositories (PAX branch)
    Write-Status "Pushing PAX branch and tag to both repositories..."
    git push origin PAX 2>$null
    git push origin "v$NewVersion" 2>$null
    git push backup PAX
    git push backup "v$NewVersion"
    Write-Success "Pushed PAX branch and tag to both GitHub repositories"
    
    # Now sync the release branch with customer-facing files
    Sync-ReleaseBranch -NewVersion $NewVersion
}

# Function to show summary
function Show-Summary {
    param(
        [string]$OldVersion,
        [string]$NewVersion,
        [string]$BumpType,
        [string]$CommitMessage
    )
    
    Write-Host ""
    Write-Host "🎉 Release Summary" -ForegroundColor Green
    Write-Host "==================" -ForegroundColor Green
    Write-Host "• Old version: " -NoNewline; Write-Host "v$OldVersion" -ForegroundColor Yellow
    Write-Host "• New version: " -NoNewline; Write-Host "v$NewVersion" -ForegroundColor Yellow
    Write-Host "• Bump type:   " -NoNewline; Write-Host "$BumpType" -ForegroundColor Yellow
    Write-Host "• Git tag:     " -NoNewline; Write-Host "v$NewVersion" -ForegroundColor Yellow
    Write-Host "• Commit msg:  " -NoNewline; Write-Host "$CommitMessage" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "� Branches Updated:" -ForegroundColor Cyan
    Write-Host "   ✅ PAX branch (development) - pushed to both repos" -ForegroundColor Green
    Write-Host "   ✅ release branch (customer-facing) - synced and pushed to both repos" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 View on GitHub:" -ForegroundColor Cyan
    Write-Host "   • Microsoft (PAX):     https://github.com/microsoft/PAX/tree/PAX" -ForegroundColor Blue
    Write-Host "   • Microsoft (release): https://github.com/microsoft/PAX/tree/release" -ForegroundColor Blue
    Write-Host "   • Private (PAX):       https://github.com/Rance9/PAX/tree/PAX" -ForegroundColor Blue
    Write-Host "   • Private (release):   https://github.com/Rance9/PAX/tree/release" -ForegroundColor Blue
    Write-Host ""
    Write-Host "🚀 GitHub Actions workflow will now:" -ForegroundColor Cyan
    Write-Host "   ✅ Build Windows executable"
    Write-Host "   ✅ Build macOS executable" 
    Write-Host "   ✅ Create GitHub release page"
    Write-Host "   ✅ Upload distribution files"
    Write-Host ""
}

# Main script logic
function Main {
    Write-Header
    
    # Show help if requested
    if ($Help) {
        Show-Usage
        return
    }
    
    # Validate that ReleaseNotes parameter is provided
    if (-not $ReleaseNotes -or $ReleaseNotes.Trim() -eq "") {
        Write-Error "The -ReleaseNotes parameter is required for creating a release."
        Write-Host ""
        Write-Host "Please provide a description of the changes in this release:" -ForegroundColor Yellow
        Write-Host "Example: .\release.ps1 -Minor -ReleaseNotes 'Added agent filtering feature with progress bar improvements'" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }
    
    # Determine bump type
    $bumpType = "patch"  # Default
    if ($Major) { $bumpType = "major" }
    elseif ($Minor) { $bumpType = "minor" }
    elseif ($Patch) { $bumpType = "patch" }
    
    Write-Status "Starting $bumpType version bump..."
    
    # Validate environment
    Test-GitStatus
    
    # Get current version
    $currentVersion = Get-CurrentVersion
    Write-Status "Current version: v$currentVersion"
    
    # Calculate new version
    $newVersion = Step-Version -CurrentVersion $currentVersion -BumpType $bumpType
    Write-Status "New version: v$newVersion"
    
    # Prepare commit message
    $finalCommitMsg = if ($Message) {
        "v${newVersion}: $Message"
    }
    else {
        switch ($bumpType) {
            "major" { "v${newVersion}: Major version release" }
            "minor" { "v${newVersion}: Minor version release" }
            default { "v${newVersion}: Patch version release" }
        }
    }
    
    # Confirm with user
    Write-Host ""
    Write-Host "About to bump version:" -ForegroundColor Yellow
    Write-Host "  From:  " -NoNewline; Write-Host "v$currentVersion" -ForegroundColor Cyan
    Write-Host "  To:    " -NoNewline; Write-Host "v$newVersion" -ForegroundColor Cyan
    Write-Host "  Type:  " -NoNewline; Write-Host "$bumpType" -ForegroundColor Cyan
    Write-Host "  Msg:   " -NoNewline; Write-Host "$finalCommitMsg" -ForegroundColor Cyan
    Write-Host "  Notes: " -NoNewline; Write-Host "$ReleaseNotes" -ForegroundColor Cyan
    Write-Host ""
    $response = Read-Host "Continue? [Y/n]"
    if ($response -match "^[Nn]$") {
        Write-Warning "Version bump cancelled by user"
        return
    }
    
    # Update version files
    Write-Status "Updating version files..."
    Update-JsonVersion -FilePath $PackageJson -NewVersion $newVersion
    Update-JsonVersion -FilePath $TauriConf -NewVersion $newVersion
    Update-CargoVersion -FilePath $CargoToml -NewVersion $newVersion
    Update-ExportScriptVersion -NewVersion $newVersion
    Update-ReadmeVersion -FilePath "README.md" -NewVersion $newVersion
    
    # Generate release notes file
    Write-Status "Generating release notes..."
    $releaseNotesFile = New-ReleaseNotesFile -NewVersion $newVersion -ReleaseDescription $ReleaseNotes
    Write-Success "Release notes saved to: $releaseNotesFile"
    
    # Commit and tag
    Write-Status "Creating git commit and tag..."
    New-CommitAndTag -NewVersion $newVersion -BumpType $bumpType -CustomMessage $Message
    
    # Show summary
    Show-Summary -OldVersion $currentVersion -NewVersion $newVersion -BumpType $bumpType -CommitMessage $finalCommitMsg
    
    Write-Success "Release process completed successfully! 🎉"
}

# Run the main function
Main

