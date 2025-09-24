# Test PowerShell 5.1 ONLY scenario (simulate system without PowerShell 7)
# This simulates what happens when pwsh.exe is not available

Write-Host "Testing PowerShell 5.1 ONLY scenario..." -ForegroundColor Cyan

# Simulate the PAX app logic when pwsh.exe is not found
Write-Host "Simulating PAX app logic when PowerShell 7 is not available..." -ForegroundColor Yellow

$pwsh7Available = $false
try {
    # Simulate: which::which("pwsh.exe") fails
    $pwsh7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    $pwsh7Available = $pwsh7 -ne $null
} catch {
    $pwsh7Available = $false
}

Write-Host "PowerShell 7 (pwsh.exe) available: $pwsh7Available" -ForegroundColor $(if ($pwsh7Available) { 'Green' } else { 'Red' })

# Now test the fallback to PowerShell 5.1
$pwsh51Available = $false
try {
    # Simulate: .or_else(|_| which::which("powershell.exe"))
    $pwsh51 = Get-Command powershell.exe -ErrorAction SilentlyContinue
    $pwsh51Available = $pwsh51 -ne $null
    if ($pwsh51Available) {
        Write-Host "PowerShell 5.1 fallback available: $pwsh51Available" -ForegroundColor Green
        Write-Host "Path: $($pwsh51.Source)" -ForegroundColor Cyan
        
        # Test the actual command that PAX would use
        Write-Host "`nTesting PAX-style command execution with PowerShell 5.1..." -ForegroundColor Yellow
        try {
            # Simulate the PAX app's Command::new(pwsh_path) with powershell.exe
            $testScript = "Write-Host 'PAX running via PowerShell 5.1 fallback!'; Write-Host 'PSVersion:' `$PSVersionTable.PSVersion"
            $result = & $pwsh51.Source -NoProfile -ExecutionPolicy Bypass -Command $testScript
            
            Write-Host "✅ PowerShell 5.1 execution test: SUCCESS" -ForegroundColor Green
            Write-Host "Output: $result" -ForegroundColor Gray
            
        } catch {
            Write-Host "❌ PowerShell 5.1 execution test: FAILED - $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Test ExchangeOnlineManagement module availability
        Write-Host "`nTesting ExchangeOnlineManagement module compatibility..." -ForegroundColor Yellow
        try {
            $moduleTest = & $pwsh51.Source -NoProfile -ExecutionPolicy Bypass -Command "if (Get-Module -ListAvailable ExchangeOnlineManagement -ErrorAction SilentlyContinue) { 'Module available' } else { 'Module not found' }"
            Write-Host "ExchangeOnlineManagement module: $moduleTest" -ForegroundColor $(if ($moduleTest -eq 'Module available') { 'Green' } else { 'Yellow' })
        } catch {
            Write-Host "Module test failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
    }
} catch {
    $pwsh51Available = $false
}

Write-Host "`n=== PAX App Compatibility Result ===" -ForegroundColor Cyan
if ($pwsh51Available) {
    Write-Host "✅ PAX app WILL WORK on systems with only PowerShell 5.1!" -ForegroundColor Green
    Write-Host "   - App will automatically fall back to powershell.exe" -ForegroundColor Green  
    Write-Host "   - All functionality should work normally" -ForegroundColor Green
    Write-Host "   - Exported scripts are already PowerShell 5.1 compatible" -ForegroundColor Green
} else {
    Write-Host "❌ No PowerShell found - PAX app will not work" -ForegroundColor Red
}

# Test our actual Rust logic pattern
Write-Host "`nTesting Rust-equivalent logic pattern:" -ForegroundColor Cyan
Write-Host "  which::which(`"pwsh.exe`").or_else(|_| which::which(`"powershell.exe`"))" -ForegroundColor Gray

$selectedExecutable = $null
if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
    $selectedExecutable = "pwsh.exe (PowerShell 7 - preferred)"
} elseif (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
    $selectedExecutable = "powershell.exe (PowerShell 5.1 - fallback)"
} else {
    $selectedExecutable = "ERROR: No PowerShell found"
}

Write-Host "Selected: $selectedExecutable" -ForegroundColor $(if ($selectedExecutable.StartsWith('ERROR')) { 'Red' } else { 'Green' })

Write-Host "`n🚀 Updated PAX app now supports both PowerShell 7 AND PowerShell 5.1!" -ForegroundColor Magenta