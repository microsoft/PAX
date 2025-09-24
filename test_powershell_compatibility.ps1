# Test PowerShell version compatibility for PAX app
# This tests that the app can find and use both PowerShell 7 and PowerShell 5.1

Write-Host "Testing PowerShell compatibility for PAX app..." -ForegroundColor Cyan

# Check what PowerShell versions are available
Write-Host "`nAvailable PowerShell executables:" -ForegroundColor Yellow

$powershells = @()

# Check for PowerShell 7 (pwsh.exe)
try {
    $pwsh7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($pwsh7) {
        $version7 = & pwsh.exe -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
        $powershells += [PSCustomObject]@{
            Name = "PowerShell 7 (pwsh.exe)"
            Path = $pwsh7.Source
            Version = $version7
            Available = $true
        }
        Write-Host "✅ PowerShell 7: $($pwsh7.Source) (v$version7)" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ PowerShell 7 (pwsh.exe): Not found" -ForegroundColor Red
}

# Check for PowerShell 5.1 (powershell.exe)
try {
    $pwsh51 = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($pwsh51) {
        $version51 = & powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
        $powershells += [PSCustomObject]@{
            Name = "PowerShell 5.1 (powershell.exe)"
            Path = $pwsh51.Source
            Version = $version51
            Available = $true
        }
        Write-Host "✅ PowerShell 5.1: $($pwsh51.Source) (v$version51)" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ PowerShell 5.1 (powershell.exe): Not found" -ForegroundColor Red
}

Write-Host "`nPAX App Compatibility Test:" -ForegroundColor Cyan

if ($powershells.Count -eq 0) {
    Write-Host "❌ CRITICAL: No PowerShell found - PAX app will not work" -ForegroundColor Red
    exit 1
}

# Test the same logic the PAX app uses (PowerShell 7 first, then 5.1 fallback)
$selectedPS = $null
if ($pwsh7) {
    $selectedPS = $powershells | Where-Object { $_.Name -like "*pwsh.exe*" }
    Write-Host "✅ PAX would use: PowerShell 7 (preferred)" -ForegroundColor Green
} elseif ($pwsh51) {
    $selectedPS = $powershells | Where-Object { $_.Name -like "*powershell.exe*" }
    Write-Host "✅ PAX would use: PowerShell 5.1 (fallback)" -ForegroundColor Yellow
}

if ($selectedPS) {
    Write-Host "   Selected: $($selectedPS.Name) at $($selectedPS.Path)" -ForegroundColor Cyan
    Write-Host "   Version: $($selectedPS.Version)" -ForegroundColor Cyan
    
    # Test a simple command that PAX might use
    Write-Host "`nTesting basic functionality..." -ForegroundColor Yellow
    try {
        $testCmd = if ($selectedPS.Name -like "*pwsh.exe*") { "pwsh.exe" } else { "powershell.exe" }
        $testResult = & $testCmd -NoProfile -ExecutionPolicy Bypass -Command "Write-Output 'PAX compatibility test successful'" 2>$null
        if ($testResult -eq "PAX compatibility test successful") {
            Write-Host "✅ Basic execution test: PASSED" -ForegroundColor Green
        } else {
            Write-Host "❌ Basic execution test: FAILED" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Basic execution test: ERROR - $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ PAX compatibility: FAILED - No compatible PowerShell found" -ForegroundColor Red
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "PowerShell 7 (pwsh.exe): $(if ($pwsh7) { 'Available' } else { 'Not Available' })" -ForegroundColor $(if ($pwsh7) { 'Green' } else { 'Red' })
Write-Host "PowerShell 5.1 (powershell.exe): $(if ($pwsh51) { 'Available' } else { 'Not Available' })" -ForegroundColor $(if ($pwsh51) { 'Green' } else { 'Red' })
Write-Host "PAX App Status: $(if ($selectedPS) { 'Compatible' } else { 'Incompatible' })" -ForegroundColor $(if ($selectedPS) { 'Green' } else { 'Red' })

if ($selectedPS) {
    Write-Host "`n🎯 PAX app should work on this system!" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  PAX app will NOT work on this system - install PowerShell 5.1+ or PowerShell 7" -ForegroundColor Red
}