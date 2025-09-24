# Script to find the earliest activity date for Copilot-licensed users
# Cross-references M365AppUsageUserDetail.csv with CopilotUsageUserDetail.csv

param(
    [string]$M365UsageCSV = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\M365AppUsageUserDetail.csv",
    [string]$CopilotUsageCSV = "C:\Users\bmiddendorf\OneDrive - Microsoft\Documents\Copilot Analytics Team\PurviewAPI\output\CopilotUsageUserDetail.csv"
)

Write-Host "Finding earliest activity date for Copilot-licensed users..." -ForegroundColor Green
Write-Host "Reading M365 usage data..." -ForegroundColor Yellow

# Read both datasets
$m365Data = Import-Csv $M365UsageCSV
$copilotData = Import-Csv $CopilotUsageCSV

Write-Host "M365 Usage records: $($m365Data.Count)" -ForegroundColor Cyan
Write-Host "Copilot Usage records: $($copilotData.Count)" -ForegroundColor Cyan

# Get list of Copilot-licensed users (everyone in the Copilot usage file)
$copilotUsers = $copilotData | Select-Object -ExpandProperty "User Principal Name" | Where-Object { $_ -ne "" }
$uniqueCopilotUsers = $copilotUsers | Sort-Object -Unique

Write-Host "Unique Copilot-licensed users: $($uniqueCopilotUsers.Count)" -ForegroundColor Cyan

# Find M365 activity for Copilot-licensed users
Write-Host "`nFiltering M365 data for Copilot-licensed users..." -ForegroundColor Yellow

$copilotUserM365Activity = $m365Data | Where-Object { 
    $_."User Principal Name" -in $uniqueCopilotUsers -and
    ![string]::IsNullOrWhiteSpace($_."Last Activity Date")
}

Write-Host "M365 activity records for Copilot users: $($copilotUserM365Activity.Count)" -ForegroundColor Cyan

# Find the earliest activity date
$activityDates = $copilotUserM365Activity | Where-Object { 
    ![string]::IsNullOrWhiteSpace($_."Last Activity Date") 
} | Select-Object -ExpandProperty "Last Activity Date" | ForEach-Object {
    try {
        [DateTime]::Parse($_)
    } catch {
        # Skip invalid dates
    }
} | Where-Object { $_ -ne $null }

if ($activityDates.Count -eq 0) {
    Write-Host "No valid activity dates found!" -ForegroundColor Red
    return
}

$earliestDate = $activityDates | Sort-Object | Select-Object -First 1
$latestDate = $activityDates | Sort-Object -Descending | Select-Object -First 1

Write-Host "`n=== RESULTS ===" -ForegroundColor Green
Write-Host "Earliest activity date for Copilot-licensed users: $($earliestDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
Write-Host "Latest activity date for Copilot-licensed users: $($latestDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
Write-Host "Date range spans: $((($latestDate - $earliestDate).Days)) days" -ForegroundColor White

# Find who had the earliest activity
$earliestActivityUsers = $copilotUserM365Activity | Where-Object { 
    try {
        [DateTime]::Parse($_."Last Activity Date") -eq $earliestDate
    } catch {
        $false
    }
}

Write-Host "`nUsers with earliest activity ($($earliestDate.ToString('yyyy-MM-dd'))):" -ForegroundColor Yellow
foreach ($user in $earliestActivityUsers | Select-Object -First 5) {
    Write-Host "- $($user.'User Principal Name')" -ForegroundColor White
}

if ($earliestActivityUsers.Count -gt 5) {
    Write-Host "... and $($earliestActivityUsers.Count - 5) more users" -ForegroundColor Gray
}

# Additional analysis: Activity distribution over time
Write-Host "`nActivity date distribution:" -ForegroundColor Yellow
$dateGroups = $activityDates | Group-Object { $_.ToString('yyyy-MM-dd') } | Sort-Object Name
foreach ($group in $dateGroups | Select-Object -First 10) {
    Write-Host "$($group.Name): $($group.Count) users" -ForegroundColor White
}

if ($dateGroups.Count -gt 10) {
    Write-Host "... and $($dateGroups.Count - 10) more dates" -ForegroundColor Gray
}

# Summary statistics
Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
Write-Host "📅 First Copilot user activity: $($earliestDate.ToString('dddd, MMMM dd, yyyy'))" -ForegroundColor Cyan
Write-Host "📊 Total activity records analyzed: $($copilotUserM365Activity.Count)" -ForegroundColor White
Write-Host "👥 Copilot users with M365 activity: $(($copilotUserM365Activity | Select-Object 'User Principal Name' -Unique).Count)" -ForegroundColor White

# Check if there are any report refresh dates that might indicate data collection periods
$reportDates = $m365Data | Where-Object { 
    $_."User Principal Name" -in $uniqueCopilotUsers 
} | Select-Object -ExpandProperty "Report Refresh Date" -Unique | Sort-Object

Write-Host "`nReport data collection periods:" -ForegroundColor Yellow
foreach ($date in $reportDates | Select-Object -First 5) {
    Write-Host "- $date" -ForegroundColor Gray
}

Write-Host "`n✅ Analysis complete!" -ForegroundColor Green