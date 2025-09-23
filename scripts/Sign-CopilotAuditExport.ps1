param(
  [Parameter(ParameterSetName='Thumbprint', Mandatory=$true)]
  [string]$CertificateThumbprint,
  [Parameter(ParameterSetName='Pfx', Mandatory=$true)]
  [string]$PfxPath,
  [Parameter(ParameterSetName='Pfx', Mandatory=$false)]
  [securestring]$PfxPassword,
  [Parameter(Mandatory=$false)]
  [string]$ScriptPath = (Join-Path $PSScriptRoot 'CopilotAuditExport.ps1')
)

if (-not (Test-Path $ScriptPath)) {
  throw "Script not found: $ScriptPath"
}

switch ($PSCmdlet.ParameterSetName) {
  'Thumbprint' {
    $cert = Get-ChildItem -Path Cert:\CurrentUser\My\$CertificateThumbprint -ErrorAction SilentlyContinue
    if (-not $cert) { $cert = Get-ChildItem -Path Cert:\LocalMachine\My\$CertificateThumbprint -ErrorAction SilentlyContinue }
    if (-not $cert) { throw "Code signing certificate with thumbprint '$CertificateThumbprint' not found in CurrentUser or LocalMachine stores." }
  }
  'Pfx' {
    if (-not (Test-Path $PfxPath)) { throw "PFX not found: $PfxPath" }
    $cert = if ($PfxPassword) { New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PfxPath, $PfxPassword) } else { New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PfxPath) }
  }
}

Set-AuthenticodeSignature -FilePath $ScriptPath -Certificate $cert -TimestampServer 'http://timestamp.digicert.com' | Out-Null
Write-Host "Signed: $ScriptPath" -ForegroundColor Green
