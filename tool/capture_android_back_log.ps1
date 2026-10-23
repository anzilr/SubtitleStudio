# Run in a SECOND PowerShell window while reproducing Android Back.
# Writes a raw, unfiltered Android log (with crash buffer) to a local file.
[CmdletBinding()]
param(
  [string]$Device = 'CPH2381',
  [string]$Output = 'cp87_android_back.log',
  [switch]$Fresh
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
  throw 'adb is not on PATH.'
}
if ($Fresh) {
  Write-Host 'Clearing Android Logcat buffers for this recording only. App data is untouched.'
  & adb -s $Device logcat -b main -b system -b crash -c
  if ($LASTEXITCODE -ne 0) { throw 'Could not clear Logcat buffers.' }
}
Write-Host "Recording Logcat on $Device to $Output (Ctrl+C to stop)."
# Direct process redirection avoids losing the process crash buffer.
& adb -s $Device logcat -b main -b system -b crash -v threadtime > $Output
