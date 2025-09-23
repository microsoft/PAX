param(
  [string]$OutDir = (Join-Path $PSScriptRoot '..' 'out'),
  [switch]$IncludeDist
)

$ErrorActionPreference = 'Stop'

# Determine version from package.json
$pkgPath = Join-Path $PSScriptRoot '..' 'package.json'
if (-not (Test-Path $pkgPath)) { throw "package.json not found at $pkgPath" }
$pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
$version = $pkg.version
$name = if ($pkg.name) { $pkg.name } else { 'purview-audit-exporter' }

# Prepare staging dir
$stage = Join-Path $env:TEMP ("pax-src-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $stage | Out-Null

# Build file list (exclude heavy/binary folders)
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$includes = @(
  '*',
  '.vscode/*',
  'src-tauri/**',
  'src/**',
  'scripts/**',
  'index.html',
  'package.json',
  'postcss.config.js',
  'tailwind.config.js',
  'tsconfig.json',
  'vite.config.ts',
  'README.md',
  'SECURITY.md',
  'TEST.md'
)
$excludes = @(
  '.git/**',
  '.github/**',
  'node_modules/**',
  'dist/**',
  'out/**',
  'src-tauri/target/**',
  'src-tauri/target',
  'src-tauri/target*',
  'src-tauri/target/**',
  'src-tauri/target',
  'src-tauri/target*',
  'src-tauri/**/target/**',
  'src-tauri/icons/**.icns',
  'src-tauri/icons/**@2x.png',
  'src-tauri/icons/**/Square*.png',
  'src-tauri/resources/scripts/*.csv',
  'src-tauri/resources/scripts/*.tmp',
  'src-tauri/resources/scripts/*.bak'
)
if (-not $IncludeDist) {
  $excludes += 'src-tauri/target/**'
}

# Copy with filtering using robocopy where available for speed
function Copy-Filtered {
  param(
    [string]$Source,
    [string]$Destination
  )
  if (-not (Test-Path $Destination)) { New-Item -ItemType Directory -Force -Path $Destination | Out-Null }
  $robo = "$env:SystemRoot\System32\robocopy.exe"
  if (Test-Path $robo) {
    # Build exclude params
    $xd = @(); $xf = @()
    foreach ($pat in $excludes) {
      if ($pat.EndsWith('/**')) { $xd += $pat.Substring(0, $pat.Length-3) }
      elseif ($pat.Contains('*') -or $pat.Contains('?')) { $xf += $pat }
      else { $xd += $pat }
    }
    $args = @($Source, $Destination, '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
    foreach ($d in $xd) { $args += @('/XD', (Join-Path $Source $d)) }
    foreach ($f in $xf) { $args += @('/XF', (Join-Path $Source $f)) }
    & $robo @args | Out-Null
  } else {
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse -Force -Exclude $excludes
  }
}

Copy-Filtered -Source $root -Destination $stage

# Ensure optional extras are included
# None right now

# Output zip
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$zipName = "${name}_source_${version}.zip"
$zipPath = Join-Path $OutDir $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zipPath)

Write-Host "Created: $zipPath" -ForegroundColor Green

# Cleanup
Remove-Item $stage -Recurse -Force
