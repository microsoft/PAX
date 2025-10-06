# Re-anonymize existing exploded file with realistic names and URLs
# Takes the existing anonymized file and updates UserIds to realistic names and anonymizes URLs

param(
    [string]$InputFile = "output\Sample_Purview_Copilot_Usage_Export_ExplodedArrays_Anonymized.csv",
    [string]$OutputFile = "output\Sample_Purview_Copilot_Usage_Export_ExplodedArrays_Anonymized_v2.csv"
)

Write-Host "Re-anonymizing with realistic names and URLs..." -ForegroundColor Cyan
Write-Host "Input: $InputFile" -ForegroundColor Gray
Write-Host "Output: $OutputFile" -ForegroundColor Gray

# Realistic first and last names
$firstNames = @('James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael', 'Linda', 'William', 'Barbara',
    'David', 'Elizabeth', 'Richard', 'Susan', 'Joseph', 'Jessica', 'Thomas', 'Sarah', 'Christopher', 'Karen',
    'Charles', 'Nancy', 'Daniel', 'Lisa', 'Matthew', 'Betty', 'Anthony', 'Margaret', 'Mark', 'Sandra',
    'Donald', 'Ashley', 'Steven', 'Kimberly', 'Andrew', 'Emily', 'Paul', 'Donna', 'Joshua', 'Michelle',
    'Kenneth', 'Carol', 'Kevin', 'Amanda', 'Brian', 'Melissa', 'George', 'Deborah', 'Timothy', 'Stephanie',
    'Ronald', 'Dorothy', 'Edward', 'Rebecca', 'Jason', 'Sharon', 'Jeffrey', 'Laura', 'Ryan', 'Cynthia',
    'Jacob', 'Amy', 'Gary', 'Kathleen', 'Nicholas', 'Angela', 'Eric', 'Shirley', 'Jonathan', 'Brenda',
    'Stephen', 'Emma', 'Larry', 'Anna', 'Justin', 'Pamela', 'Scott', 'Nicole', 'Brandon', 'Helen',
    'Benjamin', 'Samantha', 'Samuel', 'Katherine', 'Raymond', 'Christine', 'Gregory', 'Debra', 'Alexander', 'Rachel',
    'Patrick', 'Carolyn', 'Frank', 'Janet', 'Jack', 'Maria', 'Dennis', 'Catherine', 'Jerry', 'Heather')

$lastNames = @('Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
    'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin',
    'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez', 'Clark', 'Ramirez', 'Lewis', 'Robinson',
    'Walker', 'Young', 'Allen', 'King', 'Wright', 'Scott', 'Torres', 'Nguyen', 'Hill', 'Flores',
    'Green', 'Adams', 'Nelson', 'Baker', 'Hall', 'Rivera', 'Campbell', 'Mitchell', 'Carter', 'Roberts',
    'Gomez', 'Phillips', 'Evans', 'Turner', 'Diaz', 'Parker', 'Cruz', 'Edwards', 'Collins', 'Reyes',
    'Stewart', 'Morris', 'Morales', 'Murphy', 'Cook', 'Rogers', 'Gutierrez', 'Ortiz', 'Morgan', 'Cooper',
    'Peterson', 'Bailey', 'Reed', 'Kelly', 'Howard', 'Ramos', 'Kim', 'Cox', 'Ward', 'Richardson',
    'Watson', 'Brooks', 'Chavez', 'Wood', 'James', 'Bennett', 'Gray', 'Mendoza', 'Ruiz', 'Hughes',
    'Price', 'Alvarez', 'Castillo', 'Sanders', 'Patel', 'Myers', 'Long', 'Ross', 'Foster', 'Jimenez')

$fakeSiteDomains = @('contoso-corp', 'fabrikam-inc', 'adventureworks', 'northwind-data', 'woodgrove-bank',
    'tailspin-toys', 'wingtip-solutions', 'litware-tech', 'datum-systems', 'proseware-group',
    'blueyonder-air', 'coho-winery', 'alpine-skihouse', 'trey-research', 'margies-travel')

# Mapping tables to preserve duplicate patterns
$userIdMap = @{}
$urlMap = @{}
$nameIndex = 0

function New-RealisticEmail {
    param([string]$OldEmail)
    
    # Extract domain from old email
    $domain = ($OldEmail -split '@')[1]
    
    # Generate realistic name
    $first = $firstNames[$script:nameIndex % $firstNames.Count]
    $last = $lastNames[($script:nameIndex / $firstNames.Count) % $lastNames.Count]
    $script:nameIndex++
    
    return "$($first.ToLower()).$($last.ToLower())@$domain"
}

function New-AnonymousUrl {
    param([string]$OriginalUrl)
    
    if (-not $OriginalUrl -or $OriginalUrl -eq '') { return '' }
    
    try {
        $uri = [System.Uri]$OriginalUrl
        $fakeDomain = $fakeSiteDomains[(Get-Random -Minimum 0 -Maximum $fakeSiteDomains.Count)]
        
        if ($uri.Host -like "*sharepoint*" -or $uri.Host -like "*onedrive*") {
            $siteType = "sharepoint.com"
            $newPath = "/sites/$fakeDomain/documents/file$(Get-Random -Minimum 100 -Maximum 999).docx"
            return "https://$fakeDomain.$siteType$newPath"
        }
        elseif ($uri.Host -like "*office365*" -or $uri.Host -like "*outlook*") {
            return "https://outlook.office365.com/mail/inbox/id/$([Guid]::NewGuid().ToString())"
        }
        elseif ($uri.Host -like "*.youtube.com") {
            $videoId = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 11 | ForEach-Object { [char]$_ })
            return "https://www.youtube.com/watch?v=$videoId"
        }
        else {
            $tld = @('.com', '.org', '.net', '.io', '.co') | Get-Random
            return "https://www.example-site-$(Get-Random -Minimum 100 -Maximum 999)$tld/page/content"
        }
    }
    catch {
        return "https://www.example-fallback.com/resource/$(Get-Random -Minimum 1000 -Maximum 9999)"
    }
}

# Load existing anonymized data
Write-Host "`nLoading existing anonymized file..." -ForegroundColor Cyan
$data = Import-Csv -Path $InputFile
Write-Host "Loaded $($data.Count) records" -ForegroundColor Green

# Re-anonymize UserIds and URLs
Write-Host "`nRe-anonymizing UserIds and URLs..." -ForegroundColor Cyan
$processedCount = 0
$totalCount = $data.Count

foreach ($record in $data) {
    $processedCount++
    if ($processedCount % 50000 -eq 0) {
        $pct = [int](($processedCount / $totalCount) * 100)
        Write-Host "  Processed $processedCount / $totalCount records ($pct%)" -ForegroundColor Gray
    }
    
    # Re-anonymize UserId with realistic name (preserve duplicates)
    if ($record.UserId) {
        if (-not $userIdMap.ContainsKey($record.UserId)) {
            $userIdMap[$record.UserId] = New-RealisticEmail -OldEmail $record.UserId
        }
        $record.UserId = $userIdMap[$record.UserId]
    }
    
    # Re-anonymize Audit_UserId (should match UserId)
    if ($record.Audit_UserId) {
        if (-not $userIdMap.ContainsKey($record.Audit_UserId)) {
            $userIdMap[$record.Audit_UserId] = New-RealisticEmail -OldEmail $record.Audit_UserId
        }
        $record.Audit_UserId = $userIdMap[$record.Audit_UserId]
    }
    
    # Anonymize AccessedResource_SiteUrl (preserve duplicates)
    if ($record.AccessedResource_SiteUrl -and $record.AccessedResource_SiteUrl -ne '') {
        if (-not $urlMap.ContainsKey($record.AccessedResource_SiteUrl)) {
            $urlMap[$record.AccessedResource_SiteUrl] = New-AnonymousUrl -OriginalUrl $record.AccessedResource_SiteUrl
        }
        $record.AccessedResource_SiteUrl = $urlMap[$record.AccessedResource_SiteUrl]
    }
}

# Export re-anonymized data
Write-Host "`nExporting to $OutputFile..." -ForegroundColor Cyan
$data | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

Write-Host "`nRe-anonymization Summary:" -ForegroundColor Cyan
Write-Host "  Unique UserIds re-anonymized: $($userIdMap.Count)" -ForegroundColor Gray
Write-Host "  Unique URLs anonymized: $($urlMap.Count)" -ForegroundColor Gray

Write-Host "`nSample re-anonymized UserIds (first 10):" -ForegroundColor Cyan
$userIdMap.Values | Select-Object -Unique | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }

Write-Host "`nCompleted successfully!" -ForegroundColor Green
Write-Host "Output file: $OutputFile" -ForegroundColor Cyan
Write-Host "`nYou can replace the original file with:" -ForegroundColor DarkGray
Write-Host "  Move-Item '$OutputFile' '$InputFile' -Force" -ForegroundColor DarkGray
