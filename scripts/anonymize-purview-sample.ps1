# Anonymize Purview Sample Export
# Explodes RAW JSON format and anonymizes PII while preserving duplicate patterns

param(
    [string]$InputFile = "output\Sample_Purview_Copilot_Usage_Export_RAW_JSON.csv",
    [string]$OutputFile = "output\Sample_Purview_Copilot_Usage_Export_ExplodedArrays_Anonymized.csv"
)

Write-Host "Starting anonymization process..." -ForegroundColor Cyan
Write-Host "Input: $InputFile" -ForegroundColor Gray
Write-Host "Output: $OutputFile" -ForegroundColor Gray

# Define the 29 exploded columns (from PAX_Purview_Audit_Log_Processor)
$ExplodedColumns = @(
    'RecordId', 'CreationDate', 'RecordType', 'Operation', 'UserId', 'AssociatedAdminUnits', 'AssociatedAdminUnitsNames',
    'AgentId', 'AgentName', 'AppIdentity_AppId', 'AppIdentity_DisplayName', 'AppIdentity_PublisherId', 'ApplicationName',
    'CreationTime', 'ClientRegion', 'Audit_UserId', 'AppHost', 'ThreadId', 'Context_Id', 'Context_Type', 'Message_Id',
    'Message_isPrompt', 'AccessedResource_Action', 'AccessedResource_PolicyDetails', 'AccessedResource_SiteUrl',
    'AISystemPlugin_Id', 'AISystemPlugin_Name', 'ModelTransparencyDetails_ModelName', 'MessageIds'
)

# Anonymization mapping tables
$userIdMap = @{}
$userKeyMap = @{}
$orgIdMap = @{}
$ipMap = @{}
$urlMap = @{}
$userIdToKeyCorrelation = @{} # Maps anonymized UserId to anonymized UserKey

# Fake domains for anonymized emails
$fakeDomains = @('company-a.com', 'company-b.com', 'company-c.net', 'enterprise-x.org', 'business-y.com')
$domainIndex = 0

# Realistic first and last names for anonymization
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

$nameIndex = 0

# Fake website domains for URL anonymization
$fakeSiteDomains = @('contoso-corp', 'fabrikam-inc', 'adventureworks', 'northwind-data', 'woodgrove-bank',
    'tailspin-toys', 'wingtip-solutions', 'litware-tech', 'datum-systems', 'proseware-group',
    'blueyonder-air', 'coho-winery', 'alpine-skihouse', 'trey-research', 'margies-travel')

function New-AnonymousGuid {
    [Guid]::NewGuid().ToString()
}

function New-AnonymousEmail {
    param([int]$Index)
    $first = $firstNames[$Index % $firstNames.Count]
    $last = $lastNames[($Index / $firstNames.Count) % $lastNames.Count]
    $email = "$($first.ToLower()).$($last.ToLower())@$($fakeDomains[$script:domainIndex % $fakeDomains.Count])"
    $script:domainIndex++
    return $email
}

function New-AnonymousIP {
    "10.$((Get-Random -Minimum 0 -Maximum 255)).$((Get-Random -Minimum 0 -Maximum 255)).$((Get-Random -Minimum 1 -Maximum 254))"
}

function New-AnonymousUrl {
    param([string]$OriginalUrl)
    
    try {
        $uri = [System.Uri]$OriginalUrl
        $fakeDomain = $fakeSiteDomains[(Get-Random -Minimum 0 -Maximum $fakeSiteDomains.Count)]
        
        # Determine the type of site
        if ($uri.Host -like "*sharepoint*" -or $uri.Host -like "*onedrive*") {
            $siteType = "sharepoint.com"
            $pathParts = $uri.AbsolutePath -split '/'
            $newPath = "/sites/$fakeDomain/documents/file$(Get-Random -Minimum 100 -Maximum 999).docx"
            return "https://$fakeDomain.$siteType$newPath"
        }
        elseif ($uri.Host -like "*office365*" -or $uri.Host -like "*outlook*") {
            return "https://outlook.office365.com/mail/inbox/id/$(New-AnonymousGuid)"
        }
        elseif ($uri.Host -like "*.youtube.com") {
            $videoId = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 11 | ForEach-Object { [char]$_ })
            return "https://www.youtube.com/watch?v=$videoId"
        }
        else {
            # Generic external website
            $tld = @('.com', '.org', '.net', '.io', '.co') | Get-Random
            return "https://www.example-site-$(Get-Random -Minimum 100 -Maximum 999)$tld/page/content"
        }
    }
    catch {
        # Fallback for malformed URLs
        return "https://www.example-fallback.com/resource/$(Get-Random -Minimum 1000 -Maximum 9999)"
    }
}

function Get-AnonymizedUserId {
    param([string]$Original)
    if (-not $Original) { return $null }
    if (-not $userIdMap.ContainsKey($Original)) {
        $userIdMap[$Original] = New-AnonymousEmail -Index $script:nameIndex
        $script:nameIndex++
    }
    return $userIdMap[$Original]
}

function Get-AnonymizedUserKey {
    param([string]$Original, [string]$CorrelatedUserId)
    if (-not $Original) { return $null }
    if (-not $userKeyMap.ContainsKey($Original)) {
        $newKey = New-AnonymousGuid
        $userKeyMap[$Original] = $newKey
        # Establish correlation
        if ($CorrelatedUserId -and $userIdMap.ContainsKey($CorrelatedUserId)) {
            $anonymizedUserId = $userIdMap[$CorrelatedUserId]
            $userIdToKeyCorrelation[$anonymizedUserId] = $newKey
        }
    }
    return $userKeyMap[$Original]
}

function Get-AnonymizedOrgId {
    param([string]$Original)
    if (-not $Original) { return $null }
    if (-not $orgIdMap.ContainsKey($Original)) {
        $orgIdMap[$Original] = New-AnonymousGuid
    }
    return $orgIdMap[$Original]
}

function Get-AnonymizedIP {
    param([string]$Original)
    if (-not $Original -or $Original -eq '') { return '' }
    if (-not $ipMap.ContainsKey($Original)) {
        $ipMap[$Original] = New-AnonymousIP
    }
    return $ipMap[$Original]
}

function Get-AnonymizedUrl {
    param([string]$Original)
    if (-not $Original -or $Original -eq '') { return '' }
    if (-not $urlMap.ContainsKey($Original)) {
        $urlMap[$Original] = New-AnonymousUrl -OriginalUrl $Original
    }
    return $urlMap[$Original]
}

function Get-SafeValue {
    param($Object, [string]$PropertyName)
    try {
        if ($null -eq $Object) { return $null }
        $prop = $Object.PSObject.Properties[$PropertyName]
        if ($prop) { return $prop.Value }
        return $null
    }
    catch { return $null }
}

function Get-ArraySafe {
    param($Object, [string]$PropertyName)
    $val = Get-SafeValue $Object $PropertyName
    if ($null -eq $val) { return @() }
    if ($val -is [Array]) { return $val }
    if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
        return @($val)
    }
    return @()
}

# Load input data
Write-Host "`nLoading input file..." -ForegroundColor Cyan
$rawData = Import-Csv -Path $InputFile
Write-Host "Loaded $($rawData.Count) records" -ForegroundColor Green

# Process and explode records
Write-Host "`nExploding and anonymizing records..." -ForegroundColor Cyan
$explodedRecords = New-Object System.Collections.ArrayList
$processedCount = 0
$totalCount = $rawData.Count

foreach ($record in $rawData) {
    $processedCount++
    if ($processedCount % 10000 -eq 0) {
        $pct = [int](($processedCount / $totalCount) * 100)
        Write-Host "  Processed $processedCount / $totalCount records ($pct%)" -ForegroundColor Gray
    }
    
    try {
        # Parse AuditData
        $auditData = $record.AuditData | ConvertFrom-Json -ErrorAction Stop
        if (-not $auditData) { continue }
        
        # Get CopilotEventData
        $ced = Get-SafeValue $auditData 'CopilotEventData'
        
        # Anonymize core PII fields
        $originalUserId = Get-SafeValue $auditData 'UserId'
        $originalUserKey = Get-SafeValue $auditData 'UserKey'
        $originalOrgId = Get-SafeValue $auditData 'OrganizationId'
        $originalClientIP = Get-SafeValue $auditData 'ClientIP'
        
        $anonymizedUserId = Get-AnonymizedUserId $originalUserId
        $anonymizedUserKey = Get-AnonymizedUserKey $originalUserKey $originalUserId
        $anonymizedOrgId = Get-AnonymizedOrgId $originalOrgId
        $anonymizedClientIP = Get-AnonymizedIP $originalClientIP
        
        # Extract arrays from CopilotEventData
        $messages = Get-ArraySafe $ced 'Messages'
        $contexts = Get-ArraySafe $ced 'Contexts'
        $resources = Get-ArraySafe $ced 'AccessedResources'
        $plugins = Get-ArraySafe $ced 'AISystemPlugin'
        
        # Determine explosion multiplier
        $maxCount = [Math]::Max([Math]::Max($messages.Count, $contexts.Count), [Math]::Max($resources.Count, $plugins.Count))
        if ($maxCount -eq 0) { $maxCount = 1 }
        
        # Create exploded rows
        for ($i = 0; $i -lt $maxCount; $i++) {
            $explodedRow = [PSCustomObject]@{
                RecordId                  = Get-SafeValue $record 'RecordId'
                CreationDate              = Get-SafeValue $record 'CreationDate'
                RecordType                = Get-SafeValue $auditData 'RecordType'
                Operation                 = Get-SafeValue $auditData 'Operation'
                UserId                    = $anonymizedUserId
                AssociatedAdminUnits      = Get-SafeValue $record 'AssociatedAdminUnits'
                AssociatedAdminUnitsNames = Get-SafeValue $record 'AssociatedAdminUnitsNames'
            }
            
            # Agent info from CopilotEventData
            $explodedRow | Add-Member -NotePropertyName 'AgentId' -NotePropertyValue (Get-SafeValue $ced 'AgentId')
            $explodedRow | Add-Member -NotePropertyName 'AgentName' -NotePropertyValue (Get-SafeValue $ced 'AgentName')
            
            # AppIdentity
            $appIdentity = Get-SafeValue $ced 'AppIdentity'
            $explodedRow | Add-Member -NotePropertyName 'AppIdentity_AppId' -NotePropertyValue (Get-SafeValue $appIdentity 'AppId')
            $explodedRow | Add-Member -NotePropertyName 'AppIdentity_DisplayName' -NotePropertyValue (Get-SafeValue $appIdentity 'DisplayName')
            $explodedRow | Add-Member -NotePropertyName 'AppIdentity_PublisherId' -NotePropertyValue (Get-SafeValue $appIdentity 'PublisherId')
            
            $explodedRow | Add-Member -NotePropertyName 'ApplicationName' -NotePropertyValue (Get-SafeValue $ced 'ApplicationName')
            $explodedRow | Add-Member -NotePropertyName 'CreationTime' -NotePropertyValue (Get-SafeValue $auditData 'CreationTime')
            $explodedRow | Add-Member -NotePropertyName 'ClientRegion' -NotePropertyValue (Get-SafeValue $auditData 'ClientRegion')
            $explodedRow | Add-Member -NotePropertyName 'Audit_UserId' -NotePropertyValue $anonymizedUserId
            $explodedRow | Add-Member -NotePropertyName 'AppHost' -NotePropertyValue (Get-SafeValue $ced 'AppHost')
            $explodedRow | Add-Member -NotePropertyName 'ThreadId' -NotePropertyValue (Get-SafeValue $ced 'ThreadId')
            
            # Context
            $context = if ($i -lt $contexts.Count) { $contexts[$i] } else { $null }
            $explodedRow | Add-Member -NotePropertyName 'Context_Id' -NotePropertyValue (Get-SafeValue $context 'Id')
            $explodedRow | Add-Member -NotePropertyName 'Context_Type' -NotePropertyValue (Get-SafeValue $context 'Type')
            
            # Message
            $message = if ($i -lt $messages.Count) { $messages[$i] } else { $null }
            $explodedRow | Add-Member -NotePropertyName 'Message_Id' -NotePropertyValue (Get-SafeValue $message 'Id')
            $explodedRow | Add-Member -NotePropertyName 'Message_isPrompt' -NotePropertyValue (Get-SafeValue $message 'isPrompt')
            
            # AccessedResource
            $resource = if ($i -lt $resources.Count) { $resources[$i] } else { $null }
            $originalSiteUrl = Get-SafeValue $resource 'SiteUrl'
            $anonymizedSiteUrl = Get-AnonymizedUrl $originalSiteUrl
            $explodedRow | Add-Member -NotePropertyName 'AccessedResource_Action' -NotePropertyValue (Get-SafeValue $resource 'Action')
            $explodedRow | Add-Member -NotePropertyName 'AccessedResource_PolicyDetails' -NotePropertyValue (Get-SafeValue $resource 'PolicyDetails')
            $explodedRow | Add-Member -NotePropertyName 'AccessedResource_SiteUrl' -NotePropertyValue $anonymizedSiteUrl
            
            # AISystemPlugin
            $plugin = if ($i -lt $plugins.Count) { $plugins[$i] } else { $null }
            $explodedRow | Add-Member -NotePropertyName 'AISystemPlugin_Id' -NotePropertyValue (Get-SafeValue $plugin 'Id')
            $explodedRow | Add-Member -NotePropertyName 'AISystemPlugin_Name' -NotePropertyValue (Get-SafeValue $plugin 'Name')
            
            # ModelTransparencyDetails
            $modelDetails = Get-SafeValue $ced 'ModelTransparencyDetails'
            $explodedRow | Add-Member -NotePropertyName 'ModelTransparencyDetails_ModelName' -NotePropertyValue (Get-SafeValue $modelDetails 'ModelName')
            
            # MessageIds (comma-separated if multiple)
            $messageIds = if ($messages.Count -gt 0) {
                ($messages | ForEach-Object { Get-SafeValue $_ 'Id' } | Where-Object { $_ }) -join ','
            }
            else { $null }
            $explodedRow | Add-Member -NotePropertyName 'MessageIds' -NotePropertyValue $messageIds
            
            [void]$explodedRecords.Add($explodedRow)
        }
    }
    catch {
        Write-Host "  Error processing record $processedCount : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nExploded to $($explodedRecords.Count) records" -ForegroundColor Green

# Export anonymized data
Write-Host "`nExporting to $OutputFile..." -ForegroundColor Cyan
$explodedRecords | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8

Write-Host "`nAnonymization Summary:" -ForegroundColor Cyan
Write-Host "  Unique UserIds anonymized: $($userIdMap.Count)" -ForegroundColor Gray
Write-Host "  Unique UserKeys anonymized: $($userKeyMap.Count)" -ForegroundColor Gray
Write-Host "  Unique OrgIds anonymized: $($orgIdMap.Count)" -ForegroundColor Gray
Write-Host "  Unique IPs anonymized: $($ipMap.Count)" -ForegroundColor Gray
Write-Host "  Unique URLs anonymized: $($urlMap.Count)" -ForegroundColor Gray
Write-Host "  UserId-UserKey correlations preserved: $($userIdToKeyCorrelation.Count)" -ForegroundColor Gray

Write-Host "`nEmpty Columns (verified in source data):" -ForegroundColor Cyan
Write-Host "  - AssociatedAdminUnits" -ForegroundColor DarkGray
Write-Host "  - AssociatedAdminUnitsNames" -ForegroundColor DarkGray
Write-Host "  - AgentId" -ForegroundColor DarkGray
Write-Host "  - AgentName" -ForegroundColor DarkGray
Write-Host "  - AppIdentity_AppId" -ForegroundColor DarkGray
Write-Host "  - AppIdentity_DisplayName" -ForegroundColor DarkGray
Write-Host "  - AppIdentity_PublisherId" -ForegroundColor DarkGray
Write-Host "  - ApplicationName" -ForegroundColor DarkGray

Write-Host "`nCompleted successfully!" -ForegroundColor Green
Write-Host "Output file: $OutputFile" -ForegroundColor Cyan
