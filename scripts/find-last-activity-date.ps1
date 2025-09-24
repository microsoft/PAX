# Script to find the last date of any activity across all users (licensed and unlicensed)
# Analyzes M365AppUsageUserDetail.csv for the most recent activity date

param(
    [string]$M365UsageCSV = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\M365AppUsageUserDetail.csv"
)

Write-Host "Finding the last date of any activity across all users..." -ForegroundColor Green

# Read M365 usage data
Write-Host "Reading M365 usage data..." -ForegroundColor Yellow
$m365Data = Import-Csv $M365UsageCSV

Write-Host "Total M365 usage records: $($m365Data.Count)" -ForegroundColor Cyan

# Get all unique users
$allUsers = $m365Data | Select-Object -ExpandProperty "User Principal Name" | Where-Object { $_ -ne "" } | Sort-Object -Unique
Write-Host "Total unique users in data: $($allUsers.Count)" -ForegroundColor Cyan

# Collect all activity dates
Write-Host "`nAnalyzing activity dates..." -ForegroundColor Yellow

$allActivityDates = @()
$reportDates = @()

foreach ($record in $m365Data) {
    # Collect Last Activity Dates
    if (![string]::IsNullOrWhiteSpace($record."Last Activity Date")) {
        try {
            $activityDate = [DateTime]::Parse($record."Last Activity Date")
            $allActivityDates += $activityDate
        } catch {
            # Skip invalid dates
        }
    }
    
    # Also collect Report Refresh Dates (data collection dates)
    if (![string]::IsNullOrWhiteSpace($record."Report Refresh Date")) {
        try {
            $reportDate = [DateTime]::Parse($record."Report Refresh Date")
            $reportDates += $reportDate
        } catch {
            # Skip invalid dates
        }
    }
}

# Remove duplicates and sort
$uniqueActivityDates = $allActivityDates | Sort-Object -Unique
$uniqueReportDates = $reportDates | Sort-Object -Unique

Write-Host "Valid activity date records: $($allActivityDates.Count)" -ForegroundColor Cyan
Write-Host "Unique activity dates: $($uniqueActivityDates.Count)" -ForegroundColor Cyan
Write-Host "Unique report dates: $($uniqueReportDates.Count)" -ForegroundColor Cyan

# Find the latest dates
if ($uniqueActivityDates.Count -gt 0) {
    $lastActivityDate = $uniqueActivityDates | Sort-Object -Descending | Select-Object -First 1
    $firstActivityDate = $uniqueActivityDates | Sort-Object | Select-Object -First 1
} else {
    Write-Host "No valid activity dates found!" -ForegroundColor Red
    return
}

if ($uniqueReportDates.Count -gt 0) {
    $lastReportDate = $uniqueReportDates | Sort-Object -Descending | Select-Object -First 1
    $firstReportDate = $uniqueReportDates | Sort-Object | Select-Object -First 1
}

# Display results
Write-Host "`n=== ACTIVITY DATE ANALYSIS ===" -ForegroundColor Green

Write-Host "`n📅 LAST ACTIVITY DATE:" -ForegroundColor Cyan
Write-Host "Last activity: $($lastActivityDate.ToString('dddd, MMMM dd, yyyy'))" -ForegroundColor White
Write-Host "Date: $($lastActivityDate.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow

Write-Host "`n📅 FIRST ACTIVITY DATE:" -ForegroundColor Cyan
Write-Host "First activity: $($firstActivityDate.ToString('dddd, MMMM dd, yyyy'))" -ForegroundColor White
Write-Host "Date: $($firstActivityDate.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow

Write-Host "`n📊 DATA COLLECTION DATES:" -ForegroundColor Cyan
Write-Host "Last report date: $($lastReportDate.ToString('dddd, MMMM dd, yyyy'))" -ForegroundColor White
Write-Host "First report date: $($firstReportDate.ToString('dddd, MMMM dd, yyyy'))" -ForegroundColor White

# Calculate time spans
$activitySpan = ($lastActivityDate - $firstActivityDate).Days
$reportSpan = ($lastReportDate - $firstReportDate).Days

Write-Host "`n📈 TIME SPANS:" -ForegroundColor Green
Write-Host "Activity date range: $activitySpan days" -ForegroundColor White
Write-Host "Report collection range: $reportSpan days" -ForegroundColor White

# Find users with the last activity date
Write-Host "`n👥 USERS WITH LATEST ACTIVITY ($($lastActivityDate.ToString('yyyy-MM-dd'))):" -ForegroundColor Yellow

$usersWithLastActivity = $m365Data | Where-Object { 
    ![string]::IsNullOrWhiteSpace($_."Last Activity Date") -and
    (try { [DateTime]::Parse($_."Last Activity Date") -eq $lastActivityDate } catch { $false })
} | Select-Object "User Principal Name" -Unique

Write-Host "Number of users with latest activity: $($usersWithLastActivity.Count)" -ForegroundColor Cyan

# Show first 10 users
$usersWithLastActivity | Select-Object -First 10 | ForEach-Object {
    Write-Host "- $($_.'User Principal Name')" -ForegroundColor White
}

if ($usersWithLastActivity.Count -gt 10) {
    Write-Host "... and $($usersWithLastActivity.Count - 10) more users" -ForegroundColor Gray
}

# Activity distribution around the last date
Write-Host "`n📊 ACTIVITY DISTRIBUTION (Last 10 Days):" -ForegroundColor Green

$last10Days = $lastActivityDate.AddDays(-9).Date..$lastActivityDate.Date
$activityCounts = @{}

foreach ($date in $last10Days) {
    $count = ($m365Data | Where-Object { 
        ![string]::IsNullOrWhiteSpace($_."Last Activity Date") -and
        (try { [DateTime]::Parse($_."Last Activity Date").Date -eq $date } catch { $false })
    }).Count
    
    $activityCounts[$date.ToString('yyyy-MM-dd')] = $count
}

foreach ($dateKey in ($activityCounts.Keys | Sort-Object)) {
    $count = $activityCounts[$dateKey]
    if ($count -gt 0) {
        $indicator = if ($dateKey -eq $lastActivityDate.ToString('yyyy-MM-dd')) { " ← LATEST" } else { "" }
        Write-Host "$dateKey`: $count users$indicator" -ForegroundColor White
    }
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
Write-Host "🎯 LAST ACTIVITY DATE: $($lastActivityDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
Write-Host "📊 Total users tracked: $($allUsers.Count)" -ForegroundColor White
Write-Host "📅 Activity date range: $($firstActivityDate.ToString('yyyy-MM-dd')) to $($lastActivityDate.ToString('yyyy-MM-dd'))" -ForegroundColor White
Write-Host "📈 Data collection range: $($firstReportDate.ToString('yyyy-MM-dd')) to $($lastReportDate.ToString('yyyy-MM-dd'))" -ForegroundColor White

# Check if this is recent data
$daysSinceLastActivity = ((Get-Date) - $lastActivityDate).Days
Write-Host "`n⏰ Data freshness: $daysSinceLastActivity days since last recorded activity" -ForegroundColor $(if ($daysSinceLastActivity -le 7) { "Green" } elseif ($daysSinceLastActivity -le 30) { "Yellow" } else { "Red" })

Write-Host "`n✨ Analysis complete!" -ForegroundColor Green