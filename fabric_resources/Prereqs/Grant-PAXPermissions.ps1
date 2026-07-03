<#
.SYNOPSIS
    Provision and grant ALL prerequisite permissions for an unattended PAX run on
    Azure Container Apps Jobs writing to SharePoint or Fabric/OneLake.

.DESCRIPTION
    One-time bootstrap script. Performs (idempotently):

      1. Creates (or reuses) a user-assigned managed identity.
      2. Grants AcrPull on the specified Azure Container Registry to the identity.
      3. Grants Microsoft Graph application permissions and ADMIN-CONSENTS them on
         the identity's service principal:
           - AuditLogsQuery.Read.All                  (always — /security/auditLog/queries)
           - User.Read.All                            (always — /users for EntraUsers)
           - Organization.Read.All                    (always — /subscribedSkus for license map)
           - GroupMember.Read.All                     (always — /groups, /groups/{id}/members,
                                                       only consumed when -GroupNames is passed
                                                       to PAX, but pre-granted so the same
                                                       image works for both call shapes)
           - AuditLogsQuery-Exchange.Read.All         (-IncludeM365Usage only)
           - AuditLogsQuery-OneDrive.Read.All         (-IncludeM365Usage only)
           - AuditLogsQuery-SharePoint.Read.All       (-IncludeM365Usage only)
           - CopilotPackages.Read.All                 (-IncludeAgent365 only — opt-in / pre-GA)
           - Application.Read.All                     (-IncludeAgent365 only — opt-in / pre-GA)
           - Sites.ReadWrite.All, Files.ReadWrite.All (SharePoint mode only)

         OPT-IN — Microsoft Agent 365 (app-only, pre-GA):
           PAX supports Agent 365 enrichment (-IncludeAgent365Info / -OnlyAgent365Info)
           under -Auth ManagedIdentity (and -Auth AppRegistration) app-only, using the
           application permissions CopilotPackages.Read.All + Application.Read.All with NO
           interactive sign-in. These are NOT granted by default (least-privilege). Pass
           -IncludeAgent365 to grant + admin-consent them. This path is pre-GA — validate
           in your tenant before relying on it in production. (Delegated Agent 365 instead
           relies on the signed-in user's AI Admin / Global Admin directory role.)

         NOT granted (intentionally):
           - AuditLog.Read.All        — different endpoint (Entra audit activities), not
                                        used by PAX.

      4. (SharePoint mode) Adds Sites.ReadWrite.All and Files.ReadWrite.All to the
         scope list above so PAX can write outputs to the destination SharePoint
         document library.
      5. (Fabric mode) Grants Storage Blob Data Contributor on the Fabric workspace's
         OneLake at workspace scope.

    Requires the operator to be a Global Administrator (or Privileged Role Administrator
    for the Graph admin-consent step).

.PARAMETER SubscriptionId
    Subscription ID where the managed identity, ACR, and (Fabric mode) workspace live.

.PARAMETER ResourceGroup
    Resource group for the managed identity.

.PARAMETER ManagedIdentityName
    Name of the user-assigned managed identity (created if missing).

.PARAMETER Location
    Azure region for the managed identity (e.g. 'eastus').

.PARAMETER AcrResourceId
    Full Azure resource ID of the ACR. Required.

.PARAMETER Mode
    'SharePoint' or 'Fabric'. Drives which downstream permissions are granted.

.PARAMETER FabricWorkspaceResourceId
    Required when -Mode Fabric. Full resource ID of the Fabric workspace
    (provider Microsoft.Fabric/workspaces or Microsoft.PowerBIDedicated/workspaceCollections
    depending on tenant; pass the OneLake-backed workspace resource ID).

.PARAMETER IncludeM365Usage
    Grant the workload-scoped audit variants required by PAX's -IncludeM365Usage switch
    (AuditLogsQuery-Exchange.Read.All, AuditLogsQuery-OneDrive.Read.All,
    AuditLogsQuery-SharePoint.Read.All). Omit when you only need the unified
    AuditLogsQuery.Read.All umbrella scope.

.PARAMETER IncludeAgent365
    Opt-in / pre-GA. Grant the two Microsoft Agent 365 application permissions
    (CopilotPackages.Read.All + Application.Read.All) so the managed identity can run
    PAX's -IncludeAgent365Info / -OnlyAgent365Info app-only (no interactive sign-in).
    Omit unless you intend to run Agent 365 enrichment on the container path. This path
    is pre-GA — validate in your tenant before relying on it in production.

.EXAMPLE
    # SharePoint mode
    ./Grant-PAXPermissions.ps1 `
        -SubscriptionId 'xxx' -ResourceGroup 'rg-pax' `
        -ManagedIdentityName 'uai-pax' -Location 'eastus' `
        -AcrResourceId '/subscriptions/.../registries/paxacr' `
        -Mode SharePoint

.EXAMPLE
    # Fabric mode, with -IncludeM365Usage workload variants
    ./Grant-PAXPermissions.ps1 `
        -SubscriptionId 'xxx' -ResourceGroup 'rg-pax' `
        -ManagedIdentityName 'uai-pax' -Location 'eastus' `
        -AcrResourceId '/subscriptions/.../registries/paxacr' `
        -Mode Fabric `
        -FabricWorkspaceResourceId '/subscriptions/.../workspaces/PAX-Workspace' `
        -IncludeM365Usage

.EXAMPLE
    # Fabric mode, opt-in app-only Microsoft Agent 365 enrichment (pre-GA)
    ./Grant-PAXPermissions.ps1 `
        -SubscriptionId 'xxx' -ResourceGroup 'rg-pax' `
        -ManagedIdentityName 'uai-pax' -Location 'eastus' `
        -AcrResourceId '/subscriptions/.../registries/paxacr' `
        -Mode Fabric `
        -FabricWorkspaceResourceId '/subscriptions/.../workspaces/PAX-Workspace' `
        -IncludeAgent365
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $SubscriptionId,
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $ManagedIdentityName,
    [Parameter(Mandatory)] [string] $Location,
    [Parameter(Mandatory)] [string] $AcrResourceId,
    [Parameter(Mandatory)] [ValidateSet('SharePoint','Fabric')] [string] $Mode,
    [Parameter()]          [string] $FabricWorkspaceResourceId,
    [Parameter()]          [switch] $IncludeM365Usage,
    [Parameter()]          [switch] $IncludeAgent365
)

$ErrorActionPreference = 'Stop'

# Helper: invoke an idempotent `az` mutation, surface non-"already exists" failures as
# Warnings, and stay silent on benign re-run skips. Preserves prior idempotent behaviour
# but no longer swallows real errors (F-SEC-1 / F-DEP-3).
function script:Invoke-AzIdempotent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]   $Label,
        [Parameter(Mandatory)][string[]] $Arguments
    )
    $captured = & az @Arguments --only-show-errors 2>&1
    $code     = $LASTEXITCODE
    if ($code -eq 0) {
        Write-Host "  $Label : granted (or already present)." -ForegroundColor Green
        return
    }
    $text = ($captured | Out-String).Trim()
    if ($text -match '(?i)already\s*exists|RoleAssignmentExists|already\s+has\s+the\s+role|already\s+assigned') {
        Write-Host "  $Label : already present (idempotent)." -ForegroundColor DarkGray
        return
    }
    Write-Warning "$Label failed (az exit $code): $text"
}

if ($Mode -eq 'Fabric' -and -not $FabricWorkspaceResourceId) {
    throw "FabricWorkspaceResourceId is required when -Mode Fabric."
}

# --- Az CLI prerequisite ---
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI ('az') is required. Install from https://aka.ms/installazurecli"
}

Write-Host "Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $SubscriptionId | Out-Null

# --- 1. Ensure user-assigned managed identity ---
Write-Host "Ensuring user-assigned managed identity '$ManagedIdentityName'..." -ForegroundColor Cyan
$mi = az identity show --name $ManagedIdentityName --resource-group $ResourceGroup --only-show-errors 2>$null | ConvertFrom-Json
if (-not $mi) {
    $mi = az identity create --name $ManagedIdentityName --resource-group $ResourceGroup --location $Location --only-show-errors | ConvertFrom-Json
    Write-Host "  Created: $($mi.id)" -ForegroundColor Green
} else {
    Write-Host "  Exists: $($mi.id)" -ForegroundColor DarkGray
}
$miPrincipalId = $mi.principalId
$miClientId    = $mi.clientId
$miResourceId  = $mi.id

# --- 1b. Bounded wait for the identity's service principal to become discoverable (F-DEP-2 resolved) ---
# Replaces a previous fixed `Start-Sleep -Seconds 10`. Polls `az ad sp show --id <clientId>`
# at 5s intervals up to 120s total, succeeds as soon as Entra ID returns the SP. On
# timeout we emit an explicit, actionable diagnostic and continue (the downstream
# Get-MgServicePrincipal call still gates the actual permission grant, so a slow tenant
# is surfaced as a clear "wait 30s and re-run" message rather than a silent hang).
$spTimeoutSeconds  = if ($env:PAX_SP_WAIT_TIMEOUT_SECONDS  -as [int]) { [int]$env:PAX_SP_WAIT_TIMEOUT_SECONDS  } else { 120 }
$spIntervalSeconds = if ($env:PAX_SP_WAIT_INTERVAL_SECONDS -as [int]) { [int]$env:PAX_SP_WAIT_INTERVAL_SECONDS } else { 5 }
$spStart = [DateTime]::UtcNow
$spReady = $false
Write-Host "Waiting for managed identity service principal to propagate (timeout ${spTimeoutSeconds}s, interval ${spIntervalSeconds}s)..." -ForegroundColor Cyan
while (([DateTime]::UtcNow - $spStart).TotalSeconds -lt $spTimeoutSeconds) {
    $probe = & az ad sp show --id $miClientId --only-show-errors 2>&1
    if ($LASTEXITCODE -eq 0 -and $probe) {
        $spReady = $true
        $elapsed = [int]([DateTime]::UtcNow - $spStart).TotalSeconds
        Write-Host "  Service principal discoverable after ${elapsed}s." -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds $spIntervalSeconds
}
if (-not $spReady) {
    Write-Warning ("Service principal for managed identity (clientId $miClientId) not discoverable within ${spTimeoutSeconds}s. " +
                   "Proceeding optimistically; the subsequent Graph lookup will surface a clear 'wait 30s and re-run' message if propagation is still incomplete.")
}

# --- 2. AcrPull on the ACR ---
Write-Host "Granting AcrPull on $AcrResourceId..." -ForegroundColor Cyan
Invoke-AzIdempotent -Label 'AcrPull' -Arguments @(
    'role','assignment','create',
    '--assignee-object-id',      $miPrincipalId,
    '--assignee-principal-type', 'ServicePrincipal',
    '--role',                    'AcrPull',
    '--scope',                   $AcrResourceId
)

# --- 3. Microsoft Graph application permissions + admin consent ---
Write-Host "Granting Microsoft Graph application permissions..." -ForegroundColor Cyan

# Ensure Microsoft.Graph PowerShell module
if (-not (Get-Module Microsoft.Graph -ListAvailable)) {
    Write-Host "  Installing Microsoft.Graph module..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Applications -ErrorAction Stop

# Connect with required scopes for granting AppRoleAssignments
Connect-MgGraph -Scopes 'AppRoleAssignment.ReadWrite.All','Application.Read.All' -NoWelcome -ErrorAction Stop | Out-Null

$graphAppId   = '00000003-0000-0000-c000-000000000000'   # Microsoft Graph
$graphSp      = Get-MgServicePrincipal -Filter "appId eq '$graphAppId'" -ErrorAction Stop
$miSp         = Get-MgServicePrincipal -Filter "appId eq '$miClientId'" -ErrorAction Stop
if (-not $miSp) { throw "Service principal for managed identity (clientId $miClientId) not found yet. Wait 30s and re-run." }

$requiredScopes = @(
    'AuditLogsQuery.Read.All',
    'User.Read.All',
    'Organization.Read.All',
    'GroupMember.Read.All'
)
if ($IncludeM365Usage) {
    $requiredScopes += @(
        'AuditLogsQuery-Exchange.Read.All',
        'AuditLogsQuery-OneDrive.Read.All',
        'AuditLogsQuery-SharePoint.Read.All'
    )
}
if ($IncludeAgent365) {
    # Opt-in / pre-GA: application permissions for app-only Microsoft Agent 365 enrichment
    # (-IncludeAgent365Info / -OnlyAgent365Info) under -Auth ManagedIdentity. No interactive
    # sign-in is performed; a missing app-role, unlicensed tenant, or absent program
    # enrollment surfaces as a runtime 403 in PAX. Validate before relying on it in production.
    Write-Host "  Agent 365 (opt-in / pre-GA): granting CopilotPackages.Read.All + Application.Read.All." -ForegroundColor Yellow
    $requiredScopes += @(
        'CopilotPackages.Read.All',
        'Application.Read.All'
    )
}
if ($Mode -eq 'SharePoint') {
    $requiredScopes += @('Sites.ReadWrite.All','Files.ReadWrite.All')
}

foreach ($scopeName in $requiredScopes) {
    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq $scopeName -and $_.AllowedMemberTypes -contains 'Application' }
    if (-not $appRole) {
        Write-Host "  WARNING: Graph AppRole '$scopeName' not found — skipping." -ForegroundColor Yellow
        continue
    }
    $existing = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $miSp.Id -ErrorAction SilentlyContinue |
                Where-Object { $_.AppRoleId -eq $appRole.Id -and $_.ResourceId -eq $graphSp.Id }
    if ($existing) {
        Write-Host "  $scopeName : already granted" -ForegroundColor DarkGray
        continue
    }
    New-MgServicePrincipalAppRoleAssignment `
        -ServicePrincipalId $miSp.Id `
        -PrincipalId        $miSp.Id `
        -ResourceId         $graphSp.Id `
        -AppRoleId          $appRole.Id `
        -ErrorAction Stop | Out-Null
    Write-Host "  $scopeName : granted" -ForegroundColor Green
}

# --- 4. Fabric/OneLake permission (Fabric mode only) ---
if ($Mode -eq 'Fabric') {
    Write-Host "Granting 'Storage Blob Data Contributor' on Fabric workspace..." -ForegroundColor Cyan
    Invoke-AzIdempotent -Label 'Storage Blob Data Contributor (Fabric workspace)' -Arguments @(
        'role','assignment','create',
        '--assignee-object-id',      $miPrincipalId,
        '--assignee-principal-type', 'ServicePrincipal',
        '--role',                    'Storage Blob Data Contributor',
        '--scope',                   $FabricWorkspaceResourceId
    )
    Write-Host ""
    Write-Host "  IMPORTANT: Also add the managed identity as a 'Contributor' member on the" -ForegroundColor Yellow
    Write-Host "  Fabric workspace via the Fabric portal (Workspace settings -> Manage access)." -ForegroundColor Yellow
    Write-Host "  Azure RBAC alone is insufficient for OneLake DFS write access in some tenants." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " ✅ Prerequisites complete." -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host " Managed identity:" -ForegroundColor White
Write-Host "   resourceId : $miResourceId" -ForegroundColor Gray
Write-Host "   clientId   : $miClientId" -ForegroundColor Gray
Write-Host "   principalId: $miPrincipalId" -ForegroundColor Gray
Write-Host ""
Write-Host " Pass these to Deploy-PAXAcaJob.ps1:" -ForegroundColor White
Write-Host "   -ManagedIdentityResourceId '$miResourceId'" -ForegroundColor Cyan
Write-Host "   -ManagedIdentityClientId   '$miClientId'" -ForegroundColor Cyan
Write-Host ""
