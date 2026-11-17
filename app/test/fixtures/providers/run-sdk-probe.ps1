param([string]$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../..')).Path)
$ErrorActionPreference = 'Stop'
$probeRoot = Join-Path $RepoRoot '.tools/provider-probe'
$dart = Join-Path $RepoRoot '.tools/flutter/bin/dart.bat'
$env:PUB_CACHE = Join-Path $RepoRoot '.tools/pub-cache'
$env:DART_SUPPRESS_ANALYTICS = 'true'
New-Item -ItemType Directory -Force -Path $probeRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'sdk-probe.pubspec.yaml') -Destination (Join-Path $probeRoot 'pubspec.yaml') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'sdk-probe.pubspec.lock') -Destination (Join-Path $probeRoot 'pubspec.lock') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'oauth_probe.dart.txt') -Destination (Join-Path $probeRoot 'probe.dart') -Force
Push-Location $probeRoot
try {
  & $dart pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'Provider probe dependency resolution failed.' }
  & $dart run probe.dart
  if ($LASTEXITCODE -ne 0) { throw 'Provider probe failed; see sanitized scenario output.' }
} finally { Pop-Location }
