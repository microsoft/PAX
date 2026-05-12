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
          * Microsoft Graph application permissions (AuditLog.Read.All etc., admin-consented)
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
    Image tag to deploy (e.g. '1.11.1').

.PARAMETER ManagedIdentityResourceId
    Full resource ID of the user-assigned managed identity to attach.

.PARAMETER ManagedIdentityClientId
    Client ID (GUID) of the user-assigned managed identity. Passed to the script as
    AZURE_CLIENT_ID so Connect-MgGraph -Identity / Connect-AzAccount -Identity bind
    to the correct identity.

.PARAMETER ScriptArgs
    String[] of arguments forwarded to PAX_Purview_Audit_Log_Processor.ps1, e.g.
    @('-Days','30','-OutputPathSP','https://contoso.sharepoint.com/sites/PAX/Shared Documents/PAX_Output','-Auth','ManagedIdentity').

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
        -JobName 'pax-purview-daily' -AcrName 'paxacr' -ImageTag '1.11.1' `
        -ManagedIdentityResourceId '/subscriptions/.../userAssignedIdentities/uai-pax' `
        -ManagedIdentityClientId '11111111-2222-3333-4444-555555555555' `
        -ScriptArgs @('-Days','30','-OutputPathSP','https://contoso.sharepoint.com/sites/PAX/Shared Documents/PAX_Output','-Auth','ManagedIdentity','-Rollup') `
        -CronExpression '0 6 * * *'
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
    [Parameter()]          [string]   $CronExpression,
    [Parameter()]          [double]   $CpuCores             = 2.0,
    [Parameter()]          [double]   $MemoryGi             = 4.0,
    [Parameter()]          [int]      $ReplicaTimeoutSeconds = 21600
)

$ErrorActionPreference = 'Stop'

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

    # Identity / registry are immutable via update; ensure they are bound (idempotent).
    az containerapp job identity assign `
        --name              $JobName `
        --resource-group    $ResourceGroup `
        --user-assigned     $ManagedIdentityResourceId `
        --only-show-errors | Out-Null

    az containerapp job registry set `
        --name              $JobName `
        --resource-group    $ResourceGroup `
        --server            "$AcrName.azurecr.io" `
        --identity          $ManagedIdentityResourceId `
        --only-show-errors | Out-Null

    if ($CronExpression) {
        Write-Host "Note: Trigger type cannot be changed in-place. Recreate the job to switch Manual <-> Schedule." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ ACA Job '$JobName' deployed." -ForegroundColor Green
Write-Host ""
Write-Host "Manual run:" -ForegroundColor Cyan
Write-Host "  az containerapp job start --name $JobName --resource-group $ResourceGroup" -ForegroundColor Gray
Write-Host ""
Write-Host "Tail latest execution logs:" -ForegroundColor Cyan
Write-Host "  az containerapp job execution list --name $JobName --resource-group $ResourceGroup --output table" -ForegroundColor Gray
