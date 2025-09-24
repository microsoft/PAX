# Find First Copilot Licensed User Activity
# Cross-references Copilot licensing data with M365 activity to find the earliest activity by a licensed user

Write-Host "🔍 FIRST COPILOT LICENSED USER ACTIVITY ANALYSIS" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# File paths
$outputPath = Join-Path (Get-Location) "output"
$copilotFile = Join-Path $outputPath "CopilotUsageUserDetail.csv"
$m365File = Join-Path $outputPath "M365AppUsageUserDetail.csv"

Write-Host "📂 Loading data files..." -ForegroundColor Yellow

# Check if files exist
if (-not (Test-Path $copilotFile)) {
    Write-Host "❌ Error: CopilotUsageUserDetail.csv not found in output folder" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $m365File)) {
    Write-Host "❌ Error: M365AppUsageUserDetail.csv not found in output folder" -ForegroundColor Red
    exit 1
}

# Load Copilot usage data to get licensed users and their license periods
Write-Host "Loading Copilot usage data..." -ForegroundColor White
$copilotData = Import-Csv $copilotFile
Write-Host "✅ Loaded $($copilotData.Count) Copilot usage records" -ForegroundColor Green

# Load M365 activity data
Write-Host "Loading M365 activity data..." -ForegroundColor White
$m365Data = Import-Csv $m365File
Write-Host "✅ Loaded $($m365Data.Count) M365 activity records" -ForegroundColor Green

Write-Host "`n📊 ANALYZING COPILOT LICENSING TIMELINE..." -ForegroundColor Yellow

# Build a timeline of when each user was licensed for Copilot
$userLicenseTimeline = @{}

foreach ($record in $copilotData) {
    $userPrincipalName = $record."User Principal Name"
    $reportDateStr = $record."Report Refresh Date"
    
    if (![string]::IsNullOrWhiteSpace($userPrincipalName) -and ![string]::IsNullOrWhiteSpace($reportDateStr)) {
        try {
            $reportDate = [DateTime]::Parse($reportDateStr)
            
            if (-not $userLicenseTimeline.ContainsKey($userPrincipalName)) {
                $userLicenseTimeline[$userPrincipalName] = @{
                    FirstLicenseDate = $reportDate
                    LastLicenseDate = $reportDate
                }
            } else {
                if ($reportDate -lt $userLicenseTimeline[$userPrincipalName].FirstLicenseDate) {
                    $userLicenseTimeline[$userPrincipalName].FirstLicenseDate = $reportDate
                }
                if ($reportDate -gt $userLicenseTimeline[$userPrincipalName].LastLicenseDate) {
                    $userLicenseTimeline[$userPrincipalName].LastLicenseDate = $reportDate
                }
            }
        } catch {
            # Skip invalid dates
        }
    }
}

Write-Host "📋 Found license data for $($userLicenseTimeline.Keys.Count) unique Copilot users" -ForegroundColor Cyan

# Show licensing timeline summary
$earliestLicense = ($userLicenseTimeline.Values.FirstLicenseDate | Measure-Object -Minimum).Minimum
$latestLicense = ($userLicenseTimeline.Values.LastLicenseDate | Measure-Object -Maximum).Maximum

Write-Host "Earliest Copilot license: $($earliestLicense.ToString('yyyy-MM-dd dddd'))" -ForegroundColor White
Write-Host "Latest Copilot license: $($latestLicense.ToString('yyyy-MM-dd dddd'))" -ForegroundColor White

Write-Host "`n🔍 FINDING FIRST LICENSED USER ACTIVITY..." -ForegroundColor Yellow

# Find all activities by licensed users and determine which occurred during their license period
$licensedUserActivities = @()

foreach ($record in $m365Data) {
    $userPrincipalName = $record."User Principal Name"
    $activityDateStr = $record."Last Activity Date"
    
    if (![string]::IsNullOrWhiteSpace($userPrincipalName) -and ![string]::IsNullOrWhiteSpace($activityDateStr)) {
        # Check if this user was ever licensed for Copilot
        if ($userLicenseTimeline.ContainsKey($userPrincipalName)) {
            try {
                $activityDate = [DateTime]::Parse($activityDateStr)
                $userLicense = $userLicenseTimeline[$userPrincipalName]
                
                # Check if the activity occurred during or after the license period
                if ($activityDate -ge $userLicense.FirstLicenseDate) {
                    $licensedUserActivities += [PSCustomObject]@{
                        UserPrincipalName = $userPrincipalName
                        ActivityDate = $activityDate
                        FirstLicenseDate = $userLicense.FirstLicenseDate
                        LastLicenseDate = $userLicense.LastLicenseDate
                        DaysAfterLicense = ($activityDate - $userLicense.FirstLicenseDate).Days
                    }
                }
            } catch {
                # Skip invalid dates
            }
        }
    }
}

if ($licensedUserActivities.Count -eq 0) {
    Write-Host "❌ No activities found for licensed Copilot users" -ForegroundColor Red
    exit 1
}

# Find the earliest activity by a licensed user
$earliestLicensedActivity = ($licensedUserActivities | Sort-Object ActivityDate | Select-Object -First 1)

Write-Host "`n🎯 RESULTS:" -ForegroundColor Cyan
Write-Host "First activity by a Copilot-licensed user:" -ForegroundColor White
Write-Host "📅 Date: $($earliestLicensedActivity.ActivityDate.ToString('yyyy-MM-dd dddd'))" -ForegroundColor Green
Write-Host "👤 User: $($earliestLicensedActivity.UserPrincipalName)" -ForegroundColor Green
Write-Host "📝 User's first license date: $($earliestLicensedActivity.FirstLicenseDate.ToString('yyyy-MM-dd dddd'))" -ForegroundColor White
Write-Host "⏱️  Days after license: $($earliestLicensedActivity.DaysAfterLicense) days" -ForegroundColor White

# Show some context - other early activities
Write-Host "`n📊 FIRST 10 LICENSED USER ACTIVITIES:" -ForegroundColor Yellow
$firstTenActivities = $licensedUserActivities | Sort-Object ActivityDate | Select-Object -First 10

foreach ($activity in $firstTenActivities) {
    $daysAfter = if ($activity.DaysAfterLicense -eq 0) { "same day" } else { "$($activity.DaysAfterLicense) days later" }
    Write-Host "- $($activity.ActivityDate.ToString('yyyy-MM-dd')): $($activity.UserPrincipalName) ($daysAfter)" -ForegroundColor Gray
}

# Analysis of license-to-activity timing
Write-Host "`n📈 LICENSE-TO-ACTIVITY TIMING ANALYSIS:" -ForegroundColor Yellow

$sameDayActivities = ($licensedUserActivities | Where-Object { $_.DaysAfterLicense -eq 0 }).Count
$withinWeekActivities = ($licensedUserActivities | Where-Object { $_.DaysAfterLicense -le 7 }).Count
$withinMonthActivities = ($licensedUserActivities | Where-Object { $_.DaysAfterLicense -le 30 }).Count

Write-Host "Activities on same day as license: $sameDayActivities" -ForegroundColor White
Write-Host "Activities within 1 week of license: $withinWeekActivities" -ForegroundColor White
Write-Host "Activities within 1 month of license: $withinMonthActivities" -ForegroundColor White
Write-Host "Total licensed user activities: $($licensedUserActivities.Count)" -ForegroundColor White

Write-Host "`n✅ Analysis complete!" -ForegroundColor Green