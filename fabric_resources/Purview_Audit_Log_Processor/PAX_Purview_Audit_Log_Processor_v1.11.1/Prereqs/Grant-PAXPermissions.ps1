<#
.SYNOPSIS
    Provision and grant ALL prerequisite permissions for an unattended PAX run on
    Azure Container Apps Jobs writing to SharePoint or Fabric/OneLake.

.DESCRIPTION
    One-time bootstrap script. Performs (idempotently):

      1. Creates (or reuses) a user-assigned managed identity.
      2. Grants AcrPull on the specified Azure Container Registry to the identity.
      3. Grants Microsoft Graph application permissions (AuditLog.Read.All, User.Read.All,
         Organization.Read.All, Application.Read.All; + optional SharePoint scopes
         Sites.ReadWrite.All, Files.ReadWrite.All) and ADMIN-CONSENTS them on the
         identity's service principal.
      4. (SharePoint mode) Verifies SharePoint scopes are present.
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

.EXAMPLE
    # SharePoint mode
    ./Grant-PAXPermissions.ps1 `
        -SubscriptionId 'xxx' -ResourceGroup 'rg-pax' `
        -ManagedIdentityName 'uai-pax' -Location 'eastus' `
        -AcrResourceId '/subscriptions/.../registries/paxacr' `
        -Mode SharePoint

.EXAMPLE
    # Fabric mode
    ./Grant-PAXPermissions.ps1 `
        -SubscriptionId 'xxx' -ResourceGroup 'rg-pax' `
        -ManagedIdentityName 'uai-pax' -Location 'eastus' `
        -AcrResourceId '/subscriptions/.../registries/paxacr' `
        -Mode Fabric `
        -FabricWorkspaceResourceId '/subscriptions/.../workspaces/PAX-Workspace'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $SubscriptionId,
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $ManagedIdentityName,
    [Parameter(Mandatory)] [string] $Location,
    [Parameter(Mandatory)] [string] $AcrResourceId,
    [Parameter(Mandatory)] [ValidateSet('SharePoint','Fabric')] [string] $Mode,
    [Parameter()]          [string] $FabricWorkspaceResourceId
)

$ErrorActionPreference = 'Stop'

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

# Eventual-consistency wait for the identity's service principal to be discoverable.
Start-Sleep -Seconds 10

# --- 2. AcrPull on the ACR ---
Write-Host "Granting AcrPull on $AcrResourceId..." -ForegroundColor Cyan
az role assignment create `
    --assignee-object-id   $miPrincipalId `
    --assignee-principal-type ServicePrincipal `
    --role 'AcrPull' `
    --scope $AcrResourceId `
    --only-show-errors 2>$null | Out-Null
Write-Host "  AcrPull granted (or already present)." -ForegroundColor Green

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
    'AuditLog.Read.All',
    'User.Read.All',
    'Organization.Read.All',
    'Application.Read.All'
)
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
    az role assignment create `
        --assignee-object-id   $miPrincipalId `
        --assignee-principal-type ServicePrincipal `
        --role 'Storage Blob Data Contributor' `
        --scope $FabricWorkspaceResourceId `
        --only-show-errors 2>$null | Out-Null
    Write-Host "  Granted (or already present)." -ForegroundColor Green
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
