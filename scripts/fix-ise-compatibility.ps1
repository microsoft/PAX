# PowerShell 5.1 Compatible Version - Remove null-conditional operators
# This script fixes the syntax issues for older PowerShell versions

$scriptPath = "c:\temp\Purview_Export_Script_v1.0.20_20250923.ps1"
$outputPath = "c:\temp\Purview_Export_Script_v1.0.20_20250923_ISE_Compatible.ps1"

Write-Host "Converting script to PowerShell 5.1/ISE compatible syntax..." -ForegroundColor Green

# Read the original script
$content = Get-Content $scriptPath -Raw

# Fix null-conditional operators - replace ?. with traditional null checks
$fixes = @{
    # Fix: $ps = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
    '\$ps = \(Get-Command pwsh -ErrorAction SilentlyContinue\)\?\.Source' = '$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue; $ps = if ($pwshCmd) { $pwshCmd.Source } else { $null }'
    
    # Fix: if (-not $ps) { $ps = (Get-Command powershell -ErrorAction SilentlyContinue)?.Source }
    'if \(-not \$ps\) \{ \$ps = \(Get-Command powershell -ErrorAction SilentlyContinue\)\?\.Source \}' = 'if (-not $ps) { $psCmd = Get-Command powershell -ErrorAction SilentlyContinue; $ps = if ($psCmd) { $psCmd.Source } else { $null } }'
    
    # Fix other null-conditional operators
    '\$(\w+) = \$(\w+)\?\.(\w+)' = '$1 = if ($2) { $2.$3 } else { $null }'
}

foreach ($pattern in $fixes.Keys) {
    $replacement = $fixes[$pattern]
    $content = $content -replace $pattern, $replacement
}

# Additional specific fixes for complex expressions
$content = $content -replace 'if \(\$exoCmd\?\.\w+\)', 'if ($exoCmd -and $exoCmd.Parameters)'
$content = $content -replace '\$hasOpenWebPage = \$exoCmd\?\.\w+\.ContainsKey\(''OpenWebPage''\)', '$hasOpenWebPage = $exoCmd -and $exoCmd.Parameters -and $exoCmd.Parameters.ContainsKey(''OpenWebPage'')'
$content = $content -replace '\$hasUseWAM = \$exoCmd\?\.\w+\.ContainsKey\(''UseWAM''\)', '$hasUseWAM = $exoCmd -and $exoCmd.Parameters -and $exoCmd.Parameters.ContainsKey(''UseWAM'')'

# Write the compatible version
$content | Set-Content $outputPath -Encoding UTF8

Write-Host "✅ ISE-compatible script created: $outputPath" -ForegroundColor Green
Write-Host ""
Write-Host "Customer Instructions:" -ForegroundColor Yellow
Write-Host "1. Use the new file: Purview_Export_Script_v1.0.20_20250923_ISE_Compatible.ps1" -ForegroundColor White
Write-Host "2. OR (Better): Use PowerShell Console instead of ISE" -ForegroundColor White
Write-Host "3. Minimum PowerShell version: 5.1" -ForegroundColor White