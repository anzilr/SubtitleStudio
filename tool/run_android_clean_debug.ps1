# Clean app-process launch for Android native crash/waveform qualification.
# Do NOT invoke Flutter hot restart (R) with an active media_kit/libmpv Player.
# Exit any old flutter run session (q) before using this script.
# This script NEVER clears app data, uninstalls, or touches Isar files.
[CmdletBinding()]
param(
  [string]$Device = 'CPH2381',
  [ValidateSet('debug', 'profile')]
  [string]$Mode = 'debug',
  # Additional --dart-define values for opt-in experimental testing.
  [string[]]$DartDefines = @()
)

$ErrorActionPreference = 'Stop'
$packageName = 'org.malayalamsubtitles.studio'
$repoRoot = Split-Path -Parent $PSScriptRoot

foreach ($commandName in @('adb', 'flutter')) {
  if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
    throw "Required tool '$commandName' is not on PATH."
  }
}

$deviceState = & adb -s $Device get-state 2>&1
if ($LASTEXITCODE -ne 0 -or "$deviceState".Trim() -ne 'device') {
  throw "ADB device '$Device' is unavailable. Connect/unlock the device first."
}

Write-Host 'IMPORTANT: Quit an existing flutter run session with q first.'
Write-Host 'Launching from a fresh Android process (not a Dart hot restart).'
Write-Host "Stopping $packageName without removing its data or preferences..."
& adb -s $Device shell am force-stop $packageName
if ($LASTEXITCODE -ne 0) {
  throw 'ADB force-stop failed.'
}

Push-Location $repoRoot
try {
  $flutterArgs = @(
    'run', "--$Mode", '-d', $Device,
    '--dart-define=MS_ONE_WAVEFORM_TRACK_SYNC=true'
  )

  foreach ($definition in $DartDefines) {
    if ([string]::IsNullOrWhiteSpace($definition) -or
        $definition -notmatch '^[A-Za-z][A-Za-z0-9_]*=.+$') {
      throw "Invalid dart-define '$definition'. Expected NAME=value."
    }
    $flutterArgs += "--dart-define=$definition"
  }

  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) {
    throw "flutter run exited with code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
