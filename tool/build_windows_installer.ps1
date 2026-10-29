<#
.SYNOPSIS
  Builds and packages the Subtitle Studio Windows x64 installer locally.
.DESCRIPTION
  Requires Flutter Windows tooling and Inno Setup 6.5.2 or newer.
  Packages offline FFmpeg/FFprobe binaries from installer/deps/ffmpeg.
  Never downloads or executes third-party installers. Flutter platform builds
  must run on a local Windows machine, not in GitHub Actions.
.EXAMPLE
  .\tool\build_windows_installer.ps1
.EXAMPLE
  .\tool\build_windows_installer.ps1 -SkipFlutterBuild -ReplaceExistingInstaller
.EXAMPLE
  .\tool\build_windows_installer.ps1 -SigningCertificateThumbprint YOUR_CERT_THUMBPRINT
#>
[CmdletBinding()]
param(
  [switch]$SkipFlutterBuild,
  [switch]$ReplaceExistingInstaller,
  [string]$InnoCompilerPath,
  [string]$VcRuntimeSourceDirectory,
  [string]$FfmpegBundleDirectory,
  [ValidatePattern('^[A-Fa-f0-9]{40}$')]
  [string]$SigningCertificateThumbprint,
  [string]$TimestampServer = 'http://timestamp.digicert.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
  throw 'The Windows installer must be built on a Windows computer.'
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$versionLine = Get-Content -LiteralPath $pubspecPath |
  Where-Object { $_ -match '^version:\s*\d+\.\d+\.\d+\+\d+\s*$' } |
  Select-Object -First 1
if (-not $versionLine -or
    $versionLine -notmatch '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') {
  throw 'pubspec.yaml must contain a version such as 3.0.0+30.'
}
$appVersion = $Matches[1]
$buildNumber = $Matches[2]
if ([int]$buildNumber -gt 65535) {
  throw 'The Windows installer file version build number cannot exceed 65535.'
}

$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$outputDir = Join-Path $repoRoot 'installer\output'
$installerName = "SubtitleStudio_${appVersion}_${buildNumber}_Windows_x64_Setup.exe"
$installerPath = Join-Path $outputDir $installerName
$scriptPath = Join-Path $repoRoot 'installer\SubtitleStudio.iss'

if ([string]::IsNullOrWhiteSpace($InnoCompilerPath)) {
  $knownCompiler = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
  if ($null -ne $knownCompiler) {
    $InnoCompilerPath = $knownCompiler.Source
  } else {
    $innoBase = [Environment]::GetFolderPath('ProgramFilesX86')
    foreach ($candidate in @(
      (Join-Path $innoBase 'Inno Setup 7\ISCC.exe'),
      (Join-Path $innoBase 'Inno Setup 6\ISCC.exe')
    )) {
      if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $InnoCompilerPath = $candidate
        break
      }
    }
  }
}
if ([string]::IsNullOrWhiteSpace($InnoCompilerPath) -or
    -not (Test-Path -LiteralPath $InnoCompilerPath -PathType Leaf)) {
  throw 'ISCC.exe was not found. Install Inno Setup 6.5.2+ or pass -InnoCompilerPath.'
}

if (Test-Path -LiteralPath $installerPath -PathType Leaf) {
  if (-not $ReplaceExistingInstaller) {
    throw "Installer already exists: $installerPath. Use -ReplaceExistingInstaller to rebuild it."
  }
}

# Validate offline media inputs before spending time on the Flutter build.
if ([string]::IsNullOrWhiteSpace($FfmpegBundleDirectory)) {
  $FfmpegBundleDirectory = Join-Path $repoRoot 'installer\deps\ffmpeg'
}
$ffmpegFiles = @(
  'bin\ffmpeg.exe',
  'bin\ffprobe.exe',
  'LICENSE.txt',
  'SOURCE.txt'
)
foreach ($relative in $ffmpegFiles) {
  $source = Join-Path $FfmpegBundleDirectory $relative
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "FFmpeg bundle is incomplete: $source. Supply a complete -FfmpegBundleDirectory containing ffmpeg.exe, ffprobe.exe, LICENSE.txt, and SOURCE.txt."
  }
  if ((Get-Item -LiteralPath $source).Length -eq 0) {
    throw "FFmpeg bundle contains an empty file: $source"
  }
}

if (-not $SkipFlutterBuild) {
  if ($null -eq (Get-Command 'flutter' -ErrorAction SilentlyContinue)) {
    throw 'flutter was not found on PATH. Install the Flutter Windows toolchain.'
  }
  Push-Location $repoRoot
  try {
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter Windows Release build failed with exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }
}

# An Inno installer must include the entire Flutter desktop bundle, not only
# SubtitleStudio.exe. Fail explicitly if an incomplete build is supplied.
$requiredReleaseFiles = @(
  'SubtitleStudio.exe',
  'flutter_windows.dll',
  'data\icudtl.dat',
  'data\app.so',
  'data\flutter_assets\AssetManifest.bin'
)
foreach ($relative in $requiredReleaseFiles) {
  $requiredPath = Join-Path $releaseDir $relative
  if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
    throw "Release bundle is incomplete. Missing: $requiredPath"
  }
}

# Use application-local C++ runtime deployment to avoid running a global
# redistributable installer as admin from a per-user installation. The DLLs
# must originate from a properly licensed Microsoft Visual Studio toolchain.
$vcRuntimeFiles = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
foreach ($runtime in $vcRuntimeFiles) {
  $target = Join-Path $releaseDir $runtime
  if (-not (Test-Path -LiteralPath $target -PathType Leaf) -and
      -not [string]::IsNullOrWhiteSpace($VcRuntimeSourceDirectory)) {
    $source = Join-Path $VcRuntimeSourceDirectory $runtime
    if (Test-Path -LiteralPath $source -PathType Leaf) {
      Copy-Item -LiteralPath $source -Destination $target
    }
  }
  if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw "Missing application-local $runtime. Provide -VcRuntimeSourceDirectory with the x64 Microsoft VC runtime DLLs from your licensed toolchain."
  }
}

# The Windows app resolves these two executables next to itself, so the user
# never needs to install FFmpeg, edit PATH, or enable package-manager access.
$ffmpegDestination = Join-Path $releaseDir 'tools\ffmpeg'
foreach ($relative in $ffmpegFiles) {
  $source = Join-Path $FfmpegBundleDirectory $relative
  $destination = Join-Path $ffmpegDestination $relative
  [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination))
  Copy-Item -LiteralPath $source -Destination $destination -Force
  Write-Host "FFmpeg bundle: $relative SHA-256 $((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash)"
}

$compilerArguments = @(
  "/DAppVersion=$appVersion",
  "/DBuildNumber=$buildNumber",
  "/DReleaseDir=$releaseDir",
  "/DInstallerOutputDir=$outputDir"
)

if (-not [string]::IsNullOrWhiteSpace($SigningCertificateThumbprint)) {
  $signTool = Get-Command 'signtool.exe' -ErrorAction SilentlyContinue
  if ($null -eq $signTool) {
    throw 'signtool.exe was not found on PATH; install the Windows SDK signing tools.'
  }
  $exeToSign = Join-Path $releaseDir 'SubtitleStudio.exe'
  & $signTool.Source sign /sha1 $SigningCertificateThumbprint /fd SHA256 `
      /tr $TimestampServer /td SHA256 /d 'Subtitle Studio' $exeToSign
  if ($LASTEXITCODE -ne 0) {
    throw "Signing the application failed (exit code $LASTEXITCODE)."
  }
  $installerSignTool = '"' + $signTool.Source + '" sign /sha1 ' +
      $SigningCertificateThumbprint + ' /fd SHA256 /tr ' + $TimestampServer +
      ' /td SHA256 /d "Subtitle Studio" $f'
  $compilerArguments += "/DSigningEnabled=1"
  $compilerArguments += "--signtool=studio=$installerSignTool"
}

[void](New-Item -ItemType Directory -Force -Path $outputDir)
$compilerArguments += $scriptPath
& $InnoCompilerPath @compilerArguments
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup compilation failed (exit code $LASTEXITCODE)."
}
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
  throw "Inno Setup did not produce the expected installer: $installerPath"
}

$digest = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
$checksumPath = "$installerPath.sha256"
Set-Content -LiteralPath $checksumPath -Encoding ASCII -Value "$digest  $installerName"
Write-Host "Installer: $installerPath"
Write-Host "SHA-256:   $digest"
Write-Host "Checksum: $checksumPath"
if ([string]::IsNullOrWhiteSpace($SigningCertificateThumbprint)) {
  Write-Warning 'This installer is unsigned. Sign it before distributing publicly.'
}
