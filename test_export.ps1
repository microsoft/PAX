# Test script to validate the export functionality
# This will generate a test export and check for key enterprise functions

Write-Host "Testing PAX export functionality..." -ForegroundColor Cyan

# Check if the executable exists
$exePath = ".\src-tauri\target\release\Purview Audit eXporter (PAX).exe"
if (-not (Test-Path $exePath)) {
    $exePath = ".\src-tauri\target\debug\purview-audit-exporter.exe"
    if (-not (Test-Path $exePath)) {
        Write-Host "ERROR: No executable found. Build the project first." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Using executable: $exePath" -ForegroundColor Yellow

# Test export with sample parameters
$testOutput = "test_export_output.ps1"
$testCmd = @(
    "--start-date", "2024-01-01"
    "--end-date", "2024-01-02"  
    "--auth-mode", "WebLogin"
    "--output-file", "test_output.csv"
    "--activity-types", "CopilotInteraction,SharePointFileOperation"
    "--export-script", $testOutput
)

Write-Host "Running export command..." -ForegroundColor Yellow
Write-Host "Command: $exePath $($testCmd -join ' ')" -ForegroundColor Gray

try {
    & $exePath @testCmd
    
    if (Test-Path $testOutput) {
        Write-Host "SUCCESS: Export script generated at $testOutput" -ForegroundColor Green
        
        # Check for key enterprise functions in the exported script
        $content = Get-Content $testOutput -Raw
        
        $keyFunctions = @(
            "Invoke-SearchUnifiedAuditLogWithRetry",
            "Convert-ToMetricsRecord", 
            "Connect-ToComplianceCenter",
            "Start-VisibleReexecForAuth",
            "Get-UserType",
            "Get-WorkloadFromRecordType"
        )
        
        $missingFunctions = @()
        foreach ($func in $keyFunctions) {
            if ($content -notlike "*$func*") {
                $missingFunctions += $func
            }
        }
        
        if ($missingFunctions.Count -eq 0) {
            Write-Host "SUCCESS: All key enterprise functions found in exported script" -ForegroundColor Green
            
            # Check for PowerShell 5.1 compatibility issues
            if ($content -like "*?.*") {
                Write-Host "WARNING: Potential null-conditional operators found - check PowerShell 5.1 compatibility" -ForegroundColor Yellow
            } else {
                Write-Host "SUCCESS: No null-conditional operators detected - PowerShell 5.1 compatible" -ForegroundColor Green
            }
            
            # Check syntax
            Write-Host "Checking PowerShell syntax..." -ForegroundColor Yellow
            try {
                [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null) | Out-Null
                Write-Host "SUCCESS: PowerShell syntax validation passed" -ForegroundColor Green
            } catch {
                Write-Host "ERROR: PowerShell syntax validation failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            
        } else {
            Write-Host "ERROR: Missing key enterprise functions: $($missingFunctions -join ', ')" -ForegroundColor Red
        }
        
        Write-Host "`nFirst 50 lines of exported script:" -ForegroundColor Cyan
        (Get-Content $testOutput -TotalCount 50) | ForEach-Object { Write-Host "  $_" }
        
    } else {
        Write-Host "ERROR: Export script not generated at $testOutput" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: Export command failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
if (Test-Path $testOutput) {
    Remove-Item $testOutput -Force
    Write-Host "Cleaned up test file: $testOutput" -ForegroundColor Gray
}