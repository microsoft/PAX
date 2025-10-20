# PAX Version Bump and Release Script (PowerShell)
# Automatically updates version numbers in package.json, tauri.conf.json, and Cargo.toml
# Commits changes and triggers GitHub release workflow
# Supports Umbrella, Purview, and Graph script types for selective file syncing

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Umbrella', 'Purview', 'Graph')]
    [string]$ScriptType,
    
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

$VersionsManifest = "versions.json"
$PackageJson = "package.json"
$TauriConf = "src-tauri/tauri.conf.json"
$CargoToml = "src-tauri/Cargo.toml"

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

# Function to categorize files by ScriptType
function Get-FilesForScriptType {
    param([string]$ScriptType)
    
    # Get all changed files
    $allChanges = git status --porcelain
    if (-not $allChanges) {
        return @{
            Relevant = @()
            Other = @()
        }
    }
    
    $relevantFiles = @()
    $otherFiles = @()
    
    foreach ($change in $allChanges) {
        # Parse git status format: "XY filename" or "XY oldname -> newname"
        # Format is: " M filename" or "MM filename" (2 status chars + space + filename)
        $line = $change
        $file = ""
        
        if ($line -match '->') {
            # Rename: "R  old -> new"
            $file = ($line -split '->')[1].Trim()
        } else {
            # Regular change: "XY filename" - skip first 3 characters (status + space)
            $file = $line.Substring(3)
        }
        
        # Normalize path separators to forward slashes for consistent matching
        $file = $file -replace '\\', '/'
        
        $isRelevant = $false
        
        switch ($ScriptType) {
            "Umbrella" {
                # Umbrella includes core root files and shared parent folders
                # NOTE: scripts/ folder is DEV-ONLY (PAX branch) and NOT synced to release
                $isRelevant = ($file -match '^\.gitattributes$') -or
                              ($file -match '^CODE_OF_CONDUCT\.md$') -or
                              ($file -match '^CONTRIBUTORS\.md$') -or
                              ($file -match '^LICENSE$') -or
                              ($file -match '^README\.md$') -or
                              ($file -match '^SECURITY\.md$') -or
                              ($file -match '^\.github/') -or
                              # Parent folders but NOT Purview/Graph subfolders
                              (($file -match '^release_documentation/') -and ($file -notmatch '/(Purview|Graph)_Audit_Log_Processor/')) -or
                              (($file -match '^release_notes/') -and ($file -notmatch '/(Purview|Graph)_Audit_Log_Processor/')) -or
                              (($file -match '^script_archive/') -and ($file -notmatch '/(Purview|Graph)_Audit_Log_Processor/'))
            }
            "Purview" {
                # Purview includes Purview-specific files
                $isRelevant = ($file -match '^PAX_Purview_Audit_Log_Processor_v.*\.ps1$') -or
                              ($file -match '^PAX_Purview_Documentation_v.*\.pdf$') -or
                              ($file -match '^README-Purview\.md$') -or
                              ($file -match '^release_documentation/Purview_Audit_Log_Processor/') -or
                              ($file -match '^release_notes/Purview_Audit_Log_Processor/') -or
                              ($file -match '^script_archive/Purview_Audit_Log_Processor/')
            }
            "Graph" {
                # Graph includes Graph-specific files
                $isRelevant = ($file -match '^PAX_Graph_Audit_Log_Processor_v.*\.ps1$') -or
                              ($file -match '^PAX_Graph_Documentation_v.*\.pdf$') -or
                              ($file -match '^README-Graph\.md$') -or
                              ($file -match '^release_documentation/Graph_Audit_Log_Processor/') -or
                              ($file -match '^release_notes/Graph_Audit_Log_Processor/') -or
                              ($file -match '^script_archive/Graph_Audit_Log_Processor/')
            }
        }
        
        if ($isRelevant) {
            $relevantFiles += $line
        } else {
            $otherFiles += $line
        }
    }
    
    return @{
        Relevant = $relevantFiles
        Other = $otherFiles
    }
}

# Function to clean up old temporary branches
function Remove-OldTempBranches {
    Write-Status "Checking for old temporary branches to clean up..."
    
    $gh = Get-GitHubCLI
    if (-not $gh) {
        Write-Warning "GitHub CLI not found - skipping temp branch cleanup"
        return
    }
    
    # Get all temp branches from microsoft/PAX
    Write-Status "Checking microsoft/PAX for merged/closed temp branches..."
    $remoteBranches = git ls-remote --heads origin 2>$null | Where-Object { $_ -match "release-sync-" }
    
    $deletedCount = 0
    foreach ($branchLine in $remoteBranches) {
        if ($branchLine -match "refs/heads/(.+)$") {
            $branchName = $matches[1]
            
            # Check if there's a PR for this branch
            $prInfo = & $gh pr list --repo microsoft/PAX --head $branchName --state all --json state,number --jq '.[0] | "\(.state)|\(.number)"' 2>$null
            
            if ($prInfo) {
                $state, $prNum = $prInfo -split '\|'
                
                if ($state -eq "MERGED" -or $state -eq "CLOSED") {
                    Write-Status "Deleting merged/closed temp branch: $branchName (PR #$prNum - $state)"
                    git push origin --delete $branchName 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        $deletedCount++
                    }
                }
            }
        }
    }
    
    # Clean up Rance9/PAX by pruning stale branches
    Write-Status "Pruning stale remote tracking branches from Rance9/PAX..."
    git remote prune backup 2>$null | Out-Null
    
    # Delete local temp branches that no longer have remotes
    Write-Status "Cleaning up local temp branches..."
    $localBranches = git branch | Where-Object { $_ -match "release-sync-" }
    foreach ($branchLine in $localBranches) {
        $branchName = $branchLine.Trim().TrimStart('* ')
        
        # Check if remote branch still exists on either repo
        $originExists = git ls-remote --heads origin "refs/heads/$branchName" 2>$null
        $backupExists = git ls-remote --heads backup "refs/heads/$branchName" 2>$null
        
        if (-not $originExists -and -not $backupExists) {
            Write-Status "Deleting local branch with no remote: $branchName"
            git branch -D $branchName 2>$null | Out-Null
        }
    }
    
    if ($deletedCount -gt 0) {
        Write-Success "Cleaned up $deletedCount temp branch(es)"
    } else {
        Write-Status "No temp branches to clean up"
    }
}

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\release.ps1 -ScriptType <Umbrella|Purview|Graph> [OPTIONS]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -ScriptType     Type of changes (Umbrella, Purview, or Graph) [REQUIRED]"
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
    Write-Host "  .\release.ps1 -ScriptType Umbrella -Patch -ReleaseNotes 'Updated core documentation'"
    Write-Host "  .\release.ps1 -ScriptType Purview -Minor -ReleaseNotes 'Added agent filtering feature'"
    Write-Host "  .\release.ps1 -ScriptType Graph -Major -ReleaseNotes 'Initial Graph processor release'"
    Write-Host ""
    Write-Host "Commit Message Format:"
    Write-Host "  Umbrella: PAX-v1.0.0"
    Write-Host "  Purview:  purview-v1.7.0"
    Write-Host "  Graph:    graph-v0.1.0"
    Write-Host ""
    Write-Host "File Categories & Release Branch Sync:"
    Write-Host "  Umbrella - Root governance files (LICENSE, README.md, CODE_OF_CONDUCT, etc.)"
    Write-Host "             Plus parent folder .gitkeep files (release_documentation/, release_notes/, script_archive/)"
    Write-Host "             Does NOT sync product subfolders (those use product-specific commits)"
    Write-Host "             Excludes: Product scripts in root, scripts/ folder (dev-only)"
    Write-Host ""
    Write-Host "  Purview  - Purview script in root + Purview subfolders ONLY"
    Write-Host "             (release_documentation/Purview_Audit_Log_Processor/, etc.)"
    Write-Host "             Does NOT sync root governance files or parent folders"
    Write-Host ""
    Write-Host "  Graph    - Graph script in root + Graph subfolders ONLY"
    Write-Host "             (release_documentation/Graph_Audit_Log_Processor/, etc.)"
    Write-Host "             Does NOT sync root governance files or parent folders"
    Write-Host ""
}

# Function to get current version from versions.json manifest (Single Source of Truth)
function Get-CurrentVersion {
    param([string]$ScriptType)
    
    if (-not (Test-Path $VersionsManifest)) {
        Write-Error "Version manifest not found: $VersionsManifest"
        Write-Host "Please ensure versions.json exists in the repository root." -ForegroundColor Yellow
        exit 1
    }
    
    try {
        $manifest = Get-Content $VersionsManifest -Raw | ConvertFrom-Json
        
        switch ($ScriptType) {
            "Umbrella" {
                $version = $manifest.products.pax.version
                if (-not $version) {
                    Write-Error "PAX version not found in $VersionsManifest"
                    exit 1
                }
                return $version
            }
            "Purview" {
                $version = $manifest.products.purview.version
                if (-not $version) {
                    Write-Error "Purview version not found in $VersionsManifest"
                    exit 1
                }
                return $version
            }
            "Graph" {
                $version = $manifest.products.graph.version
                if (-not $version) {
                    Write-Error "Graph version not found in $VersionsManifest"
                    exit 1
                }
                return $version
            }
        }
    }
    catch {
        Write-Error "Failed to read version manifest: $($_.Exception.Message)"
        exit 1
    }
}

# Function to update version in versions.json manifest
function Update-VersionsManifest {
    param(
        [string]$ScriptType,
        [string]$NewVersion
    )
    
    if (-not (Test-Path $VersionsManifest)) {
        Write-Error "Version manifest not found: $VersionsManifest"
        exit 1
    }
    
    try {
        $manifest = Get-Content $VersionsManifest -Raw | ConvertFrom-Json
        
        # Update version based on ScriptType
        switch ($ScriptType) {
            "Umbrella" {
                $manifest.products.pax.version = $NewVersion
                Write-Status "Updated PAX version in manifest: $NewVersion"
            }
            "Purview" {
                $manifest.products.purview.version = $NewVersion
                $manifest.products.purview.releaseDate = (Get-Date).ToString("yyyy-MM-dd")
                Write-Status "Updated Purview version in manifest: $NewVersion"
            }
            "Graph" {
                $manifest.products.graph.version = $NewVersion
                $manifest.products.graph.releaseDate = (Get-Date).ToString("yyyy-MM-dd")
                Write-Status "Updated Graph version in manifest: $NewVersion"
            }
        }
        
        # Update lastUpdated timestamp
        $manifest.lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        # Save back to file with proper formatting
        $jsonOutput = $manifest | ConvertTo-Json -Depth 20
        $jsonOutput | Set-Content $VersionsManifest -Encoding UTF8
        Write-Success "Updated version manifest: $VersionsManifest"
        
        # Stage the manifest file for commit
        git add $VersionsManifest 2>$null
        Write-Success "Staged version manifest for commit"
    }
    catch {
        Write-Error "Failed to update version manifest: $($_.Exception.Message)"
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
        [string]$NewVersion,
        [string]$ScriptType
    )

    # Umbrella commits don't have scripts to version
    if ($ScriptType -eq "Umbrella") {
        Write-Status "Umbrella commit - no script versioning needed"
        return
    }

    # Determine script pattern, filenames, and paths based on ScriptType
    $scriptPattern = switch ($ScriptType) {
        "Purview" { "PAX_Purview_Audit_Log_Processor_v*.ps1" }
        "Graph"   { "PAX_Graph_Audit_Log_Processor_v*.ps1" }
    }
    
    $scriptPrefix = switch ($ScriptType) {
        "Purview" { "PAX_Purview_Audit_Log_Processor" }
        "Graph"   { "PAX_Graph_Audit_Log_Processor" }
    }
    
    $processorType = switch ($ScriptType) {
        "Purview" { "Purview Audit Log Processor" }
        "Graph"   { "Graph Audit Log Processor" }
    }
    
    $archiveFolder = switch ($ScriptType) {
        "Purview" { "script_archive/Purview_Audit_Log_Processor" }
        "Graph"   { "script_archive/Graph_Audit_Log_Processor" }
    }

    # Find existing versioned script file in root
    $existingScript = Get-ChildItem -Path $scriptPattern -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $existingScript) {
        Write-Warning "Export script not found matching pattern: $scriptPattern (skipping)"
        return
    }

    $oldPath = $existingScript.FullName
    $oldFilename = $existingScript.Name
    $newFilename = "${scriptPrefix}_v$NewVersion.ps1"
    $newPath = Join-Path (Get-Location) $newFilename
    
    # Extract old version from filename for verification
    if ($oldFilename -match "v([\d\.]+)\.ps1$") {
        $oldVersion = $matches[1]
        Write-Status "Current $ScriptType script version: v$oldVersion"
    }
    
    Write-Status "Updating $ScriptType export script: $oldFilename -> $newFilename"

    try {
        # STEP 1: Archive old version to script_archive folder (PAX branch only)
        if ($oldPath -ne $newPath) {
            if (-not (Test-Path $archiveFolder)) {
                New-Item -Path $archiveFolder -ItemType Directory -Force | Out-Null
                Write-Success "Created script archive folder: $archiveFolder"
            }
            
            $archivePath = Join-Path $archiveFolder $oldFilename
            
            # Archive the RELEASED version (from git tag), not the working directory version
            # This ensures post-release changes don't pollute the archive
            $oldVersionTag = switch ($ScriptType) {
                "Purview" { "purview-v$oldVersion" }
                "Graph"   { "graph-v$oldVersion" }
            }
            
            # Check if the tag exists
            $tagExists = git tag -l $oldVersionTag 2>$null
            if ($tagExists) {
                # Extract the file from the git tag (committed/released version)
                $gitFilePath = $oldFilename
                $archivedContent = git show "${oldVersionTag}:${gitFilePath}" 2>$null
                
                if ($LASTEXITCODE -eq 0 -and $archivedContent) {
                    $archivedContent | Set-Content -Path $archivePath -Encoding UTF8 -NoNewline
                    Write-Success "Archived RELEASED version from tag $oldVersionTag to: $archiveFolder/$oldFilename"
                }
                else {
                    # Fallback: If git show fails, copy from working directory (with warning)
                    Copy-Item -Path $oldPath -Destination $archivePath -Force
                    Write-Warning "Could not extract from tag $oldVersionTag, archived working directory version (may include post-release changes)"
                }
            }
            else {
                # Tag doesn't exist (first release or tag missing), copy from working directory
                Copy-Item -Path $oldPath -Destination $archivePath -Force
                Write-Warning "Tag $oldVersionTag not found, archived working directory version (may include post-release changes)"
            }
        }
        
        # STEP 2: Read and update content for new version
        $content = Get-Content $oldPath -Raw -ErrorAction Stop
        $updated = $false
        
        # Update static version comment at top of file (line 1)
        # Pattern: # Portable Audit eXporter (PAX) - [Purview|Graph] Audit Log Processor - vX.X.X
        $staticPattern = "(?m)^#\s*Portable Audit eXporter \(PAX\) - $processorType - v[\d\.]+\s*$"
        if ($content -match $staticPattern) {
            $staticReplacement = "# Portable Audit eXporter (PAX) - $processorType - v$NewVersion"
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
        # Replace [PAX_Purview|PAX_Graph]_Audit_Log_Processor_vX.X.X.ps1 with new version
        $scriptNamePattern = "${scriptPrefix}_v[\d\.]+\.ps1"
        if ($content -match $scriptNamePattern) {
            $content = [regex]::Replace($content, $scriptNamePattern, $newFilename)
            Write-Success "Updated script filename references in help examples"
        }
        
        # STEP 3: Save updated content to new versioned filename in root
        if ($updated -or ($oldPath -ne $newPath)) {
            $content | Set-Content -Path $newPath -Encoding UTF8 -NoNewline
            Write-Success "Saved updated script to: $newFilename"
            
            # Remove old file from root (already archived)
            if ($oldPath -ne $newPath) {
                Remove-Item -Path $oldPath -Force
                Write-Success "Removed old script from root: $oldFilename (archived in $archiveFolder)"
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
        [string]$NewVersion,
        [string]$ScriptType = "Purview"
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "README not found at $FilePath (skipping)"
        return
    }

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
        $updated = $false
        
        # Determine product-specific patterns based on ScriptType
        if ($ScriptType -eq "Purview") {
            $productName = "Purview_Audit_Log_Processor"
            $scriptName = "PAX_Purview_Audit_Log_Processor"
            $releaseTag = "purview"
            $docName = "PAX_Purview_Audit_Log_Processor_Documentation"
        } elseif ($ScriptType -eq "Graph") {
            $productName = "Graph_Audit_Log_Processor"
            $scriptName = "PAX_Graph_Audit_Log_Processor"
            $releaseTag = "graph"
            $docName = "PAX_Graph_Audit_Log_Processor_Documentation"
        } else {
            Write-Warning "Update-ReadmeVersion only supports Purview/Graph ScriptTypes"
            return
        }
        
        # 1. Update GitHub release download link
        # Pattern: [`PAX_Purview_Audit_Log_Processor_v1.7.0.ps1`](https://github.com/microsoft/PAX/releases/download/purview-v1.7.0/PAX_Purview_Audit_Log_Processor_v1.7.0.ps1)
        $downloadLinkPattern = "(\[``${scriptName}_v)[\d\.]+\.ps1``\]\(https://github\.com/microsoft/PAX/releases/download/${releaseTag}-v[\d\.]+/${scriptName}_v[\d\.]+\.ps1\)"
        if ($content -match $downloadLinkPattern) {
            $newDownloadLink = "`${1}$NewVersion.ps1``](https://github.com/microsoft/PAX/releases/download/${releaseTag}-v$NewVersion/${scriptName}_v$NewVersion.ps1)"
            $content = [regex]::Replace($content, $downloadLinkPattern, $newDownloadLink)
            $updated = $true
            Write-Success "Updated README GitHub release download link to v$NewVersion"
        }
        
        # 2. Update documentation link
        # Pattern: [Latest Documentation](./release_documentation/Purview_Audit_Log_Processor/MD/PAX_Purview_Audit_Log_Processor_Documentation_v1.7.0.md)
        $docLinkPattern = "(\[Latest Documentation\]\(\.\/release_documentation\/${productName}\/MD\/${docName}_v)[\d\.]+\.md\)"
        if ($content -match $docLinkPattern) {
            $newDocLink = "`${1}$NewVersion.md)"
            $content = [regex]::Replace($content, $docLinkPattern, $newDocLink)
            $updated = $true
            Write-Success "Updated README documentation link to v$NewVersion"
        }
        
        # 3. Update release notes link
        # Pattern: [Latest Release Notes](./release_notes/Purview_Audit_Log_Processor/PAX_Purview_Audit_Log_Processor_Release_Note_v1.7.0.md)
        $notesLinkPattern = "(\[Latest Release Notes\]\(\.\/release_notes\/${productName}\/${scriptName}_Release_Note_v)[\d\.]+\.md\)"
        if ($content -match $notesLinkPattern) {
            $newNotesLink = "`${1}$NewVersion.md)"
            $content = [regex]::Replace($content, $notesLinkPattern, $newNotesLink)
            $updated = $true
            Write-Success "Updated README release notes link to v$NewVersion"
        }
        
        # Save changes if any updates were made
        if ($updated) {
            $content | Set-Content -Path $FilePath -Encoding UTF8 -NoNewline
            Write-Success "✓ Updated README.md with all v$NewVersion links"
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
        [string]$ReleaseDescription,
        [string]$ScriptType
    )
    
    Write-Status "Generating release notes for $ScriptType v$NewVersion..."
    
    # Determine folder and paths based on ScriptType
    $releaseNotesFolder = switch ($ScriptType) {
        "Purview"  { "release_notes\Purview_Audit_Log_Processor" }
        "Graph"    { "release_notes\Graph_Audit_Log_Processor" }
        "Umbrella" { "release_notes" }
    }
    
    $scriptPrefix = switch ($ScriptType) {
        "Purview"  { "PAX_Purview_Audit_Log_Processor" }
        "Graph"    { "PAX_Graph_Audit_Log_Processor" }
        "Umbrella" { $null }
    }
    
    $processorPath = switch ($ScriptType) {
        "Purview"  { "Purview_Audit_Log_Processor" }
        "Graph"    { "Graph_Audit_Log_Processor" }
        "Umbrella" { $null }
    }
    
    # Create release_notes folder if it doesn't exist
    if (-not (Test-Path $releaseNotesFolder)) {
        New-Item -Path $releaseNotesFolder -ItemType Directory -Force | Out-Null
        Write-Success "Created $releaseNotesFolder folder"
    }
    
    # Get GitHub username from git config
    $gitUsername = git config user.name
    if (-not $gitUsername) {
        $gitUsername = "Unknown"
    }
    
    # Get current timestamp
    $releaseDate = (Get-Date).ToString("yyyy-MM-dd")
    
    # Get the last tag for comparison
    $lastTag = git describe --tags --abbrev=0 2>$null
    if (-not $lastTag) {
        Write-Warning "No previous tag found, this appears to be first release"
        $lastTag = "Initial"
        $previousVersion = "Initial"
    } else {
        # Extract version from tag (e.g., "purview-v1.7.0" -> "1.7.0")
        if ($lastTag -match "v?([\d\.]+)$") {
            $previousVersion = $matches[1]
        } else {
            $previousVersion = $lastTag
        }
    }
    
    Write-Status "Analyzing changes since $lastTag..."
    
    # Get list of modified files since last tag
    $modifiedFiles = git diff --name-only $lastTag HEAD 2>$null
    if (-not $modifiedFiles) {
        $modifiedFiles = @()
    }
    else {
        $modifiedFiles = $modifiedFiles -split "`n" | Where-Object { $_ -ne "" }
    }
    
    # Get detailed diff for each modified file
    $fileDiffs = @()
    foreach ($file in $modifiedFiles) {
        if ($file -match "\.(ps1|md)$") {  # Focus on scripts and documentation
            $diff = git diff $lastTag HEAD -- $file 2>$null
            if ($diff) {
                $fileDiffs += @{
                    File = $file
                    Diff = $diff
                }
            }
        }
    }
    
    # Categorize changes
    $scriptChanges = @($modifiedFiles | Where-Object { $_ -match "\.ps1$" -and $_ -notmatch "scripts/" })
    $docChanges = @($modifiedFiles | Where-Object { $_ -match "release_documentation.*\.md$" })
    $infraChanges = @($modifiedFiles | Where-Object { $_ -match "(README|LICENSE|SECURITY|scripts/)" })
    
    # Get commit messages for context
    $commits = git log "$lastTag..HEAD" --pretty=format:"%s" 2>$null
    if ($commits) {
        $commits = $commits -split "`n" | Where-Object { $_ -ne "" }
    } else {
        $commits = @()
    }
    
    # Generate AI prompt for release notes
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  AI RELEASE NOTES GENERATION REQUIRED" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "STEP 1: Copy the prompt below and paste it into GitHub Copilot Chat" -ForegroundColor Green
    Write-Host "STEP 2: Copilot will generate comprehensive release notes" -ForegroundColor Green  
    Write-Host "STEP 3: Copy Copilot's response and paste it back here when prompted" -ForegroundColor Green
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Build the AI prompt
    $aiPrompt = @"
Generate comprehensive, user-friendly release notes for $ScriptType Audit Log Processor v$NewVersion.

**Release Context:**
- Product: $ScriptType Audit Log Processor
- New Version: $NewVersion
- Previous Version: $previousVersion
- Release Date: $releaseDate
- Released By: $gitUsername

**Changes Summary:**
- Script files changed: $($scriptChanges.Count)
- Documentation changed: $($docChanges.Count)
- Infrastructure changed: $($infraChanges.Count)

**Modified Files:**
$($modifiedFiles | ForEach-Object { "- $_" } | Out-String)

**Commit Messages:**
$($commits | ForEach-Object { "- $_" } | Out-String)

**File Diffs (Key Changes):**
$($fileDiffs | ForEach-Object {
    "
### $($_.File)
``````diff
$($_.Diff)
``````
"
} | Out-String)

**Instructions:**
Please analyze these changes and generate release notes following this structure:

# Release Notes: v$NewVersion

## Release Information
- **Version:** $NewVersion
- **Release Date:** $releaseDate (Updated)
- **Released By:** $gitUsername (@microsoft)
- **Previous Version:** v$previousVersion

---

## Overview

[Write 2-3 sentences explaining what this release accomplishes and why it was created. Focus on USER VALUE, not technical details.]

Version $NewVersion is a [maintenance/feature/major] release that [describe primary purpose]. This release [describe key improvements].

---

## What's New

[List the key changes in user-friendly language. Group by category if needed:]

### Documentation Improvements
[If documentation was changed, explain what sections were added/improved and why users will benefit]

### Script Enhancements  
[If script was changed, explain what functionality was improved and what problems it solves]

### Infrastructure Updates
[If infrastructure was changed, explain how it improves the release process]

---

## Detailed Changes

[Provide a detailed section-by-section breakdown of changes. For documentation changes, list which sections were modified and how. For script changes, explain functional improvements.]

---

## Installation

### Download v$NewVersion (This Version)
- **Script**: [${scriptPrefix}_v${NewVersion}.ps1](https://github.com/microsoft/PAX/releases/download/$($ScriptType.ToLower())-v${NewVersion}/${scriptPrefix}_v${NewVersion}.ps1)
- **Release Notes**: [This document](https://github.com/microsoft/PAX/blob/release/release_notes/${processorPath}/${scriptPrefix}_Release_Note_v${NewVersion}.md)
- **Documentation**: [${scriptPrefix}_Documentation_v${NewVersion}.md](https://github.com/microsoft/PAX/blob/release/release_documentation/${processorPath}/MD/${scriptPrefix}_Documentation_v${NewVersion}.md)

### Previous Versions
- v${previousVersion}: [Script](https://github.com/microsoft/PAX/releases/download/$($ScriptType.ToLower())-v${previousVersion}/${scriptPrefix}_v${previousVersion}.ps1) | [Release Notes](https://github.com/microsoft/PAX/blob/release/release_notes/${processorPath}/${scriptPrefix}_Release_Note_v${previousVersion}.md)
- [All Purview Releases](https://github.com/microsoft/PAX/releases?q=purview&expanded=true)

---

*Managed and released by the Microsoft Copilot Growth ROI Advisory Team. Please reach out to [Brian Middendorf](mailto:bmiddendorf@microsoft.com?subject=PAX%20${ScriptType}%20v${NewVersion}%20Feedback) with any feedback.*

**IMPORTANT:** Make the release notes comprehensive, user-friendly, and focus on VALUE delivered to users, not just technical file changes.
"@
    
    # Display the prompt
    Write-Host $aiPrompt -ForegroundColor White
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Save prompt to clipboard if possible
    try {
        $aiPrompt | Set-Clipboard
        Write-Success "✓ Prompt copied to clipboard!"
    } catch {
        Write-Warning "Could not copy to clipboard. Please manually copy the prompt above."
    }
    
    Write-Host ""
    Write-Host "Paste this prompt into GitHub Copilot Chat, then press ENTER here..." -ForegroundColor Yellow
    Read-Host | Out-Null
    
    Write-Host ""
    Write-Host "Now paste Copilot's response below and press ENTER twice when done:" -ForegroundColor Yellow
    Write-Host "(Paste the ENTIRE markdown response including all sections)" -ForegroundColor Cyan
    Write-Host ""
    
    # Read multi-line input from user
    $releaseNotesContent = @()
    $emptyLineCount = 0
    while ($true) {
        $line = Read-Host
        if ($line -eq "") {
            $emptyLineCount++
            if ($emptyLineCount -ge 2) {
                break
            }
            $releaseNotesContent += ""
        } else {
            $emptyLineCount = 0
            $releaseNotesContent += $line
        }
    }
    
    $releaseNotesText = $releaseNotesContent -join "`n"
    
    if (-not $releaseNotesText -or $releaseNotesText.Trim().Length -lt 100) {
        Write-Error "Release notes content too short or empty. Aborting."
        throw "Invalid release notes content"
    }
    
    # Save release notes file with proper naming convention
    if ($ScriptType -eq "Umbrella") {
        $releaseNotesFilename = "PAX_Release_Note_v$NewVersion.md"
    } else {
        $releaseNotesFilename = "${scriptPrefix}_Release_Note_v$NewVersion.md"
    }
    $releaseNotesFile = Join-Path $releaseNotesFolder $releaseNotesFilename
    $releaseNotesText | Set-Content -Path $releaseNotesFile -Encoding UTF8
    Write-Success "Created release notes file: $releaseNotesFile"
    
    # Add to git
    git add $releaseNotesFile 2>$null
    Write-Success "Staged release notes file for commit"
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Release notes successfully created!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    return $releaseNotesFile
}

# Function to validate git status
# Function to validate git status
function Test-GitStatus {
    param([string]$ScriptType)
    
    try {
        git rev-parse --git-dir | Out-Null
    }
    catch {
        Write-Error "Not in a git repository!"
        exit 1
    }
    
    # Check current branch
    $currentBranch = git rev-parse --abbrev-ref HEAD
    if ($currentBranch -ne "PAX") {
        Write-Error "Must be on PAX branch. Current branch: $currentBranch"
        Write-Host "Switch to PAX branch: git checkout PAX" -ForegroundColor Yellow
        exit 1
    }
    
    # Check for uncommitted changes
    $status = git status --porcelain
    
    if (-not $status) {
        Write-Error "No changes detected. Nothing to commit."
        exit 1
    }
    
    # Smart file filtering
    Write-Status "Analyzing changed files for ScriptType: $ScriptType"
    $fileCategories = Get-FilesForScriptType -ScriptType $ScriptType
    
    if ($fileCategories.Relevant.Count -eq 0) {
        Write-Error "No $ScriptType-related files have changed."
        Write-Host ""
        Write-Host "Changed files detected:" -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        Write-Host ""
        Write-Host "These files do not match the -ScriptType $ScriptType category." -ForegroundColor Yellow
        Write-Host "Please specify the correct -ScriptType for these files." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host ""
    Write-Host "Files to commit for ${ScriptType}:" -ForegroundColor Green
    $fileCategories.Relevant | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
    
    if ($fileCategories.Other.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠️  WARNING: Other uncommitted files NOT included in this commit:" -ForegroundColor Yellow
        $fileCategories.Other | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        Write-Host ""
        Write-Host "These files will require separate commits with appropriate -ScriptType:" -ForegroundColor Yellow
        
        # Suggest appropriate ScriptType for other files
        $hasUmbrella = $fileCategories.Other | Where-Object { $_ -match '(README\.md|LICENSE|CODE_OF_CONDUCT|SECURITY|CONTRIBUTORS|\.gitattributes|\.github/)' }
        $hasPurview = $fileCategories.Other | Where-Object { $_ -match 'Purview|purview' }
        $hasGraph = $fileCategories.Other | Where-Object { $_ -match 'Graph|graph' }
        $hasDevOnly = $fileCategories.Other | Where-Object { $_ -match '^scripts/' }
        
        if ($hasUmbrella) {
            Write-Host "  → Run with -ScriptType Umbrella for core files" -ForegroundColor Cyan
        }
        if ($hasPurview) {
            Write-Host "  → Run with -ScriptType Purview for Purview files" -ForegroundColor Cyan
        }
        if ($hasGraph) {
            Write-Host "  → Run with -ScriptType Graph for Graph files" -ForegroundColor Cyan
        }
        if ($hasDevOnly) {
            Write-Host "  → scripts/ folder changes stay on PAX branch only (not synced to release)" -ForegroundColor Magenta
        }
        Write-Host ""
    }
    
    $response = Read-Host "Continue and commit ONLY the $ScriptType files listed above? [y/N]"
    if ($response -notmatch "^[Yy]$") {
        Write-Error "Aborting - no files committed"
        exit 1
    }
    
    return $fileCategories
}

# Function to sync files from PAX branch to release worktree based on ScriptType
function Sync-ReleaseWorktreeFiles {
    param(
        [string]$ReleaseWorktreePath,
        [string]$ScriptType,
        [string]$NewVersion
    )
    
    Write-Status "Syncing files to release worktree (ScriptType: $ScriptType)..."
    
    # Core root files (governance) - ONLY for Umbrella releases
    $coreFiles = @{
        ".gitattributes" = ".gitattributes"
        ".github/workflows/build-release.yml" = ".github/workflows/build-release.yml"
        "CODE_OF_CONDUCT.md" = "CODE_OF_CONDUCT.md"
        "CONTRIBUTORS.md" = "CONTRIBUTORS.md"
        "LICENSE" = "LICENSE"
        "README.md" = "README.md"
        "SECURITY.md" = "SECURITY.md"
    }
    
    $filesToSync = @{}
    
    # Add core files ONLY for Umbrella (root governance files = PAX branding only)
    if ($ScriptType -eq "Umbrella") {
        $coreFiles.GetEnumerator() | ForEach-Object { $filesToSync[$_.Key] = $_.Value }
    }
    
    # Add script-specific files (scripts in root = product branding)
    if ($ScriptType -eq "Purview") {
        # Find the current versioned Purview script file
        $scriptPattern = "PAX_Purview_Audit_Log_Processor_v*.ps1"
        $currentScript = Get-ChildItem -Path $scriptPattern -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($currentScript) {
            $filesToSync[$currentScript.Name] = $currentScript.Name
            Write-Status "Found Purview script: $($currentScript.Name)"
        }
        
        # PDF is archived to release_documentation folder, NOT synced to root
    }
    elseif ($ScriptType -eq "Graph") {
        # Find the current versioned Graph script file
        $scriptPattern = "PAX_Graph_Audit_Log_Processor_v*.ps1"
        $currentScript = Get-ChildItem -Path $scriptPattern -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($currentScript) {
            $filesToSync[$currentScript.Name] = $currentScript.Name
            Write-Status "Found Graph script: $($currentScript.Name)"
        }
        
        # PDF is archived to release_documentation folder, NOT synced to root
    }
    # Umbrella type only syncs core files (already added above)
    
    # Copy individual files
    foreach ($sourceFile in $filesToSync.Keys) {
        $destFile = $filesToSync[$sourceFile]
        $sourcePath = Join-Path (Get-Location) $sourceFile
        $destPath = Join-Path $ReleaseWorktreePath $destFile
        
        if (Test-Path $sourcePath) {
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Write-Success "✓ Synced $destFile"
        }
        else {
            Write-Warning "Source file not found: $sourceFile (skipping)"
        }
    }
    
    # Sync product subfolders based on script type
    # Umbrella does NOT sync product subfolders (only parent .gitkeep files via Add-VersionMarkers)
    # Purview syncs Purview subfolders only
    # Graph syncs Graph subfolders only
    
    if ($ScriptType -eq "Purview") {
        # Sync Purview documentation folder
        $sourceDocFolder = "release_documentation\Purview_Audit_Log_Processor"
        $destDocFolder = Join-Path $ReleaseWorktreePath $sourceDocFolder
        if (Test-Path $sourceDocFolder) {
            if (-not (Test-Path $destDocFolder)) {
                New-Item -ItemType Directory -Path $destDocFolder -Recurse -Force | Out-Null
            }
            # Copy entire folder structure (MD and PDF subfolders)
            Get-ChildItem -Path $sourceDocFolder -Recurse -File | ForEach-Object {
                $relativePath = $_.FullName.Substring((Get-Location).Path.Length + 1)
                $destPath = Join-Path $ReleaseWorktreePath $relativePath
                $destDir = Split-Path $destPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -Path $_.FullName -Destination $destPath -Force
                Write-Success "✓ Synced $relativePath"
            }
        }
        
        # Sync Purview release notes folder
        $sourceNotesFolder = "release_notes\Purview_Audit_Log_Processor"
        $destNotesFolder = Join-Path $ReleaseWorktreePath $sourceNotesFolder
        if (Test-Path $sourceNotesFolder) {
            if (-not (Test-Path $destNotesFolder)) {
                New-Item -ItemType Directory -Path $destNotesFolder -Force | Out-Null
            }
            Get-ChildItem -Path $sourceNotesFolder -File | ForEach-Object {
                $relativePath = $_.FullName.Substring((Get-Location).Path.Length + 1)
                $destPath = Join-Path $ReleaseWorktreePath $relativePath
                Copy-Item -Path $_.FullName -Destination $destPath -Force
                Write-Success "✓ Synced $relativePath"
            }
        }
        
        # Sync Purview script archive folder
        $sourceArchiveFolder = "script_archive\Purview_Audit_Log_Processor"
        $destArchiveFolder = Join-Path $ReleaseWorktreePath $sourceArchiveFolder
        if (Test-Path $sourceArchiveFolder) {
            if (-not (Test-Path $destArchiveFolder)) {
                New-Item -ItemType Directory -Path $destArchiveFolder -Force | Out-Null
            }
            Get-ChildItem -Path $sourceArchiveFolder -File | ForEach-Object {
                $relativePath = $_.FullName.Substring((Get-Location).Path.Length + 1)
                $destPath = Join-Path $ReleaseWorktreePath $relativePath
                Copy-Item -Path $_.FullName -Destination $destPath -Force
                Write-Success "✓ Synced $relativePath"
            }
        }
    }
    
    if ($ScriptType -eq "Graph") {
        # Sync Graph documentation folder
        $sourceDocFolder = "release_documentation\Graph_Audit_Log_Processor"
        $destDocFolder = Join-Path $ReleaseWorktreePath $sourceDocFolder
        if (Test-Path $sourceDocFolder) {
            if (-not (Test-Path $destDocFolder)) {
                New-Item -ItemType Directory -Path $destDocFolder -Recurse -Force | Out-Null
            }
            Get-ChildItem -Path $sourceDocFolder -Recurse -File | ForEach-Object {
                $relativePath = $_.FullName.Substring((Get-Location).Path.Length + 1)
                $destPath = Join-Path $ReleaseWorktreePath $relativePath
                $destDir = Split-Path $destPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -Path $_.FullName -Destination $destPath -Force
                Write-Success "✓ Synced $relativePath"
            }
        }
        
        # Sync Graph release notes folder
        $sourceNotesFolder = "release_notes\Graph_Audit_Log_Processor"
        $destNotesFolder = Join-Path $ReleaseWorktreePath $sourceNotesFolder
        if (Test-Path $sourceNotesFolder) {
            if (-not (Test-Path $destNotesFolder)) {
                New-Item -ItemType Directory -Path $destNotesFolder -Force | Out-Null
            }
            Get-ChildItem -Path $sourceNotesFolder -File | ForEach-Object {
                $relativePath = $_.FullName.Substring((Get-Location).Path.Length + 1)
                $destPath = Join-Path $ReleaseWorktreePath $relativePath
                Copy-Item -Path $_.FullName -Destination $destPath -Force
                Write-Success "✓ Synced $relativePath"
            }
        }
        
        # Sync Graph script archive folder
        $sourceArchiveFolder = "script_archive\Graph_Audit_Log_Processor"
        $destArchiveFolder = Join-Path $ReleaseWorktreePath $sourceArchiveFolder
        if (Test-Path $sourceArchiveFolder) {
            if (-not (Test-Path $destArchiveFolder)) {
                New-Item -ItemType Directory -Path $destArchiveFolder -Force | Out-Null
            }
            Get-ChildItem -Path $sourceArchiveFolder -File | ForEach-Object {
                $relativePath = $_.FullName.Substring((Get-Location).Path.Length + 1)
                $destPath = Join-Path $ReleaseWorktreePath $relativePath
                Copy-Item -Path $_.FullName -Destination $destPath -Force
                Write-Success "✓ Synced $relativePath"
            }
        }
    }
    
    # Clean up old versioned files in release worktree root (keep only current version)
    if ($ScriptType -eq "Purview") {
        # Clean up old Purview scripts
        $scriptFilename = (Get-ChildItem -Path "PAX_Purview_Audit_Log_Processor_v*.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1).Name
        if ($scriptFilename) {
            Get-ChildItem -Path "$ReleaseWorktreePath/PAX_Purview_Audit_Log_Processor_v*.ps1" -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -ne $scriptFilename } | 
                ForEach-Object {
                    Remove-Item $_.FullName -Force
                    Write-Status "Removed old Purview script version: $($_.Name)"
                }
        }
        
        # PDFs are in release_documentation folder, not root - no cleanup needed here
    }
    elseif ($ScriptType -eq "Graph") {
        # Clean up old Graph scripts
        $scriptFilename = (Get-ChildItem -Path "PAX_Graph_Audit_Log_Processor_v*.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1).Name
        if ($scriptFilename) {
            Get-ChildItem -Path "$ReleaseWorktreePath/PAX_Graph_Audit_Log_Processor_v*.ps1" -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -ne $scriptFilename } | 
                ForEach-Object {
                    Remove-Item $_.FullName -Force
                    Write-Status "Removed old Graph script version: $($_.Name)"
                }
        }
        
        # PDFs are in release_documentation folder, not root - no cleanup needed here
    }
    # Umbrella type doesn't have versioned scripts to clean up
    
    return $true
}

# Function to add version markers to files to ensure they're included in commits
function Add-VersionMarkers {
    param(
        [string]$CommitMessage,
        [string]$ReleaseWorktreePath
    )
    
    Write-Status "Adding version markers to ensure files are committed..."
    
    Push-Location $ReleaseWorktreePath
    try {
        # Determine commit type from commit message
        $isUmbrellaCommit = $CommitMessage -match "^PAX-v"
        $isPurviewCommit = $CommitMessage -match "^purview-v"
        $isGraphCommit = $CommitMessage -match "^graph-v"
        
        # ALWAYS update parent folder .gitkeep files with "PAX Solution Set" headers
        # This ensures parent folders always show PAX commit messages, regardless of ScriptType
        if (Test-Path "release_documentation\.gitkeep") {
            "# PAX Solution Set - Release Documentation`n" | Out-File -FilePath "release_documentation\.gitkeep" -Encoding utf8
        }
        
        if (Test-Path "release_notes\.gitkeep") {
            "# PAX Solution Set - Release Notes`n" | Out-File -FilePath "release_notes\.gitkeep" -Encoding utf8
        }
        
        if (Test-Path "script_archive\.gitkeep") {
            "# PAX Script Archive`n" | Out-File -FilePath "script_archive\.gitkeep" -Encoding utf8
        }
        
        # Add markers to governance files ONLY for Umbrella commits
        if ($isUmbrellaCommit) {
            $governanceFiles = @("CODE_OF_CONDUCT.md", "CONTRIBUTORS.md", "SECURITY.md")
            foreach ($file in $governanceFiles) {
                if (Test-Path $file) {
                    "`n<!-- $CommitMessage -->" | Out-File -FilePath $file -Encoding utf8 -Append
                }
            }
            
            # Add marker to LICENSE (uses # comment)
            if (Test-Path "LICENSE") {
                "`n# $CommitMessage" | Out-File -FilePath "LICENSE" -Encoding utf8 -Append
            }
            
            # Add marker to .gitattributes
            if (Test-Path ".gitattributes") {
                # Check if header already exists
                $content = Get-Content ".gitattributes" -Raw
                if ($content -notmatch "^# PAX Solution Set") {
                    "# PAX Solution Set - Git Attributes`n$content" | Out-File -FilePath ".gitattributes" -Encoding utf8 -NoNewline
                }
            }
        }
        
        # For Purview commits, add version comment to script and update subfolder .gitkeep files
        if ($isPurviewCommit) {
            $purviewScript = Get-ChildItem -Path "PAX_Purview_Audit_Log_Processor_v*.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($purviewScript) {
                $version = if ($CommitMessage -match "purview-v([\d\.]+)") { $matches[1] }
                if ($version) {
                    "`n# Updated: v$version" | Out-File -FilePath $purviewScript.Name -Encoding utf8 -Append
                }
            }
            
            # Update Purview subfolder .gitkeep files to show purview-vx.x.x
            if (Test-Path "release_documentation\Purview_Audit_Log_Processor\.gitkeep") {
                "# Purview Audit Log Processor - Release Documentation`n" | Out-File -FilePath "release_documentation\Purview_Audit_Log_Processor\.gitkeep" -Encoding utf8
            }
            if (Test-Path "release_notes\Purview_Audit_Log_Processor\.gitkeep") {
                "# Purview Audit Log Processor - Release Notes`n" | Out-File -FilePath "release_notes\Purview_Audit_Log_Processor\.gitkeep" -Encoding utf8
            }
            if (Test-Path "script_archive\Purview_Audit_Log_Processor\.gitkeep") {
                "# Purview Audit Log Processor - Script Archive`n" | Out-File -FilePath "script_archive\Purview_Audit_Log_Processor\.gitkeep" -Encoding utf8
            }
        }
        
        # For Graph commits, add version comment to script and update subfolder .gitkeep files
        if ($isGraphCommit) {
            $graphScript = Get-ChildItem -Path "PAX_Graph_Audit_Log_Processor_v*.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($graphScript) {
                $version = if ($CommitMessage -match "graph-v([\d\.]+)") { $matches[1] }
                if ($version) {
                    "`n# Updated: v$version" | Out-File -FilePath $graphScript.Name -Encoding utf8 -Append
                }
            }
            
            # Update Graph subfolder .gitkeep files to show graph-vx.x.x
            if (Test-Path "release_documentation\Graph_Audit_Log_Processor\.gitkeep") {
                "# Graph Audit Log Processor - Release Documentation`n" | Out-File -FilePath "release_documentation\Graph_Audit_Log_Processor\.gitkeep" -Encoding utf8
            }
            if (Test-Path "release_notes\Graph_Audit_Log_Processor\.gitkeep") {
                "# Graph Audit Log Processor - Release Notes`n" | Out-File -FilePath "release_notes\Graph_Audit_Log_Processor\.gitkeep" -Encoding utf8
            }
            if (Test-Path "script_archive\Graph_Audit_Log_Processor\.gitkeep") {
                "# Graph Audit Log Processor - Script Archive`n" | Out-File -FilePath "script_archive\Graph_Audit_Log_Processor\.gitkeep" -Encoding utf8
            }
        }
        
        Write-Success "Version markers added"
    }
    finally {
        Pop-Location
    }
}

# Function to sync release branch with customer-facing files
function Sync-ReleaseBranch {
    param(
        [string]$NewVersion,
        [string]$ScriptType,
        [string]$CommitMessage
    )
    
    # Determine source markdown file and PDF filename based on ScriptType
    if ($ScriptType -eq "Purview") {
        $mdFilename = "PAX_Purview_Audit_Log_Processor_Documentation_v${NewVersion}.md"
        $mdPath = "release_documentation\Purview_Audit_Log_Processor\MD\$mdFilename"
        $pdfFilename = "PAX_Purview_Audit_Log_Processor_Documentation_v${NewVersion}.pdf"
        $docType = "Purview documentation"
    } elseif ($ScriptType -eq "Graph") {
        $mdFilename = "PAX_Graph_Audit_Log_Processor_Documentation_v${NewVersion}.md"
        $mdPath = "release_documentation\Graph_Audit_Log_Processor\MD\$mdFilename"
        $pdfFilename = "PAX_Graph_Audit_Log_Processor_Documentation_v${NewVersion}.pdf"
        $docType = "Graph documentation"
    } else {
        # Umbrella uses README.md
        $mdPath = "README.md"
        $pdfFilename = "PAX_Documentation_v${NewVersion}.pdf"
        $docType = "README.md"
    }
    
    Write-Status "Generating documentation PDF from $docType..."
    
    # Generate PDF from markdown using VS Code Markdown PDF extension
    # Create PDF in TEMP folder to avoid OneDrive security policies
    $readmePath = Join-Path (Get-Location) $mdPath
    
    # Use TEMP folder for PDF generation (outside OneDrive)
    $tempFolder = [System.IO.Path]::GetTempPath()
    $tempReadmePath = Join-Path $tempFolder "README_temp_for_pdf.md"
    $tempPdfPath = Join-Path $tempFolder "README_temp_for_pdf.pdf"
    $finalPdfPath = Join-Path (Get-Location) $pdfFilename
    
    if (Test-Path $readmePath) {
        try {
            # Clean up any old temp files
            if (Test-Path $tempReadmePath) { Remove-Item $tempReadmePath -Force }
            if (Test-Path $tempPdfPath) { Remove-Item $tempPdfPath -Force }
            
            # Copy source markdown to TEMP folder for PDF generation
            Copy-Item $readmePath $tempReadmePath -Force
            Write-Status "Copied $docType to TEMP folder (avoids OneDrive security policies)"
            
            Write-Status "Attempting to generate PDF using VS Code Markdown PDF extension..."
            
            # Open markdown file in VS Code and wait for user to export
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
            Write-Host "║  PDF GENERATION REQUIRED                                       ║" -ForegroundColor Yellow
            Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
            Write-Host "║  Opening $docType copy in VS Code (TEMP folder)...             ║" -ForegroundColor Yellow
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
            
            # Archive PDF to appropriate release_documentation folder based on ScriptType
            if ($ScriptType -eq "Purview") {
                $productFolder = "Purview_Audit_Log_Processor"
                $docDescription = "Purview documentation"
            } elseif ($ScriptType -eq "Graph") {
                $productFolder = "Graph_Audit_Log_Processor"
                $docDescription = "Graph documentation"
            } else {
                # Umbrella uses root release_documentation folder
                $productFolder = ""
                $docDescription = "Umbrella documentation"
            }
            
            Write-Status "Archiving $docDescription to release_documentation\$productFolder..."
            
            if ($productFolder) {
                $releaseDocFolder = Join-Path (Get-Location) "release_documentation\$productFolder"
            } else {
                $releaseDocFolder = Join-Path (Get-Location) "release_documentation"
            }
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
            
            # Archive the current README.md as documentation ONLY for Umbrella releases
            # Purview and Graph have their own product-specific documentation files
            # that should be manually created/updated before release
            if ($ScriptType -eq "Umbrella") {
                $readmeMdFilename = "PAX_Documentation_v${NewVersion}.md"
                $archiveMdPath = Join-Path $releaseDocMdFolder $readmeMdFilename
                if (Test-Path $readmePath) {
                    Copy-Item -Path $readmePath -Destination $archiveMdPath -Force
                    Write-Success "✓ Archived README as Umbrella documentation: MD\$readmeMdFilename"
                } else {
                    Write-Warning "Could not archive README.md - source file not found"
                }
            } else {
                # For Purview/Graph, verify product-specific documentation exists
                if ($ScriptType -eq "Purview") {
                    $expectedDocFile = "PAX_Purview_Audit_Log_Processor_Documentation_v${NewVersion}.md"
                } elseif ($ScriptType -eq "Graph") {
                    $expectedDocFile = "PAX_Graph_Audit_Log_Processor_Documentation_v${NewVersion}.md"
                }
                
                $expectedDocPath = Join-Path $releaseDocMdFolder $expectedDocFile
                if (Test-Path $expectedDocPath) {
                    Write-Success "✓ Found product documentation: MD\$expectedDocFile"
                } else {
                    Write-Warning "⚠️  Product-specific documentation not found: MD\$expectedDocFile"
                    Write-Warning "   Please create this file manually before release"
                    Write-Warning "   README.md is NOT copied for Purview/Graph releases"
                }
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
        $ReleaseWorktreePath = $null
        $worktrees | ForEach-Object {
            if ($_ -match "^\s*(.+?)\s+[a-f0-9]+\s+\[release\]") {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
                $ReleaseWorktreePath = $matches[1].Trim()
            }
        }
        
        if (-not $ReleaseWorktreePath -or -not (Test-Path $ReleaseWorktreePath)) {
            Write-Warning "Release worktree not found. Run: git worktree add `"..\PAX App-release`" release"
            return
        }
        
        Write-Status "Release worktree location: $ReleaseWorktreePath"
        
        # Sync files from PAX to release worktree using ScriptType-aware function
        if (-not (Sync-ReleaseWorktreeFiles -ReleaseWorktreePath $ReleaseWorktreePath -ScriptType $ScriptType -NewVersion $NewVersion)) {
            Write-Error "Failed to sync files to release worktree"
            return
        }
        
        # Navigate to release worktree and commit changes
        Push-Location $releaseWorktreePath
        try {
            # Check if there are changes
            $changes = git status --porcelain
            if ($changes) {
                Write-Status "Changes detected in release worktree:"
                $changes | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
                
                # Stage and commit changes with formatted commit message
                git add .
                git commit -m $CommitMessage
                Write-Success "Committed changes to release branch: $CommitMessage"
                
                # AFTER product commit, update parent folders with PAX headers in separate commit
                # This ensures parent folders always show PAX-vX.X.X instead of product version
                Add-VersionMarkers -CommitMessage $CommitMessage -ReleaseWorktreePath $releaseWorktreePath
                
                # Check if version markers created changes
                $markerChanges = git status --porcelain
                if ($markerChanges) {
                    # Get current PAX version for parent folder commit
                    $paxVersion = Get-CurrentVersion -ScriptType "Umbrella"
                    $parentCommitMsg = "PAX-v$paxVersion"
                    
                    Write-Status "Committing parent folder updates with: $parentCommitMsg"
                    git add .
                    git commit -m $parentCommitMsg
                    Write-Success "Committed parent folder markers: $parentCommitMsg"
                }
                
                # Push release branch to Rance9/PAX (backup) with force - no protection
                Write-Status "Pushing release branch to Rance9/PAX..."
                git push backup release -f 2>$null
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
                # Add a newline to all root files to force a git change
                "`n" | Add-Content -Path $_.FullName -NoNewline
            }
            Write-Success "✓ Updated directory and file timestamps in release branch"
            
            # Stage and commit product files first
            git add . 2>$null
            $changes = git diff --cached --name-only
            if ($changes) {
                git commit -m $CommitMessage
                Write-Success "Committed changes to release branch: $CommitMessage"
                
                # AFTER product commit, update parent folders with PAX headers in separate commit
                $currentPath = Get-Location
                Add-VersionMarkers -CommitMessage $CommitMessage -ReleaseWorktreePath $currentPath
                
                # Check if version markers created changes
                $markerChanges = git status --porcelain
                if ($markerChanges) {
                    # Get current PAX version for parent folder commit
                    $paxVersion = Get-CurrentVersion -ScriptType "Umbrella"
                    $parentCommitMsg = "PAX-v$paxVersion"
                    
                    Write-Status "Committing parent folder updates with: $parentCommitMsg"
                    git add .
                    git commit -m $parentCommitMsg
                    Write-Success "Committed parent folder markers: $parentCommitMsg"
                }
                
                # Push release branch to Rance9/PAX (backup) with force - no protection
                Write-Status "Pushing release branch to Rance9/PAX..."
                git push backup release -f 2>$null
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
        [string]$CustomMessage,
        [string]$ScriptType,
        [hashtable]$FileCategories
    )
    
    # Generate commit message based on ScriptType
    $commitMsg = switch ($ScriptType) {
        "Umbrella" { "PAX-v${NewVersion}" }
        "Purview"  { "purview-v${NewVersion}" }
        "Graph"    { "graph-v${NewVersion}" }
        default    { "v${NewVersion}" }
    }
    
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
        # Add a newline to all root files to force a git change
        "`n" | Add-Content -Path $_.FullName -NoNewline
    }
    Write-Success "✓ Updated directory and file timestamps"
    
    # Stage only the relevant files based on ScriptType
    Write-Status "Staging $ScriptType files for commit..."
    foreach ($fileStatus in $FileCategories.Relevant) {
        # Parse git status format: "XY filename" (2 status chars + space + filename)
        $file = ""
        
        if ($fileStatus -match '->') {
            # Rename: "R  old -> new" - stage both old and new
            $parts = $fileStatus -split '->'
            $oldFile = ($parts[0].Substring(3)).Trim()
            $newFile = $parts[1].Trim()
            git add $oldFile $newFile 2>$null
            Write-Status "Staged rename: $oldFile -> $newFile"
        } else {
            # Regular change: " M filename" - skip first 3 chars (space + status + space)
            $file = $fileStatus.Substring(3)
            git add $file 2>$null
            Write-Status "Staged: $file"
        }
    }
    
    # Also stage .gitkeep files that were just created/updated
    git add **/.gitkeep 2>$null
    Write-Status "Staged .gitkeep files"
    
    # Commit the changes
    git commit -m $commitMsg
    Write-Success "Created commit: $commitMsg"
    
    # Create appropriate tag based on script type
    if ($ScriptType -eq "Purview") {
        $tagName = "purview-v$NewVersion"
    } elseif ($ScriptType -eq "Graph") {
        $tagName = "graph-v$NewVersion"
    } else {
        $tagName = "PAX-v$NewVersion"
    }
    
    git tag $tagName
    Write-Success "Created tag: $tagName"
    
    # Push changes and tag to both repositories (PAX branch)
    Write-Status "Pushing PAX branch and tag to both repositories..."
    git push origin PAX 2>$null
    git push origin $tagName 2>$null
    git push backup PAX
    git push backup $tagName
    Write-Success "Pushed PAX branch and tag to both GitHub repositories"
    
    # Create GitHub release for product releases (not umbrella)
    if ($ScriptType -ne "Umbrella") {
        Write-Status "Creating GitHub release for $tagName..."
        
        # Get GitHub CLI command
        $gh = Get-GitHubCLI
        if ($gh) {
            # Determine script file path for asset
            if ($ScriptType -eq "Purview") {
                $scriptFile = "PAX_Purview_Audit_Log_Processor_v${NewVersion}.ps1"
            } elseif ($ScriptType -eq "Graph") {
                $scriptFile = "PAX_Graph_Audit_Log_Processor_v${NewVersion}.ps1"
            }
            
            # Get release notes file path
            $releaseNotesPath = "release_notes\${ScriptType}_Audit_Log_Processor\${scriptName}_Release_Note_v${NewVersion}.md"
            
            # Create release with script file as asset
            if (Test-Path $scriptFile) {
                $releaseTitle = "${ScriptType} Audit Log Processor v${NewVersion}"
                $releaseNotes = if (Test-Path $releaseNotesPath) {
                    Get-Content $releaseNotesPath -Raw
                } else {
                    "Release v${NewVersion}"
                }
                
                & $gh release create $tagName $scriptFile `
                    --repo microsoft/PAX `
                    --title $releaseTitle `
                    --notes $releaseNotes `
                    --target release 2>$null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "✓ Created GitHub release: $releaseTitle"
                    Write-Success "✓ Attached asset: $scriptFile"
                } else {
                    Write-Warning "Failed to create GitHub release (may already exist)"
                }
            } else {
                Write-Warning "Script file not found: $scriptFile (skipping release creation)"
            }
        } else {
            Write-Warning "GitHub CLI not found - skipping GitHub release creation"
            Write-Host "  To create release manually: gh release create $tagName --repo microsoft/PAX" -ForegroundColor Yellow
        }
    }
    
    # Now sync the release branch with customer-facing files
    Sync-ReleaseBranch -NewVersion $NewVersion -ScriptType $ScriptType -CommitMessage $commitMsg
}

# Function to show summary
function Show-Summary {
    param(
        [string]$OldVersion,
        [string]$NewVersion,
        [string]$BumpType,
        [string]$CommitMessage,
        [string]$ScriptType = "Umbrella"
    )
    
    # Determine tag name based on script type
    if ($ScriptType -eq "Purview") {
        $tagName = "purview-v$NewVersion"
    } elseif ($ScriptType -eq "Graph") {
        $tagName = "graph-v$NewVersion"
    } else {
        $tagName = "PAX-v$NewVersion"
    }
    
    Write-Host ""
    Write-Host "🎉 Release Summary" -ForegroundColor Green
    Write-Host "==================" -ForegroundColor Green
    Write-Host "• Old version: " -NoNewline; Write-Host "v$OldVersion" -ForegroundColor Yellow
    Write-Host "• New version: " -NoNewline; Write-Host "v$NewVersion" -ForegroundColor Yellow
    Write-Host "• Bump type:   " -NoNewline; Write-Host "$BumpType" -ForegroundColor Yellow
    Write-Host "• Git tag:     " -NoNewline; Write-Host "$tagName" -ForegroundColor Yellow
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
    
    Write-Status "Starting $bumpType version bump for $ScriptType..."
    
    # Validate environment and get file categories
    $fileCategories = Test-GitStatus -ScriptType $ScriptType
    
    # Clean up old temporary branches
    Remove-OldTempBranches
    
    # Get current version based on ScriptType
    $currentVersion = Get-CurrentVersion -ScriptType $ScriptType
    Write-Status "Current version: v$currentVersion"
    
    # Calculate new version
    $newVersion = Step-Version -CurrentVersion $currentVersion -BumpType $bumpType
    Write-Status "New version: v$newVersion"
    
    # Generate commit message based on ScriptType
    $commitMsg = switch ($ScriptType) {
        "Umbrella" { "PAX-v${newVersion}" }
        "Purview"  { "purview-v${newVersion}" }
        "Graph"    { "graph-v${newVersion}" }
    }
    
    # Prepare commit message
    $finalCommitMsg = if ($Message) {
        "${commitMsg}: $Message"
    }
    else {
        $commitMsg
    }
    
    # Confirm with user
    Write-Host ""
    Write-Host "About to bump version:" -ForegroundColor Yellow
    Write-Host "  ScriptType: " -NoNewline; Write-Host "$ScriptType" -ForegroundColor Cyan
    Write-Host "  From:       " -NoNewline; Write-Host "v$currentVersion" -ForegroundColor Cyan
    Write-Host "  To:         " -NoNewline; Write-Host "v$newVersion" -ForegroundColor Cyan
    Write-Host "  Type:       " -NoNewline; Write-Host "$bumpType" -ForegroundColor Cyan
    Write-Host "  Commit Msg: " -NoNewline; Write-Host "$finalCommitMsg" -ForegroundColor Cyan
    Write-Host "  Notes:      " -NoNewline; Write-Host "$ReleaseNotes" -ForegroundColor Cyan
    Write-Host ""
    $response = Read-Host "Continue? [Y/n]"
    if ($response -match "^[Nn]$") {
        Write-Warning "Version bump cancelled by user"
        return
    }
    
    # Update version files
    Write-Status "Updating version files..."
    
    # ALWAYS update the versions.json manifest first (Single Source of Truth)
    Update-VersionsManifest -ScriptType $ScriptType -NewVersion $newVersion
    
    # Update package.json, tauri.conf.json, and Cargo.toml ONLY for Umbrella releases
    # (These are for the PAX Tauri app which is currently on back burner)
    if ($ScriptType -eq "Umbrella") {
        Update-JsonVersion -FilePath $PackageJson -NewVersion $newVersion
        Update-JsonVersion -FilePath $TauriConf -NewVersion $newVersion
        Update-CargoVersion -FilePath $CargoToml -NewVersion $newVersion
    }
    
    # Update script version and README for Purview/Graph releases
    Update-ExportScriptVersion -NewVersion $newVersion -ScriptType $ScriptType
    Update-ReadmeVersion -FilePath "README.md" -NewVersion $newVersion -ScriptType $ScriptType
    
    # Generate release notes file
    Write-Status "Generating release notes..."
    $releaseNotesFile = New-ReleaseNotesFile -NewVersion $newVersion -ReleaseDescription $ReleaseNotes -ScriptType $ScriptType
    Write-Success "Release notes saved to: $releaseNotesFile"
    
    # Commit and tag
    Write-Status "Creating git commit and tag..."
    New-CommitAndTag -NewVersion $newVersion -BumpType $bumpType -CustomMessage $Message -ScriptType $ScriptType -FileCategories $fileCategories
    
    # Show summary
    Show-Summary -OldVersion $currentVersion -NewVersion $newVersion -BumpType $bumpType -CommitMessage $finalCommitMsg -ScriptType $ScriptType
    
    Write-Success "Release process completed successfully! 🎉"
}

# Run the main function
Main

