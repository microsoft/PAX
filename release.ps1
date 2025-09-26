# PAX Version Bump and Release Script (PowerShell)
# Automatically updates version numbers, commits changes, and triggers GitHub release workflow

param(
    [switch]$Patch,
    [switch]$Minor, 
    [switch]$Major,
    [string]$Message,
    [switch]$Help
)

# Script configuration
$ScriptName = "PAX Release Script"
$PackageJson = "package.json"
$TauriConf = "src-tauri/tauri.conf.json"

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
        default { # patch
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
        } elseif ($content.PSObject.Properties['package']) {
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
        } else {
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
    
    # Create commit message - use custom message if provided, otherwise auto-generate
    $commitMsg = if ($CustomMessage) {
        "v${NewVersion}: $CustomMessage"
    } else {
        switch ($BumpType) {
            "major" { "v${NewVersion}: Major version release" }
            "minor" { "v${NewVersion}: Minor version release" }
            default { "v${NewVersion}: Patch version release" }
        }
    }
    
    # Commit the changes
    git commit -m $commitMsg
    Write-Success "Created commit: $commitMsg"
    
    # Create and push tag
    git tag "v$NewVersion"
    Write-Success "Created tag: v$NewVersion"
    
    # Push changes and tag
    git push origin main
    git push origin "v$NewVersion"
    Write-Success "Pushed changes and tag to GitHub"
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
    Write-Host "🚀 GitHub Actions workflow will now:" -ForegroundColor Cyan
    Write-Host "   ✅ Build Windows executable"
    Write-Host "   ✅ Build macOS executable" 
    Write-Host "   ✅ Create GitHub release page"
    Write-Host "   ✅ Upload distribution files"
    Write-Host ""
    Write-Host "View progress at: https://github.com/Rance9/PAX/actions" -ForegroundColor Blue
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
    } else {
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
    
    # Commit and tag
    Write-Status "Creating git commit and tag..."
    New-CommitAndTag -NewVersion $newVersion -BumpType $bumpType -CustomMessage $Message
    
    # Show summary
    Show-Summary -OldVersion $currentVersion -NewVersion $newVersion -BumpType $bumpType -CommitMessage $finalCommitMsg
    
    Write-Success "Release process completed successfully! 🎉"
}

# Run the main function
Main