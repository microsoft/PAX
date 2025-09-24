# Find Last Activity Date Analysis
# Analyzes the M365AppUsageUserDetail.csv to find the latest activity date across all users

Write-Host "🔍 LAST ACTIVITY DATE ANALYSIS" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green

# File paths
$m365File = "# File paths
$m365File = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\M365AppUsageUserDetail.csv"

# Check if file exists
if (-not (Test-Path $m365File)) {
    Write-Host "❌ Error: $m365File not found" -ForegroundColor Red
    exit 1
}

Write-Host "📂 Loading M365 App Usage data..." -ForegroundColor Yellow

# Import the data
try {
    $m365Data = Import-Csv $m365File
    Write-Host "✅ Loaded $($m365Data.Count) M365 app usage records" -ForegroundColor Green
} catch {
    Write-Host "❌ Error loading M365 data: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n📊 ANALYZING ACTIVITY DATES..." -ForegroundColor Yellow

# Find all valid activity dates and get the latest one
$allActivityDates = @()
$invalidDates = 0

foreach ($record in $m365Data) {
    $activityDateStr = $record."Last Activity Date"
    if (![string]::IsNullOrWhiteSpace($activityDateStr) -and $activityDateStr -ne "") {
        try {
            $activityDate = [DateTime]::Parse($activityDateStr)
            $allActivityDates += $activityDate
        } catch {
            $invalidDates++
        }
    }
}

if ($allActivityDates.Count -eq 0) {
    Write-Host "❌ No valid activity dates found in the data" -ForegroundColor Red
    exit 1
}

# Get the latest activity date
$lastActivityDate = ($allActivityDates | Measure-Object -Maximum).Maximum
$firstActivityDate = ($allActivityDates | Measure-Object -Minimum).Minimum

Write-Host "`n📅 ACTIVITY DATE SUMMARY:" -ForegroundColor Cyan
Write-Host "Latest activity date: $($lastActivityDate.ToString('yyyy-MM-dd dddd'))" -ForegroundColor White
Write-Host "Earliest activity date: $($firstActivityDate.ToString('yyyy-MM-dd dddd'))" -ForegroundColor White

$activitySpan = ($lastActivityDate - $firstActivityDate).Days
Write-Host "Activity date range: $activitySpan days" -ForegroundColor White

if ($invalidDates -gt 0) {
    Write-Host "Invalid/unparseable dates: $invalidDates" -ForegroundColor Yellow
}

# Find users with the last activity date
Write-Host "`n👥 USERS WITH LATEST ACTIVITY ($($lastActivityDate.ToString('yyyy-MM-dd'))):" -ForegroundColor Yellow

$usersWithLastActivity = @()
foreach ($record in $m365Data) {
    $activityDateStr = $record."Last Activity Date"
    if (![string]::IsNullOrWhiteSpace($activityDateStr) -and $activityDateStr -ne "") {
        try {
            $activityDate = [DateTime]::Parse($activityDateStr)
            if ($activityDate -eq $lastActivityDate) {
                $usersWithLastActivity += $record
            }
        } catch {
            # Skip invalid dates
        }
    }
}

# Get unique users
$uniqueUsersWithLastActivity = $usersWithLastActivity | Select-Object "User Principal Name" -Unique

Write-Host "Number of users with latest activity: $($uniqueUsersWithLastActivity.Count)" -ForegroundColor Cyan

# Show first 10 users
Write-Host "`nFirst 10 users with latest activity:" -ForegroundColor White
$uniqueUsersWithLastActivity | Select-Object -First 10 | ForEach-Object {
    Write-Host "- $($_.'User Principal Name')" -ForegroundColor Gray
}

if ($uniqueUsersWithLastActivity.Count -gt 10) {
    Write-Host "... and $($uniqueUsersWithLastActivity.Count - 10) more users" -ForegroundColor Gray
}

# Analyze Report Date to understand data freshness
Write-Host "`n📈 DATA FRESHNESS ANALYSIS:" -ForegroundColor Cyan

$reportDates = @()
foreach ($record in $m365Data) {
    $reportDateStr = $record."Report Date"
    if (![string]::IsNullOrWhiteSpace($reportDateStr) -and $reportDateStr -ne "") {
        try {
            $reportDate = [DateTime]::Parse($reportDateStr)
            $reportDates += $reportDate
        } catch {
            # Skip invalid dates
        }
    }
}

if ($reportDates.Count -gt 0) {
    $latestReportDate = ($reportDates | Measure-Object -Maximum).Maximum
    $earliestReportDate = ($reportDates | Measure-Object -Minimum).Minimum
    
    Write-Host "Latest report date: $($latestReportDate.ToString('yyyy-MM-dd dddd'))" -ForegroundColor White
    Write-Host "Earliest report date: $($earliestReportDate.ToString('yyyy-MM-dd dddd'))" -ForegroundColor White
    
    $reportSpan = ($latestReportDate - $earliestReportDate).Days
    Write-Host "Report collection range: $reportSpan days" -ForegroundColor White
    
    # Data freshness
    $daysSinceLastReport = ((Get-Date) - $latestReportDate).Days
    Write-Host "Days since latest report: $daysSinceLastReport days" -ForegroundColor $(if ($daysSinceLastReport -le 2) { "Green" } elseif ($daysSinceLastReport -le 7) { "Yellow" } else { "Red" })
    
    # Gap between activity and reporting
    $activityReportGap = ($latestReportDate - $lastActivityDate).Days
    Write-Host "Gap between latest activity and latest report: $activityReportGap days" -ForegroundColor White
}

# Activity distribution analysis
Write-Host "`n📊 RECENT ACTIVITY DISTRIBUTION:" -ForegroundColor Cyan

$recentDates = @{}
$cutoffDate = $lastActivityDate.AddDays(-30)  # Last 30 days

foreach ($record in $m365Data) {
    $activityDateStr = $record."Last Activity Date"
    if (![string]::IsNullOrWhiteSpace($activityDateStr) -and $activityDateStr -ne "") {
        try {
            $activityDate = [DateTime]::Parse($activityDateStr)
            if ($activityDate -ge $cutoffDate) {
                $dateKey = $activityDate.ToString('yyyy-MM-dd')
                if ($recentDates.ContainsKey($dateKey)) {
                    $recentDates[$dateKey]++
                } else {
                    $recentDates[$dateKey] = 1
                }
            }
        } catch {
            # Skip invalid dates
        }
    }
}

# Show top 10 most active days
$sortedDates = $recentDates.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10

Write-Host "Top 10 most active days (last 30 days):" -ForegroundColor White
foreach ($dateEntry in $sortedDates) {
    $date = [DateTime]::Parse($dateEntry.Key)
    $dayName = $date.ToString('dddd')
    Write-Host "- $($dateEntry.Key) ($dayName): $($dateEntry.Value) users" -ForegroundColor Gray
}

Write-Host "`n✅ Analysis complete!" -ForegroundColor Green