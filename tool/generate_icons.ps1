$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$iconPath = Join-Path $projectRoot 'lib\favicon.png'
$configPath = Join-Path $projectRoot 'flutter_launcher_icons.yaml'

if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
  throw "Icon source not found: $iconPath`nPlace a square PNG (1024x1024 recommended) at lib/favicon.png and run this script again."
}

Push-Location $projectRoot
try {
  dart run flutter_launcher_icons -f $configPath
  Write-Host 'Application icons generated for Android, iOS, Web, Windows, and macOS.'
} finally {
  Pop-Location
}
