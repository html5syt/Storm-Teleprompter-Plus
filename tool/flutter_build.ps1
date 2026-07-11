param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('windows', 'apk', 'appbundle')]
  [string]$Target,

  [Parameter(Mandatory = $true)]
  [ValidateSet('debug', 'release')]
  [string]$Mode,

  [string]$Version = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = (git rev-parse --short=8 HEAD).Trim()
}

$flutterArgs = @(
  'build',
  $Target,
  "--$Mode",
  "--dart-define=APP_VERSION=$Version"
)

if ($Mode -eq 'release' -and $Version -match '^v?(\d+\.\d+\.\d+)$') {
  $flutterArgs += "--build-name=$($Matches[1])"
}

if ($Target -eq 'apk') {
  $flutterArgs += '--split-per-abi'
}

& flutter @flutterArgs
exit $LASTEXITCODE
