# Test script to measure row explosion performance improvements
Write-Host "Testing Row Explosion Performance Improvements" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow

# Test with a reasonable record count that will trigger row explosion
$testParams = @{
    StartDate = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
    EndDate = (Get-Date).ToString("yyyy-MM-dd") 
    ResultSize = 25
    CopilotInteractionOnly = $true
    DevTest = $true
    Verbose = $false  # Reduce verbose output for cleaner test
}

Write-Host "Running performance test with parameters:" -ForegroundColor Green
$testParams | Format-Table -AutoSize

Write-Host "Starting test run..." -ForegroundColor Green
Write-Host "Note: This test uses DevTest mode to generate synthetic records for row explosion testing" -ForegroundColor Yellow
$startTime = Get-Date

try {
    & .\scripts\CopilotAuditExport.ps1 @testParams
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host "`nPerformance Test Results:" -ForegroundColor Yellow
    Write-Host "Total Duration: $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Green
    Write-Host "Minutes: $($duration.TotalMinutes.ToString('F2'))" -ForegroundColor Green
    
    if ($duration.TotalMinutes -lt 2) {
        Write-Host "EXCELLENT: Under 2 minutes!" -ForegroundColor Green
    } elseif ($duration.TotalMinutes -lt 5) {
        Write-Host "GOOD: Under 5 minutes" -ForegroundColor Yellow
    } else {
        Write-Host "SLOW: Over 5 minutes - needs more optimization" -ForegroundColor Red
    }
}
catch {
    Write-Host "Test failed: $($_.Exception.Message)" -ForegroundColor Red
}