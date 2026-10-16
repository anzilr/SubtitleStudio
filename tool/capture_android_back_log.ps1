# Run in a SECOND PowerShell window while reproducing Android Back.
# Writes a raw, unfiltered Android log (with crash buffer) to a local file.
[CmdletBinding()]
param(
  [string]$Device = 'CPH2381',
  [string]$Output = 'cp87_android_back.log'
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
  throw 'adb is not on PATH.'
}
Write-Host "Recording Logcat on $Device to $Output (Ctrl+C to stop)."
# Direct process redirection avoids losing the process crash buffer.
& adb -s $Device logcat -b main -b system -b crash -v threadtime > $Output
