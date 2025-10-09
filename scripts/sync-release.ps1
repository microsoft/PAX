# Sync Release Branch with PAX Branch
# This script updates the 8 release files with their latest versions from PAX

Write-Host "🔄 Syncing release branch files with PAX branch..." -ForegroundColor Cyan
Write-Host ""

# Ensure we're in the PAX branch
$currentBranch = git rev-parse --abbrev-ref HEAD
if ($currentBranch -ne "PAX") {
    Write-Host "❌ Error: Must run this from PAX branch. Currently on: $currentBranch" -ForegroundColor Red
    exit 1
}

# Find the current versioned script file dynamically
$scriptPattern = "scripts/PAX_Purview_Audit_Log_Processor_v*.ps1"
$currentScript = Get-ChildItem -Path $scriptPattern -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $currentScript) {
    Write-Host "❌ Error: Could not find export script matching pattern: $scriptPattern" -ForegroundColor Red
    exit 1
}

$scriptFilename = $currentScript.Name
$scriptRelativePath = "scripts/$scriptFilename"
Write-Host "📄 Found current script: $scriptFilename" -ForegroundColor Green
Write-Host ""

# The 8 files that exist in both branches (with dynamic script filename)
$releaseFiles = @(
    ".gitattributes"
    ".github/workflows/build-release.yml"
    "CODE_OF_CONDUCT.md"
    "CONTRIBUTORS.md"
    "LICENSE"
    "README.md"
    "SECURITY.md"
    $scriptRelativePath
)

Write-Host "📋 Files to sync:" -ForegroundColor Yellow
$releaseFiles | ForEach-Object { Write-Host "  • $_" }
Write-Host ""

# Check if there are uncommitted changes in PAX
$status = git status --porcelain
if ($status) {
    Write-Host "⚠️  Warning: You have uncommitted changes in PAX branch:" -ForegroundColor Yellow
    Write-Host $status
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        Write-Host "Aborted." -ForegroundColor Red
        exit 1
    }
}

# Switch to release branch and update files
Write-Host "📥 Checking out files from PAX to release..." -ForegroundColor Cyan
git checkout release

foreach ($file in $releaseFiles) {
    Write-Host "  Updating: $file" -ForegroundColor Gray
    git checkout PAX -- $file
}

# Check if there are changes
$changes = git status --porcelain
if ($changes) {
    Write-Host ""
    Write-Host "📝 Changes detected:" -ForegroundColor Yellow
    git status --short
    Write-Host ""
    
    $commit = Read-Host "Commit and push these changes? (y/n)"
    if ($commit -eq "y") {
        $commitMsg = "Sync release files with PAX branch ($(Get-Date -Format 'yyyy-MM-dd'))"
        git add .
        git commit -m $commitMsg
        
        Write-Host ""
        Write-Host "🚀 Pushing to origin/release..." -ForegroundColor Cyan
        git push origin release
        
        Write-Host ""
        Write-Host "✅ Release branch synced and pushed!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "⚠️  Changes staged but not committed. Run 'git commit' manually." -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "✅ Release branch already up to date!" -ForegroundColor Green
}

# Switch back to PAX
Write-Host ""
Write-Host "🔙 Switching back to PAX branch..." -ForegroundColor Cyan
git checkout PAX

Write-Host ""
Write-Host "✅ Done!" -ForegroundColor Green
