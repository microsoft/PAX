# Script to properly track staggered Copilot license rollout over time
# Analyzes when users first appear in Copilot usage data to determine licensing timeline

param(
    [string]$M365UsageCSV = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\M365AppUsageUserDetail.csv",
    [string]$CopilotUsageCSV = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\CopilotUsageUserDetail.csv"
)

Write-Host "Analyzing staggered Copilot license rollout..." -ForegroundColor Green

# Read both datasets
$m365Data = Import-Csv $M365UsageCSV
$copilotData = Import-Csv $CopilotUsageCSV

Write-Host "Total M365 users in data: $(($m365Data | Select-Object 'User Principal Name' -Unique).Count)" -ForegroundColor Cyan
Write-Host "Total Copilot usage records: $($copilotData.Count)" -ForegroundColor Cyan

# Get all unique users from M365 data (represents the 1000 user base)
$allUsers = $m365Data | Select-Object -ExpandProperty "User Principal Name" | Where-Object { $_ -ne "" } | Sort-Object -Unique
Write-Host "Total unique M365 users: $($allUsers.Count)" -ForegroundColor Yellow

# Get Copilot users and their first license dates
# We'll determine licensing date by the earliest date each user appears in any Copilot data
$copilotUserLicensing = @{}

foreach ($record in $copilotData) {
    $user = $record."User Principal Name"
    if ([string]::IsNullOrWhiteSpace($user)) { continue }
    
    # Get report refresh date as proxy for when they were included in Copilot reporting
    $reportDate = $null
    if (![string]::IsNullOrWhiteSpace($record."Report Refresh Date")) {
        try {
            $reportDate = [DateTime]::Parse($record."Report Refresh Date")
        } catch { continue }
    }
    
    # Track the earliest date this user appeared in Copilot data
    if ($reportDate -ne $null) {
        if (-not $copilotUserLicensing.ContainsKey($user) -or $reportDate -lt $copilotUserLicensing[$user]) {
            $copilotUserLicensing[$user] = $reportDate
        }
    }
}

Write-Host "Users with Copilot licensing dates tracked: $($copilotUserLicensing.Count)" -ForegroundColor Cyan

# Create monthly licensing timeline
$monthlyLicensing = @{}
$licensedUsers = @{}

# Get all unique months from the data
$allDates = $copilotUserLicensing.Values | Sort-Object
$startDate = $allDates[0]
$endDate = $allDates[-1]

# Create month buckets
$currentDate = Get-Date -Year $startDate.Year -Month $startDate.Month -Day 1
while ($currentDate -le $endDate) {
    $monthKey = $currentDate.ToString('yyyy-MM')
    $monthlyLicensing[$monthKey] = @{
        FirstDay = $currentDate
        NewLicenses = 0
        TotalLicensed = 0
        NewlyLicensedUsers = @()
    }
    $currentDate = $currentDate.AddMonths(1)
}

# Populate licensing data
foreach ($user in $copilotUserLicensing.Keys) {
    $licenseDate = $copilotUserLicensing[$user]
    $monthKey = $licenseDate.ToString('yyyy-MM')
    
    if ($monthlyLicensing.ContainsKey($monthKey)) {
        $monthlyLicensing[$monthKey].NewLicenses++
        $monthlyLicensing[$monthKey].NewlyLicensedUsers += $user
    }
}

# Calculate cumulative totals
$cumulativeTotal = 0
$monthlyResults = @()

foreach ($monthKey in ($monthlyLicensing.Keys | Sort-Object)) {
    $monthData = $monthlyLicensing[$monthKey]
    $cumulativeTotal += $monthData.NewLicenses
    $monthData.TotalLicensed = $cumulativeTotal
    
    $result = [PSCustomObject]@{
        Month = $monthKey
        FirstDayOfMonth = $monthData.FirstDay.ToString('yyyy-MM-dd')
        MonthName = $monthData.FirstDay.ToString('MMMM yyyy')
        NewLicensesThisMonth = $monthData.NewLicenses
        TotalLicensedAsOfFirstDay = $cumulativeTotal
        CumulativeLicensedUsers = $cumulativeTotal
        PercentageOfTotal = [Math]::Round(($cumulativeTotal / $allUsers.Count) * 100, 1)
        UnlicensedUsers = $allUsers.Count - $cumulativeTotal
    }
    
    $monthlyResults += $result
}

# Display results
Write-Host "`n=== STAGGERED COPILOT LICENSE ROLLOUT ===" -ForegroundColor Green
Write-Host "Tracking actual licensing dates based on first appearance in Copilot data" -ForegroundColor Yellow
Write-Host ""

foreach ($result in $monthlyResults) {
    Write-Host "📅 $($result.MonthName) (as of $($result.FirstDayOfMonth))" -ForegroundColor Cyan
    Write-Host "   New Licenses: $($result.NewLicensesThisMonth)" -ForegroundColor Green
    Write-Host "   Total Licensed: $($result.TotalLicensedAsOfFirstDay)" -ForegroundColor White
    Write-Host "   Percentage: $($result.PercentageOfTotal)%" -ForegroundColor Gray
    Write-Host "   Unlicensed: $($result.UnlicensedUsers)" -ForegroundColor Gray
    Write-Host ""
}

# Summary table
Write-Host "=== ROLLOUT SUMMARY TABLE ===" -ForegroundColor Green
Write-Host "Month`t`tNew`tTotal`t%`tUnlicensed" -ForegroundColor Yellow
Write-Host "-----`t`t---`t-----`t-`t----------" -ForegroundColor Yellow
foreach ($result in $monthlyResults) {
    Write-Host "$($result.Month)`t`t$($result.NewLicensesThisMonth)`t$($result.TotalLicensedAsOfFirstDay)`t$($result.PercentageOfTotal)%`t$($result.UnlicensedUsers)" -ForegroundColor White
}

# Export to CSV
$outputPath = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\copilot_license_rollout.csv"
$monthlyResults | Export-Csv -Path $outputPath -NoTypeInformation
Write-Host "`n✅ Rollout data exported to: $outputPath" -ForegroundColor Green

# Rollout insights
Write-Host "`n=== ROLLOUT INSIGHTS ===" -ForegroundColor Green
$totalLicensed = ($monthlyResults | Select-Object -Last 1).TotalLicensedAsOfFirstDay
$totalUsers = $allUsers.Count
$neverLicensed = $totalUsers - $totalLicensed
$rolloutMonths = $monthlyResults.Count
$avgLicensesPerMonth = [Math]::Round($totalLicensed / $rolloutMonths, 0)

Write-Host "🏢 Total user base: $totalUsers users" -ForegroundColor White
Write-Host "📈 Total licensed by end: $totalLicensed users" -ForegroundColor White
Write-Host "❌ Never licensed: $neverLicensed users" -ForegroundColor White
Write-Host "📊 Rollout period: $rolloutMonths months" -ForegroundColor White
Write-Host "⚡ Average licenses per month: $avgLicensesPerMonth" -ForegroundColor White
Write-Host "🎯 Final adoption rate: $([Math]::Round(($totalLicensed / $totalUsers) * 100, 1))%" -ForegroundColor Cyan

# Validate against expected numbers
Write-Host "`n=== VALIDATION ===" -ForegroundColor Green
if ($totalUsers -eq 1000) {
    Write-Host "✅ Total users matches expected: 1,000" -ForegroundColor Green
} else {
    Write-Host "⚠️ Total users: $totalUsers (expected: 1,000)" -ForegroundColor Yellow
}

if ($totalLicensed -eq 800) {
    Write-Host "✅ Total licensed matches expected: 800" -ForegroundColor Green
} else {
    Write-Host "⚠️ Total licensed: $totalLicensed (expected: 800)" -ForegroundColor Yellow
}

if ($neverLicensed -eq 200) {
    Write-Host "✅ Never licensed matches expected: 200" -ForegroundColor Green
} else {
    Write-Host "⚠️ Never licensed: $neverLicensed (expected: 200)" -ForegroundColor Yellow
}

# Peak rollout month
$peakMonth = $monthlyResults | Sort-Object NewLicensesThisMonth -Descending | Select-Object -First 1
Write-Host "🏆 Peak rollout month: $($peakMonth.MonthName) ($($peakMonth.NewLicensesThisMonth) new licenses)" -ForegroundColor White

Write-Host "`n✨ Staggered rollout analysis complete!" -ForegroundColor Green