<#
.SYNOPSIS
    Deploy or update an Azure Container Apps Job that runs the PAX Purview Audit Log
    Processor against a SharePoint or Fabric/OneLake destination.

.DESCRIPTION
    Provisions (or idempotently updates) an ACA Job using the pre-built container image
    from your Azure Container Registry. The job runs on a manual or scheduled trigger,
    authenticates via a user-assigned managed identity, and writes outputs to either
    SharePoint Online or Microsoft Fabric/OneLake.

    Prerequisites (run Grant-PAXPermissions.ps1 once first):
      - Azure subscription + resource group
      - Container Apps environment (Consumption-only is sufficient)
      - Azure Container Registry containing the pax-purview image (built from
        ../Dockerfile/PAX.Dockerfile)
      - User-assigned managed identity with:
          * AcrPull on the ACR
          * Microsoft Graph application permissions, admin-consented:
              AuditLogsQuery.Read.All, User.Read.All, Organization.Read.All,
              GroupMember.Read.All (always); AuditLogsQuery-Exchange.Read.All,
              AuditLogsQuery-OneDrive.Read.All, AuditLogsQuery-SharePoint.Read.All
              (only when PAX is invoked with -IncludeM365Usage).
              Note: Agent 365 scopes (CopilotPackages.Read.All, Application.Read.All)
              and the legacy AuditLog.Read.All Entra-audit scope are NOT used by PAX
              and are intentionally not granted.
          * Sites.ReadWrite.All + Files.ReadWrite.All (SharePoint mode), OR
            Contributor / Storage Blob Data Contributor on the Fabric workspace (Fabric mode)

.PARAMETER SubscriptionId
    Azure subscription ID hosting the ACA environment.

.PARAMETER ResourceGroup
    Resource group containing the ACA environment.

.PARAMETER EnvironmentName
    Name of the existing Container Apps environment.

.PARAMETER JobName
    Name for the ACA Job (created if missing, updated if present).

.PARAMETER AcrName
    Name of the Azure Container Registry (without .azurecr.io).

.PARAMETER ImageTag
    Image tag to deploy (e.g. '<x.y.z>', matching the SCRIPT_VERSION the image was built with).

.PARAMETER ManagedIdentityResourceId
    Full resource ID of the user-assigned managed identity to attach.

.PARAMETER ManagedIdentityClientId
    Client ID (GUID) of the user-assigned managed identity. Passed to the script as
    AZURE_CLIENT_ID so Connect-MgGraph -Identity / Connect-AzAccount -Identity bind
    to the correct identity.

.PARAMETER ScriptArgs
    String[] of arguments forwarded to PAX_Purview_Audit_Log_Processor.ps1, e.g.
    @('-OutputPath','https://contoso.sharepoint.com/sites/PAX/Shared Documents/PAX_Output','-Auth','ManagedIdentity').

    Destination model: each output stream has its own switch pair, and
    storage tier is inferred from each path's form (drive-rooted = Local,
    https://...sharepoint.com/... = SharePoint, https://...onelake.dfs.fabric.microsoft.com/...
    = Fabric).
    Per-stream switches:
        Purview audit            : -OutputPath           / -AppendFile
        EntraUsers / MAC license : -OutputPathUserInfo   / -AppendUserInfo
        Agent 365 catalog        : -OutputPathAgent365Info / -AppendAgent365Info
        Run log                  : -OutputPathLog        (no append pair)
    All supplied destinations in URL form must resolve to the same storage tier
    (no mixed Local/SP/Fabric in one run; the script rejects mixed-tier
    invocations at parameter validation). UNC paths are rejected on every
    destination switch.

    NOTE: PAX does not expose a `-Days` parameter; use `-StartDate yyyy-MM-dd -EndDate yyyy-MM-dd`
    to pin a window. With neither supplied, the script's default window is the last 30 days (UTC).

.PARAMETER BootstrapLogStorageAccount
    REQUIRED. Name of the Azure Storage account that backs the bootstrap-log file
    share. Will be created (Standard_LRS / StorageV2 / TLS1.2 / public-blob disabled)
    if it does not already exist in -ResourceGroup. Must be a globally-unique
    3-24 character lowercase alphanumeric string. Mounted into every job replica
    at /pax-logs; PAX writes its bootstrap log there so pre-flight
    failures (auth errors, bad -OutputPath URLs, parameter rejection) remain
    readable after container exit without spinning a replacement container.

.PARAMETER BootstrapLogShareName
    Name of the file share inside -BootstrapLogStorageAccount. Default
    'pax-bootstrap-logs'. Created if missing.

.PARAMETER BootstrapLogShareQuotaGi
    File-share quota in Gi. Default 5 (sufficient for thousands of bootstrap
    logs at ~10-50 KiB each).

.PARAMETER BootstrapLogStorageSku
    Storage account SKU when the account must be created. Default
    'Standard_LRS'. Use 'Standard_ZRS' for zonal redundancy.

.PARAMETER CronExpression
    Optional 5-field cron for scheduled trigger (e.g. '0 6 * * *' = 06:00 UTC daily).
    If omitted the job is created with a Manual trigger and must be started with
    `az containerapp job start`.

.PARAMETER CpuCores
    vCPU per replica. Default 2.0.

.PARAMETER MemoryGi
    Memory per replica in Gi. Default 4.0.

.PARAMETER ReplicaTimeoutSeconds
    Hard timeout per replica execution. Default 21600 (6 hours).

.EXAMPLE
    ./Deploy-PAXAcaJob.ps1 `
        -SubscriptionId 'xxx' -ResourceGroup 'rg-pax' -EnvironmentName 'cae-pax' `
        -JobName 'pax-purview-daily' -AcrName 'paxacr' -ImageTag '<x.y.z>' `
        -ManagedIdentityResourceId '/subscriptions/.../userAssignedIdentities/uai-pax' `
        -ManagedIdentityClientId '11111111-2222-3333-4444-555555555555' `
        -BootstrapLogStorageAccount 'paxbootstraplogs' `
        -ScriptArgs @('-OutputPath','https://contoso.sharepoint.com/sites/PAX/Shared Documents/PAX_Output','-Auth','ManagedIdentity','-Rollup') `
        -CronExpression '0 6 * * *'   # no -StartDate/-EndDate => default 30-day UTC window
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]   $SubscriptionId,
    [Parameter(Mandatory)] [string]   $ResourceGroup,
    [Parameter(Mandatory)] [string]   $EnvironmentName,
    [Parameter(Mandatory)] [string]   $JobName,
    [Parameter(Mandatory)] [string]   $AcrName,
    [Parameter(Mandatory)] [string]   $ImageTag,
    [Parameter(Mandatory)] [string]   $ManagedIdentityResourceId,
    [Parameter(Mandatory)] [string]   $ManagedIdentityClientId,
    [Parameter(Mandatory)] [string[]] $ScriptArgs,
    # Bootstrap-log durable mount (mandatory — required so pre-flight failures stay readable). The
    # storage account holds an Azure Files share that is mounted into every job replica
    # at /pax-logs. The PAX image sets $env:PAX_BOOTSTRAP_LOG_DIR=/pax-logs so the
    # bootstrap log lands on the share until the script resolves its final output path;
    # on pre-flight failure the bootstrap log survives container deletion, removing the
    # need to spin a replacement container for post-mortem.
    [Parameter(Mandatory)] [string]   $BootstrapLogStorageAccount,
    [Parameter()]          [string]   $BootstrapLogShareName     = 'pax-bootstrap-logs',
    [Parameter()]          [int]      $BootstrapLogShareQuotaGi  = 5,
    [Parameter()]          [string]   $BootstrapLogStorageSku    = 'Standard_LRS',
    [Parameter()]          [string]   $CronExpression,
    [Parameter()]          [double]   $CpuCores             = 2.0,
    [Parameter()]          [double]   $MemoryGi             = 4.0,
    [Parameter()]          [int]      $ReplicaTimeoutSeconds = 21600
)

$ErrorActionPreference = 'Stop'
# Note: $ErrorActionPreference does NOT catch native exit codes from `az`. Critical
# mutations below explicitly inspect $LASTEXITCODE and throw on non-zero (F-DEP-3).

function Test-AzCli {
    $az = Get-Command az -ErrorAction SilentlyContinue
    if (-not $az) { throw "Azure CLI ('az') not found on PATH. Install from https://aka.ms/installazurecli" }
}

Test-AzCli

Write-Host "Setting subscription context to $SubscriptionId..." -ForegroundColor Cyan
az account set --subscription $SubscriptionId | Out-Null

# Ensure containerapp extension is present + current.
Write-Host "Ensuring 'containerapp' Az CLI extension is installed..." -ForegroundColor Cyan
az extension add --name containerapp --upgrade --only-show-errors 2>$null | Out-Null

$image = "$AcrName.azurecr.io/pax-purview:$ImageTag"
Write-Host "Image: $image" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# Bootstrap-log durable mount provisioning (mandatory).
#
# Three idempotent stages:
#   1. Ensure the storage account exists (Standard_LRS / StorageV2 by default).
#   2. Ensure the file share exists with the requested quota.
#   3. Register the share with the ACA environment as a named storage entry. The
#      env-storage name 'pax-logs' is what the job's volumes[] block references.
# After job create/update we patch the job's template.volumes + container
# volumeMounts via `az resource update --set` (JSON path), which is the only
# clean way to attach a volume mount to an ACA Job — `az containerapp job
# create/update` does not expose --bind-mount flags for Jobs.
# ---------------------------------------------------------------------------
$envStorageName = 'pax-logs'
$mountPath      = '/pax-logs'

Write-Host "Ensuring storage account '$BootstrapLogStorageAccount' exists for bootstrap logs..." -ForegroundColor Cyan
$saExists = az storage account show --name $BootstrapLogStorageAccount --resource-group $ResourceGroup --only-show-errors 2>$null
if (-not $saExists) {
    az storage account create `
        --name              $BootstrapLogStorageAccount `
        --resource-group    $ResourceGroup `
        --sku               $BootstrapLogStorageSku `
        --kind              StorageV2 `
        --min-tls-version   TLS1_2 `
        --allow-blob-public-access false `
        --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "az storage account create failed for '$BootstrapLogStorageAccount' (exit $LASTEXITCODE). Pick a globally-unique 3-24 char lowercase-alphanumeric name." }
}

Write-Host "Fetching storage account key..." -ForegroundColor Cyan
$saKey = az storage account keys list --account-name $BootstrapLogStorageAccount --resource-group $ResourceGroup --query '[0].value' -o tsv --only-show-errors
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($saKey)) { throw "Failed to retrieve key for storage account '$BootstrapLogStorageAccount' (exit $LASTEXITCODE)." }

Write-Host "Ensuring file share '$BootstrapLogShareName' exists (quota ${BootstrapLogShareQuotaGi} Gi)..." -ForegroundColor Cyan
az storage share-rm create `
    --resource-group    $ResourceGroup `
    --storage-account   $BootstrapLogStorageAccount `
    --name              $BootstrapLogShareName `
    --quota             $BootstrapLogShareQuotaGi `
    --only-show-errors 2>$null | Out-Null
# share-rm create returns non-zero if the share already exists; verify post-condition
# rather than trusting exit code.
$shareCheck = az storage share-rm show --resource-group $ResourceGroup --storage-account $BootstrapLogStorageAccount --name $BootstrapLogShareName --only-show-errors 2>$null
if (-not $shareCheck) { throw "File share '$BootstrapLogShareName' does not exist after create attempt — check storage account name and permissions." }

Write-Host "Registering file share with ACA environment '$EnvironmentName' as storage '$envStorageName'..." -ForegroundColor Cyan
az containerapp env storage set `
    --name                          $EnvironmentName `
    --resource-group                $ResourceGroup `
    --storage-name                  $envStorageName `
    --azure-file-account-name       $BootstrapLogStorageAccount `
    --azure-file-account-key        $saKey `
    --azure-file-share-name         $BootstrapLogShareName `
    --access-mode                   ReadWrite `
    --only-show-errors | Out-Null
if ($LASTEXITCODE -ne 0) { throw "az containerapp env storage set failed (exit $LASTEXITCODE)." }

# Build args array for create/update — ACA Job's `--args` expects a single quoted string
# of space-separated arguments. Quote any value containing whitespace.
$quotedArgs = foreach ($a in $ScriptArgs) {
    if ($a -match '\s') { '"' + ($a -replace '"', '\"') + '"' } else { $a }
}
$argsString = ($quotedArgs -join ' ')

# Idempotent create-or-update
$existing = az containerapp job show --name $JobName --resource-group $ResourceGroup --only-show-errors 2>$null
if (-not $existing) {
    Write-Host "Creating ACA Job '$JobName'..." -ForegroundColor Cyan
    $triggerArgs = @('--trigger-type','Manual')
    if ($CronExpression) { $triggerArgs = @('--trigger-type','Schedule','--cron-expression', $CronExpression) }

    az containerapp job create `
        --name              $JobName `
        --resource-group    $ResourceGroup `
        --environment       $EnvironmentName `
        @triggerArgs `
        --replica-timeout   $ReplicaTimeoutSeconds `
        --replica-retry-limit 0 `
        --parallelism       1 `
        --replica-completion-count 1 `
        --image             $image `
        --cpu               $CpuCores `
        --memory            ("{0}Gi" -f $MemoryGi) `
        --mi-user-assigned  $ManagedIdentityResourceId `
        --registry-server   "$AcrName.azurecr.io" `
        --registry-identity $ManagedIdentityResourceId `
        --env-vars          "AZURE_CLIENT_ID=$ManagedIdentityClientId" `
        --args              $argsString `
        --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "az containerapp job create failed (exit $LASTEXITCODE)." }
}
else {
    Write-Host "Updating existing ACA Job '$JobName'..." -ForegroundColor Cyan
    az containerapp job update `
        --name              $JobName `
        --resource-group    $ResourceGroup `
        --image             $image `
        --cpu               $CpuCores `
        --memory            ("{0}Gi" -f $MemoryGi) `
        --replica-timeout   $ReplicaTimeoutSeconds `
        --set-env-vars      "AZURE_CLIENT_ID=$ManagedIdentityClientId" `
        --args              $argsString `
        --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "az containerapp job update failed (exit $LASTEXITCODE)." }

    # Identity / registry are immutable via update; ensure they are bound (idempotent).
    az containerapp job identity assign `
        --name              $JobName `
        --resource-group    $ResourceGroup `
        --user-assigned     $ManagedIdentityResourceId `
        --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warning "az containerapp job identity assign returned exit $LASTEXITCODE (continuing; may already be bound)." }

    az containerapp job registry set `
        --name              $JobName `
        --resource-group    $ResourceGroup `
        --server            "$AcrName.azurecr.io" `
        --identity          $ManagedIdentityResourceId `
        --only-show-errors | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warning "az containerapp job registry set returned exit $LASTEXITCODE (continuing; may already be bound)." }

    if ($CronExpression) {
        Write-Host "Note: Trigger type cannot be changed in-place. Recreate the job to switch Manual <-> Schedule." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Attach the bootstrap-log volume + mount to the job. ACA Jobs do not expose a
# --bind-mount / --volume flag on create/update, so we patch the ARM resource
# directly. Both --set calls are idempotent (last write wins).
# ---------------------------------------------------------------------------
Write-Host "Attaching bootstrap-log volume mount to job '$JobName' at $mountPath..." -ForegroundColor Cyan
$jobId = az containerapp job show --name $JobName --resource-group $ResourceGroup --query 'id' -o tsv --only-show-errors
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($jobId)) { throw "Could not resolve resource id for job '$JobName' (exit $LASTEXITCODE)." }

# Discover the container name ACA assigned (defaults to the job name, but be defensive).
$containerName = az containerapp job show --name $JobName --resource-group $ResourceGroup --query 'properties.template.containers[0].name' -o tsv --only-show-errors
if ([string]::IsNullOrWhiteSpace($containerName)) { $containerName = $JobName }

$volumesJson = (@(@{ name = $envStorageName; storageType = 'AzureFile'; storageName = $envStorageName }) | ConvertTo-Json -Compress -Depth 5)
$mountsJson  = (@(@{ volumeName = $envStorageName; mountPath = $mountPath })                              | ConvertTo-Json -Compress -Depth 5)
# `az resource update --set` expects a string the CLI will parse — pass JSON literal.
# Use single outer quotes so PowerShell does not interpolate the inner braces.
az resource update --ids $jobId --set "properties.template.volumes=$volumesJson" --only-show-errors | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to set properties.template.volumes on job '$JobName' (exit $LASTEXITCODE)." }
az resource update --ids $jobId --set "properties.template.containers[0].volumeMounts=$mountsJson" --only-show-errors | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to set volumeMounts on container '$containerName' (exit $LASTEXITCODE)." }

Write-Host ""
Write-Host "✅ ACA Job '$JobName' deployed." -ForegroundColor Green
Write-Host "   Bootstrap-log share : $BootstrapLogStorageAccount / $BootstrapLogShareName (mounted at $mountPath)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Manual run:" -ForegroundColor Cyan
Write-Host "  az containerapp job start --name $JobName --resource-group $ResourceGroup" -ForegroundColor Gray
Write-Host ""
Write-Host "Tail latest execution logs:" -ForegroundColor Cyan
Write-Host "  az containerapp job execution list --name $JobName --resource-group $ResourceGroup --output table" -ForegroundColor Gray
