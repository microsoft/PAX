# PAX Branch Sync Script
# Commits changes to PAX branch and syncs to release branch via PR
# Supports both Purview and Graph script versioning conventions

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Umbrella', 'Purview', 'Graph')]
    [string]$ScriptType,
    
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$Description = "",
    
    [switch]$Help
)

# Script configuration
$ScriptName = "PAX Branch Sync Script"

# Change to repository root (parent of scripts folder)
$ScriptRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ScriptRoot

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

function Write-Header {
    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "  $ScriptName" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
}

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\sync-branches.ps1 -ScriptType <Umbrella|Purview|Graph> -Version <version> [-Description <description>]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -ScriptType     Type of changes (Umbrella, Purview, or Graph) [REQUIRED]"
    Write-Host "  -Version        Version number (e.g., '1.0.0') [REQUIRED]"
    Write-Host "  -Description    Description of changes (optional)"
    Write-Host "  -Help           Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\sync-branches.ps1 -ScriptType Umbrella -Version '1.0.0' -Description 'Added sync script'"
    Write-Host "  .\sync-branches.ps1 -ScriptType Purview -Version '1.7.0' -Description 'Documentation fixes'"
    Write-Host "  .\sync-branches.ps1 -ScriptType Graph -Version '0.1.0' -Description 'Initial placeholder'"
    Write-Host ""
    Write-Host "Commit Message Format:"
    Write-Host "  Umbrella: PAX-v1.0.0"
    Write-Host "  Purview:  purview-v1.7.0"
    Write-Host "  Graph:    graph-v0.1.0"
    Write-Host ""
    Write-Host "File Categories:"
    Write-Host "  Umbrella - Core root files (.gitattributes, LICENSE, README.md, etc.) and shared folders"
    Write-Host "             (Includes: .github, release_documentation, release_notes, script_archive parent folders)"
    Write-Host "             (Excludes: scripts/ folder - dev-only, stays on PAX branch)"
    Write-Host "  Purview  - Purview script, README-Purview.md, and Purview_Audit_Log_Processor subfolders"
    Write-Host "  Graph    - Graph script, README-Graph.md, and Graph_Audit_Log_Processor subfolders"
    Write-Host ""
}

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
    Write-Host "Files to commit for $ScriptType (v${Version}):" -ForegroundColor Green
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

# Function to validate worktree setup
function Test-WorktreeSetup {
    Write-Status "Validating worktree setup..."
    
    $worktrees = git worktree list 2>$null
    $releaseWorktree = $worktrees | Where-Object { $_ -match "\[release\]" }
    
    if (-not $releaseWorktree) {
        Write-Error "Release worktree not found!"
        Write-Host ""
        Write-Host "Please set up the release worktree:" -ForegroundColor Yellow
        Write-Host "  git worktree add `"..\PAX App-release`" release" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }
    
    # Extract worktree path
    $releaseWorktreePath = $null
    $worktrees | ForEach-Object {
        if ($_ -match "^\s*(.+?)\s+[a-f0-9]+\s+\[release\]") {
            $releaseWorktreePath = $matches[1].Trim()
        }
    }
    
    if (-not (Test-Path $releaseWorktreePath)) {
        Write-Error "Release worktree path not found: $releaseWorktreePath"
        exit 1
    }
    
    Write-Success "Release worktree found: $releaseWorktreePath"
    return $releaseWorktreePath
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
        $line = $change.Trim()
        $file = ""
        
        if ($line -match '->') {
            # Rename: "R  old -> new"
            $file = ($line -split '->')[1].Trim()
        } else {
            # Regular change: "M  filename" or "A  filename"
            $file = $line.Substring(3).Trim()
        }
        
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

# Function to commit changes to PAX branch
function Submit-PAXBranchChanges {
    param(
        [string]$CommitMessage,
        [array]$FilesToCommit
    )
    
    Write-Status "Committing changes to PAX branch..."
    
    # Stage only the relevant files
    foreach ($fileStatus in $FilesToCommit) {
        # Parse git status format to get actual filename
        $line = $fileStatus.Trim()
        $file = ""
        
        if ($line -match '->') {
            # Rename: "R  old -> new" - stage both old and new
            $parts = $line -split '->'
            $oldFile = ($parts[0] -replace '^.\s+', '').Trim()
            $newFile = $parts[1].Trim()
            git add $oldFile $newFile 2>$null
            Write-Status "Staged rename: $oldFile -> $newFile"
        } else {
            # Regular change: "M  filename" or "A  filename" or "D  filename"
            $file = $line.Substring(3).Trim()
            git add $file 2>$null
            Write-Status "Staged: $file"
        }
    }
    
    # Commit with formatted message
    git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to commit changes"
        return $false
    }
    Write-Success "Created commit: $CommitMessage"
    
    return $true
}

# Function to push PAX branch to both repositories
function Publish-PAXBranch {
    Write-Status "Pushing PAX branch to both repositories..."
    
    # Push to microsoft/PAX (origin)
    git push origin PAX 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push to microsoft/PAX"
        return $false
    }
    Write-Success "Pushed to microsoft/PAX"
    
    # Push to Rance9/PAX (backup)
    git push backup PAX 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push to Rance9/PAX"
        return $false
    }
    Write-Success "Pushed to Rance9/PAX"
    
    return $true
}

# Function to sync files to release worktree
function Sync-ReleaseWorktreeFiles {
    param(
        [string]$ReleaseWorktreePath,
        [string]$ScriptType
    )
    
    Write-Status "Syncing files to release worktree..."
    
    # Determine which script pattern to look for
    $scriptPattern = if ($ScriptType -eq "Purview") {
        "PAX_Purview_Audit_Log_Processor_v*.ps1"
    } else {
        "PAX_Graph_Audit_Log_Processor_v*.ps1"
    }
    
    # Find the current versioned script file dynamically in root
    $currentScript = Get-ChildItem -Path $scriptPattern -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $currentScript) {
        Write-Warning "No $ScriptType script found matching pattern: $scriptPattern"
        $scriptFilename = $null
    } else {
        $scriptFilename = $currentScript.Name
        Write-Status "Found script to sync: $scriptFilename"
    }
    
    # Define customer-facing files to sync
    $filesToSync = @(
        ".gitattributes",
        ".github/workflows/build-release.yml",
        "CODE_OF_CONDUCT.md",
        "CONTRIBUTORS.md",
        "LICENSE",
        "README.md",              # Umbrella overview
        "README-Purview.md",      # Purview-specific detailed docs
        "README-Graph.md",        # Graph-specific detailed docs (when available)
        "SECURITY.md"
    )
    # NOTE: scripts/ folder is intentionally excluded - it's dev-only (PAX branch)
    
    # Add script if found
    if ($scriptFilename) {
        $filesToSync += $scriptFilename
    }
    
    # Copy individual files from PAX to release worktree
    $copiedFiles = @()
    foreach ($sourceFile in $filesToSync) {
        $sourcePath = Join-Path (Get-Location) $sourceFile
        $destPath = Join-Path $ReleaseWorktreePath $sourceFile
        
        if (Test-Path $sourcePath) {
            # Create destination directory if needed
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            # Copy file
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            $copiedFiles += $sourceFile
            Write-Success "✓ Synced $sourceFile"
        }
        else {
            Write-Warning "Source file not found: $sourceFile (skipping)"
        }
    }
    
    # Sync release_documentation folder (entire directory)
    $releaseDocFolder = "release_documentation"
    $sourceDocPath = Join-Path (Get-Location) $releaseDocFolder
    $destDocPath = Join-Path $ReleaseWorktreePath $releaseDocFolder
    
    if (Test-Path $sourceDocPath) {
        Write-Status "Syncing $releaseDocFolder folder..."
        
        # Ensure destination folder exists
        if (-not (Test-Path $destDocPath)) {
            New-Item -ItemType Directory -Path $destDocPath -Force | Out-Null
        }
        
        # Copy all subdirectories and files recursively
        Get-ChildItem -Path $sourceDocPath -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Substring($sourceDocPath.Length + 1)
            $destItemPath = Join-Path $destDocPath $relativePath
            
            if ($_.PSIsContainer) {
                # Create directory
                if (-not (Test-Path $destItemPath)) {
                    New-Item -ItemType Directory -Path $destItemPath -Force | Out-Null
                }
            } else {
                # Copy file
                $destItemDir = Split-Path $destItemPath -Parent
                if (-not (Test-Path $destItemDir)) {
                    New-Item -ItemType Directory -Path $destItemDir -Force | Out-Null
                }
                Copy-Item -Path $_.FullName -Destination $destItemPath -Force
            }
        }
        Write-Success "✓ Synced $releaseDocFolder folder"
    }
    
    # Sync release_notes folder (entire directory)
    $releaseNotesFolder = "release_notes"
    $sourceNotesPath = Join-Path (Get-Location) $releaseNotesFolder
    $destNotesPath = Join-Path $ReleaseWorktreePath $releaseNotesFolder
    
    if (Test-Path $sourceNotesPath) {
        Write-Status "Syncing $releaseNotesFolder folder..."
        
        # Ensure destination folder exists
        if (-not (Test-Path $destNotesPath)) {
            New-Item -ItemType Directory -Path $destNotesPath -Force | Out-Null
        }
        
        # Copy all subdirectories and files recursively
        Get-ChildItem -Path $sourceNotesPath -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Substring($sourceNotesPath.Length + 1)
            $destItemPath = Join-Path $destNotesPath $relativePath
            
            if ($_.PSIsContainer) {
                # Create directory
                if (-not (Test-Path $destItemPath)) {
                    New-Item -ItemType Directory -Path $destItemPath -Force | Out-Null
                }
            } else {
                # Copy file
                $destItemDir = Split-Path $destItemPath -Parent
                if (-not (Test-Path $destItemDir)) {
                    New-Item -ItemType Directory -Path $destItemDir -Force | Out-Null
                }
                Copy-Item -Path $_.FullName -Destination $destItemPath -Force
            }
        }
        Write-Success "✓ Synced $releaseNotesFolder folder"
    }
    
    # Sync script_archive folder (entire directory)
    $scriptArchiveFolder = "script_archive"
    $sourceArchivePath = Join-Path (Get-Location) $scriptArchiveFolder
    $destArchivePath = Join-Path $ReleaseWorktreePath $scriptArchiveFolder
    
    if (Test-Path $sourceArchivePath) {
        Write-Status "Syncing $scriptArchiveFolder folder..."
        
        # Ensure destination folder exists
        if (-not (Test-Path $destArchivePath)) {
            New-Item -ItemType Directory -Path $destArchivePath -Force | Out-Null
        }
        
        # Copy all subdirectories and files recursively
        Get-ChildItem -Path $sourceArchivePath -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Substring($sourceArchivePath.Length + 1)
            $destItemPath = Join-Path $destArchivePath $relativePath
            
            if ($_.PSIsContainer) {
                # Create directory
                if (-not (Test-Path $destItemPath)) {
                    New-Item -ItemType Directory -Path $destItemPath -Force | Out-Null
                }
            } else {
                # Copy file
                $destItemDir = Split-Path $destItemPath -Parent
                if (-not (Test-Path $destItemDir)) {
                    New-Item -ItemType Directory -Path $destItemDir -Force | Out-Null
                }
                Copy-Item -Path $_.FullName -Destination $destItemPath -Force
            }
        }
        Write-Success "✓ Synced $scriptArchiveFolder folder"
    }
    
    return $true
}

# Function to sync release branch with proper cherry-pick workflow
function Sync-ReleaseBranch {
    param(
        [string]$ReleaseWorktreePath,
        [string]$CommitMessage,
        [string]$PRDescription,
        [string]$ScriptType
    )
    
    Write-Status "Syncing release branch..."
    
    # Navigate to release worktree
    Push-Location $ReleaseWorktreePath
    try {
        # CRITICAL: Fetch latest from microsoft/PAX release branch
        Write-Status "Fetching latest from microsoft/PAX release branch..."
        git fetch origin release 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to fetch from microsoft/PAX release branch"
            return $false
        }
        
        # Get current release commit before reset
        $currentCommit = git rev-parse HEAD
        Write-Status "Current release commit: $currentCommit"
        
        # CRITICAL: Reset local release branch to microsoft/PAX's release branch
        Write-Status "Resetting local release branch to microsoft/PAX's release branch..."
        git reset --hard origin/release
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to reset to origin/release"
            return $false
        }
        Write-Success "Reset to origin/release ($(git rev-parse --short HEAD))"
        
        # Sync files from PAX branch
        if (-not (Sync-ReleaseWorktreeFiles -ReleaseWorktreePath $ReleaseWorktreePath -ScriptType $ScriptType)) {
            Write-Error "Failed to sync files to release worktree"
            return $false
        }
        
        # Check if there are changes after sync
        $changes = git status --porcelain
        if (-not $changes) {
            Write-Status "No changes detected after file sync (already up to date)"
            return $true
        }
        
        Write-Status "Changes detected in release worktree:"
        $changes | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        
        # Stage and commit changes
        git add .
        git commit -m $CommitMessage
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to commit changes to release branch"
            return $false
        }
        
        $newCommit = git rev-parse HEAD
        Write-Success "Committed changes to release branch: $newCommit"
        
        # Push release branch to Rance9/PAX (backup) - no protection
        Write-Status "Pushing release branch to Rance9/PAX..."
        git push backup release -f 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to push to Rance9/PAX release branch"
            return $false
        }
        Write-Success "Pushed release branch to Rance9/PAX"
        
        # For microsoft/PAX, create PR due to branch protection
        Write-Status "Creating PR for microsoft/PAX release branch..."
        
        # Generate temp branch name based on script type and version
        $tempBranchSuffix = $CommitMessage -replace '^(purview|graph)-v', ''
        $tempBranch = if ($ScriptType -eq "Purview") {
            "release-sync-purview-v${tempBranchSuffix}"
        } else {
            "release-sync-graph-v${tempBranchSuffix}"
        }
        
        # Get GitHub CLI command
        $gh = Get-GitHubCLI
        if (-not $gh) {
            Write-Error "Cannot create PR - GitHub CLI not found"
            Write-Status "Skipping PR creation (manual PR required)"
            return $false
        }
        
        # Clean up old temporary branches before creating new one
        Write-Status "Checking for old temporary branches..."
        $oldTempBranches = git ls-remote --heads origin 2>$null | Where-Object { $_ -match "release-sync-(purview|graph)-v" -and $_ -notmatch $tempBranch }
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
        Write-Status "Pushing to temporary branch: $tempBranch"
        git push origin release:$tempBranch -f 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to push to temporary branch"
            return $false
        }
        Write-Success "Pushed to temporary branch: $tempBranch"
        
        # Check if PR already exists
        $existingPR = & $gh pr list --repo microsoft/PAX --base release --head $tempBranch --json number --jq '.[0].number' 2>$null
        
        if ($existingPR) {
            Write-Status "PR already exists: https://github.com/microsoft/PAX/pull/$existingPR"
            Write-Host "`n⚠️  PR already exists. Please review and merge at: https://github.com/microsoft/PAX/pull/$existingPR" -ForegroundColor Yellow
        } else {
            # Create new PR with description
            $prTitle = $CommitMessage
            $prBody = if ($PRDescription) {
                "$PRDescription`n`nCommit: $CommitMessage"
            } else {
                "Automated sync for $CommitMessage`n`nSynced files from PAX branch to release branch."
            }
            
            $prUrl = & $gh pr create --repo microsoft/PAX --base release --head $tempBranch --title $prTitle --body $prBody 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "PR created: $prUrl"
                Write-Host "`n⚠️  ACTION REQUIRED: Please approve and merge the PR at: $prUrl" -ForegroundColor Yellow
            } else {
                Write-Error "Failed to create PR: $prUrl"
                return $false
            }
        }
        
        Write-Success "Release branch sync complete!"
        return $true
    }
    catch {
        Write-Error "Error during release branch sync: $($_.Exception.Message)"
        return $false
    }
    finally {
        Pop-Location
    }
}

# Function to show summary
function Show-Summary {
    param(
        [string]$CommitMessage,
        [string]$ScriptType,
        [string]$Version,
        [string]$Description
    )
    
    Write-Host ""
    Write-Host "🎉 Branch Sync Summary" -ForegroundColor Green
    Write-Host "======================" -ForegroundColor Green
    Write-Host "• Script Type:  " -NoNewline; Write-Host "$ScriptType" -ForegroundColor Yellow
    Write-Host "• Version:      " -NoNewline; Write-Host "$Version" -ForegroundColor Yellow
    Write-Host "• Commit Msg:   " -NoNewline; Write-Host "$CommitMessage" -ForegroundColor Yellow
    if ($Description) {
        Write-Host "• Description:  " -NoNewline; Write-Host "$Description" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "📦 Branches Updated:" -ForegroundColor Cyan
    Write-Host "   ✅ PAX branch (development) - committed and pushed to both repos" -ForegroundColor Green
    Write-Host "   ✅ release branch (customer-facing) - synced via worktree" -ForegroundColor Green
    Write-Host "   ✅ Rance9/PAX release - pushed directly" -ForegroundColor Green
    Write-Host "   ⏳ microsoft/PAX release - PR created (awaiting approval)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🌐 View on GitHub:" -ForegroundColor Cyan
    Write-Host "   • Microsoft (PAX):     https://github.com/microsoft/PAX/tree/PAX" -ForegroundColor Blue
    Write-Host "   • Microsoft (release): https://github.com/microsoft/PAX/pulls" -ForegroundColor Blue
    Write-Host "   • Private (PAX):       https://github.com/Rance9/PAX/tree/PAX" -ForegroundColor Blue
    Write-Host "   • Private (release):   https://github.com/Rance9/PAX/tree/release" -ForegroundColor Blue
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
    
    # Validate parameters
    if (-not $Version) {
        Write-Error "Version parameter is required"
        Show-Usage
        exit 1
    }
    
    # Format commit message based on script type
    $commitMessage = switch ($ScriptType) {
        "Umbrella" { "PAX-v${Version}" }
        "Purview"  { "purview-v${Version}" }
        "Graph"    { "graph-v${Version}" }
    }
    
    Write-Status "Script Type: $ScriptType"
    Write-Status "Version: $Version"
    Write-Status "Commit Message: $commitMessage"
    if ($Description) {
        Write-Status "Description: $Description"
    }
    
    # Validate environment
    Write-Status "Validating git environment..."
    $fileCategories = Test-GitStatus -ScriptType $ScriptType
    
    # Validate worktree setup
    $releaseWorktreePath = Test-WorktreeSetup
    
    # Confirm with user
    Write-Host ""
    Write-Host "About to commit and sync changes:" -ForegroundColor Yellow
    Write-Host "  Type:   " -NoNewline; Write-Host "$ScriptType" -ForegroundColor Cyan
    Write-Host "  Version:" -NoNewline; Write-Host " $Version" -ForegroundColor Cyan
    Write-Host "  Commit: " -NoNewline; Write-Host "$commitMessage" -ForegroundColor Cyan
    if ($Description) {
        Write-Host "  Desc:   " -NoNewline; Write-Host "$Description" -ForegroundColor Cyan
    }
    Write-Host ""
    $response = Read-Host "Continue? [Y/n]"
    if ($response -match "^[Nn]$") {
        Write-Warning "Sync cancelled by user"
        return
    }
    
    # Commit changes to PAX branch
    if (-not (Submit-PAXBranchChanges -CommitMessage $commitMessage -FilesToCommit $fileCategories.Relevant)) {
        Write-Error "Failed to commit changes to PAX branch"
        exit 1
    }
    
    # Push PAX branch to both repositories
    if (-not (Publish-PAXBranch)) {
        Write-Error "Failed to push PAX branch to repositories"
        exit 1
    }
    
    # Sync to release branch and create PR
    if (-not (Sync-ReleaseBranch -ReleaseWorktreePath $releaseWorktreePath -CommitMessage $commitMessage -PRDescription $Description -ScriptType $ScriptType)) {
        Write-Error "Failed to sync release branch"
        exit 1
    }
    
    # Show summary
    Show-Summary -CommitMessage $commitMessage -ScriptType $ScriptType -Version $Version -Description $Description
    
    Write-Success "Branch sync completed successfully! 🎉"
}

# Run the main function
Main
