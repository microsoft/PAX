# PAX Version Bump and Release Script (PowerShell)
# Automatically updates version numbers in package.json, tauri.conf.json, and Cargo.toml
# Commits changes and triggers GitHub release workflow

param(
    [switch]$Patch,
    [switch]$Minor, 
    [switch]$Major,
    [string]$Message,
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

function Write-Header {
    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "  $ScriptName" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
}

# Function to clean up old temporary PR branches
function Remove-OldPRBranches {
    param([string]$Pattern = "release-sync-v*")
    
    Write-Status "Cleaning up old temporary PR branches..."
    
    # Get all remote branches matching the pattern
    $remoteBranches = git ls-remote --heads origin | Where-Object { $_ -match "refs/heads/$Pattern" }
    
    if ($remoteBranches) {
        $branchesToDelete = $remoteBranches | ForEach-Object {
            if ($_ -match "refs/heads/(.+)$") {
                $matches[1]
            }
        }
        
        foreach ($branch in $branchesToDelete) {
            # Check if there's a merged PR for this branch
            $prStatus = gh pr list --repo microsoft/PAX --head $branch --state merged --json number --jq '.[0].number' 2>$null
            
            if ($prStatus) {
                # PR was merged, safe to delete
                Write-Status "Deleting merged temporary branch: $branch"
                git push origin --delete $branch 2>$null
            } else {
                # Check if PR is closed (not merged)
                $closedPR = gh pr list --repo microsoft/PAX --head $branch --state closed --json number --jq '.[0].number' 2>$null
                if ($closedPR) {
                    Write-Status "Deleting closed temporary branch: $branch"
                    git push origin --delete $branch 2>$null
                }
                # If PR is still open, leave the branch alone
            }
        }
        Write-Success "Cleanup complete"
    } else {
        Write-Status "No temporary branches to clean up"
    }
}

# Function to show usage
function Show-Usage {
    Write-Host "Usage: .\release.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Patch     Increment patch version (1.0.21 → 1.0.22) [DEFAULT]"
    Write-Host "  -Minor     Increment minor version (1.0.21 → 1.1.0)"
    Write-Host "  -Major     Increment major version (1.0.21 → 2.0.0)"
    Write-Host "  -Message   Custom commit message (optional)"
    Write-Host "  -Help      Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\release.ps1                                    # Increment patch version"
    Write-Host "  .\release.ps1 -Patch                             # Increment patch version"
    Write-Host "  .\release.ps1 -Minor                             # Increment minor version"  
    Write-Host "  .\release.ps1 -Major                             # Increment major version"
    Write-Host "  .\release.ps1 -Minor -Message 'Added new features'  # Custom commit message"
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
        # STEP 1: Archive old version to scripts/LegacyScripts folder (PAX branch only)
        if ($oldPath -ne $newPath) {
            $legacyFolder = "scripts/LegacyScripts"
            if (-not (Test-Path $legacyFolder)) {
                New-Item -Path $legacyFolder -ItemType Directory -Force | Out-Null
                Write-Success "Created LegacyScripts folder"
            }
            
            $legacyPath = Join-Path $legacyFolder $oldFilename
            Copy-Item -Path $oldPath -Destination $legacyPath -Force
            Write-Success "Archived old version to: scripts/LegacyScripts/$oldFilename"
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
            
            # Remove old file from root (already archived in scripts/LegacyScripts)
            if ($oldPath -ne $newPath) {
                Remove-Item -Path $oldPath -Force
                Write-Success "Removed old script from root: $oldFilename (archived in scripts/LegacyScripts)"
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
        
        # Define customer-facing files to sync (excluding scripts/ folder entirely)
        $filesToSync = @{
            ".gitattributes" = ".gitattributes"
            ".github/workflows/build-release.yml" = ".github/workflows/build-release.yml"
            "CODE_OF_CONDUCT.md" = "CODE_OF_CONDUCT.md"
            "CONTRIBUTORS.md" = "CONTRIBUTORS.md"
            "LICENSE" = "LICENSE"
            "PAX_Overview.pdf" = "PAX_Overview.pdf"
            "README.md" = "README.md"
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
        
        # Clean up old versioned scripts in release worktree root (keep only current version)
        $releaseRootPath = $releaseWorktreePath
        if (Test-Path $releaseRootPath) {
            Get-ChildItem -Path "$releaseRootPath/PAX_Purview_Audit_Log_Processor_v*.ps1" | 
                Where-Object { $_.Name -ne $scriptFilename } | 
                ForEach-Object {
                    Remove-Item $_.FullName -Force
                    Write-Status "Removed old script version: $($_.Name)"
                }
        }
        
        # Navigate to release worktree and commit changes
        Push-Location $releaseWorktreePath
        try {
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
                
                # Push to temporary branch on microsoft/PAX
                git push origin release:$tempBranch -f 2>$null
                
                # Check if PR already exists
                $existingPR = gh pr list --repo microsoft/PAX --base release --head $tempBranch --json number --jq '.[0].number' 2>$null
                
                if ($existingPR) {
                    Write-Status "PR already exists: https://github.com/microsoft/PAX/pull/$existingPR"
                } else {
                    # Create new PR
                    $prUrl = gh pr create --repo microsoft/PAX --base release --head $tempBranch --title "v${NewVersion}" --body "Automated release sync for v${NewVersion}`n`nSynced files from PAX branch to release branch." 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "PR created: $prUrl"
                        Write-Host "`n⚠️  ACTION REQUIRED: Please approve and merge the PR at: $prUrl" -ForegroundColor Yellow
                    } else {
                        Write-Error "Failed to create PR: $prUrl"
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
            git checkout $currentBranch -- "PAX_Overview.pdf" 2>$null
            git checkout $currentBranch -- "README.md" 2>$null
            git checkout $currentBranch -- "SECURITY.md" 2>$null
            git checkout $currentBranch -- "$scriptFilename" 2>$null
            
            Write-Success "✓ Copied customer-facing files"
            
            # Clean up old script versions from root
            Get-ChildItem -Path "PAX_Purview_Audit_Log_Processor_v*.ps1" | 
                Where-Object { $_.Name -ne $scriptFilename } | 
                ForEach-Object {
                    Remove-Item $_.FullName -Force
                    Write-Status "Removed old script version: $($_.Name)"
                }
            
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
                
                # Push to temporary branch on microsoft/PAX
                git push origin release:$tempBranch -f 2>$null
                
                # Check if PR already exists
                $existingPR = gh pr list --repo microsoft/PAX --base release --head $tempBranch --json number --jq '.[0].number' 2>$null
                
                if ($existingPR) {
                    Write-Status "PR already exists: https://github.com/microsoft/PAX/pull/$existingPR"
                } else {
                    # Create new PR
                    $prUrl = gh pr create --repo microsoft/PAX --base release --head $tempBranch --title "v${NewVersion}" --body "Automated release sync for v${NewVersion}`n`nSynced files from PAX branch to release branch." 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "PR created: $prUrl"
                        Write-Host "`n⚠️  ACTION REQUIRED: Please approve and merge the PR at: $prUrl" -ForegroundColor Yellow
                    } else {
                        Write-Error "Failed to create PR: $prUrl"
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
    Write-Host "  From: " -NoNewline; Write-Host "v$currentVersion" -ForegroundColor Cyan
    Write-Host "  To:   " -NoNewline; Write-Host "v$newVersion" -ForegroundColor Cyan
    Write-Host "  Type: " -NoNewline; Write-Host "$bumpType" -ForegroundColor Cyan
    Write-Host "  Msg:  " -NoNewline; Write-Host "$finalCommitMsg" -ForegroundColor Cyan
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
    
    # Commit and tag
    Write-Status "Creating git commit and tag..."
    New-CommitAndTag -NewVersion $newVersion -BumpType $bumpType -CustomMessage $Message
    
    # Show summary
    Show-Summary -OldVersion $currentVersion -NewVersion $newVersion -BumpType $bumpType -CommitMessage $finalCommitMsg
    
    # Clean up old temporary PR branches
    Remove-OldPRBranches
    
    Write-Success "Release process completed successfully! 🎉"
}

# Run the main function
Main

