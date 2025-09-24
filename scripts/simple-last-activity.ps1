# Find Last Activity Date Analysis
Write-Host "Finding last activity date..." -ForegroundColor Green

# Use current directory and navigate to output
$outputPath = Join-Path (Get-Location) "output"
$m365File = Join-Path $outputPath "M365AppUsageUserDetail.csv"

Write-Host "Looking for file: $m365File" -ForegroundColor Yellow

if (-not (Test-Path $m365File)) {
    Write-Host "File not found. Checking what files are available..." -ForegroundColor Red
    if (Test-Path $outputPath) {
        $files = Get-ChildItem $outputPath -Name "*.csv"
        Write-Host "Available CSV files:" -ForegroundColor Yellow
        $files | ForEach-Object { Write-Host "- $_" -ForegroundColor White }
    } else {
        Write-Host "Output directory not found: $outputPath" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Loading data..." -ForegroundColor Yellow
$data = Import-Csv $m365File
Write-Host "Loaded $($data.Count) records" -ForegroundColor Green

# Find all valid activity dates
$validDates = @()
foreach ($record in $data) {
    $dateStr = $record."Last Activity Date"
    if (![string]::IsNullOrWhiteSpace($dateStr)) {
        try {
            $date = [DateTime]::Parse($dateStr)
            $validDates += $date
        } catch {
            # Skip invalid dates
        }
    }
}

if ($validDates.Count -eq 0) {
    Write-Host "No valid activity dates found" -ForegroundColor Red
    exit 1
}

$lastDate = ($validDates | Measure-Object -Maximum).Maximum
$firstDate = ($validDates | Measure-Object -Minimum).Minimum

Write-Host "`nRESULTS:" -ForegroundColor Cyan
Write-Host "Last activity date: $($lastDate.ToString('yyyy-MM-dd dddd'))" -ForegroundColor White
Write-Host "First activity date: $($firstDate.ToString('yyyy-MM-dd dddd'))" -ForegroundColor White
Write-Host "Date range: $(($lastDate - $firstDate).Days) days" -ForegroundColor White

# Count users with last activity date
$usersWithLastActivity = 0
foreach ($record in $data) {
    $dateStr = $record."Last Activity Date"
    if (![string]::IsNullOrWhiteSpace($dateStr)) {
        try {
            $date = [DateTime]::Parse($dateStr)
            if ($date -eq $lastDate) {
                $usersWithLastActivity++
            }
        } catch {
            # Skip invalid dates
        }
    }
}

Write-Host "Users with latest activity ($($lastDate.ToString('yyyy-MM-dd'))): $usersWithLastActivity" -ForegroundColor Green