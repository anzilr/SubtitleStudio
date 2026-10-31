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
  [switch]$CleanFlutterBuild,
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

if ($SkipFlutterBuild -and $CleanFlutterBuild) {
  throw '-SkipFlutterBuild and -CleanFlutterBuild cannot be used together.'
}

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

# Inspect PE headers without executing downloaded tool binaries. Reject wrong-
# architecture media and runtime files before they enter a Windows x64 setup.
function Assert-WindowsX64Binary {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
  )
  $stream = [IO.File]::OpenRead($FilePath)
  try {
    $reader = [IO.BinaryReader]::new($stream)
    if ($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5A4D) {
      throw "Not a Windows PE executable: $FilePath"
    }
    [void]$stream.Seek(0x3C, [IO.SeekOrigin]::Begin)
    $peOffset = $reader.ReadInt32()
    if ($peOffset -lt 64 -or $peOffset -gt ($stream.Length - 6)) {
      throw "Invalid Windows PE header: $FilePath"
    }
    [void]$stream.Seek($peOffset, [IO.SeekOrigin]::Begin)
    if ($reader.ReadUInt32() -ne 0x00004550 -or
        $reader.ReadUInt16() -ne 0x8664) {
      throw "Expected a Windows x64 (AMD64) executable: $FilePath"
    }
  } finally {
    $stream.Dispose()
  }
}

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
# Prefer a curated bundle, but accept a single untouched Gyan.dev essentials
# folder placed directly under installer/. Never alter the user's source files.
if ([string]::IsNullOrWhiteSpace($FfmpegBundleDirectory)) {
  $FfmpegBundleDirectory = Join-Path $repoRoot 'installer\deps\ffmpeg'
  if (-not (Test-Path -LiteralPath $FfmpegBundleDirectory -PathType Container)) {
    $localBundles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'installer') -Directory -Filter 'ffmpeg-*-essentials_build')
    if ($localBundles.Count -eq 1) {
      $FfmpegBundleDirectory = $localBundles[0].FullName
      Write-Host "Using local FFmpeg bundle: $FfmpegBundleDirectory"
    } elseif ($localBundles.Count -gt 1) {
      throw 'Multiple FFmpeg essentials bundles found. Choose one with -FfmpegBundleDirectory.'
    }
  }
}
$preparedLicense = Join-Path $FfmpegBundleDirectory 'LICENSE.txt'
$preparedSource = Join-Path $FfmpegBundleDirectory 'SOURCE.txt'
$vendorLicense = Join-Path $FfmpegBundleDirectory 'LICENSE'
$vendorSource = Join-Path $FfmpegBundleDirectory 'README.txt'
if ((Test-Path -LiteralPath $preparedLicense -PathType Leaf) -and
    (Test-Path -LiteralPath $preparedSource -PathType Leaf)) {
  $licenseNotice = $preparedLicense
  $sourceNotice = $preparedSource
} elseif ((Test-Path -LiteralPath $vendorLicense -PathType Leaf) -and
          (Test-Path -LiteralPath $vendorSource -PathType Leaf)) {
  $manifest = Get-Content -LiteralPath $vendorSource -Raw
  if ($manifest -notmatch '(?m)^FFmpeg 64-bit static Windows build from www\.gyan\.dev' -or
      $manifest -notmatch '(?m)^Version:\s+\S+' -or
      $manifest -notmatch '(?m)^Source Code:\s+https://\S+') {
    throw "Unrecognized FFmpeg build manifest: $vendorSource"
  }
  $licenseNotice = $vendorLicense
  $sourceNotice = $vendorSource
  Write-Warning 'Packaging upstream GPL license and build manifest as local notices. Verify corresponding source and third-party licensing before any public distribution.'
} else {
  throw "FFmpeg notices missing in $FfmpegBundleDirectory. Supply LICENSE.txt and SOURCE.txt, or an untouched Gyan.dev LICENSE and README.txt pair."
}

$ffmpegFiles = @(
  'bin\ffmpeg.exe',
  'bin\ffprobe.exe',
  'LICENSE.txt',
  'SOURCE.txt'
)
$ffmpegSourceFiles = @{}
foreach ($relative in $ffmpegFiles) {
  if ($relative -eq 'LICENSE.txt') {
    $source = $licenseNotice
  } elseif ($relative -eq 'SOURCE.txt') {
    $source = $sourceNotice
  } else {
    $source = Join-Path $FfmpegBundleDirectory $relative
  }
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "FFmpeg bundle is incomplete: $source. Supply ffmpeg.exe, ffprobe.exe and matching licensing/source notices."
  }
  if ((Get-Item -LiteralPath $source).Length -eq 0) {
    throw "FFmpeg bundle contains an empty file: $source"
  }
  $ffmpegSourceFiles[$relative] = $source
}
foreach ($relative in @('bin\ffmpeg.exe', 'bin\ffprobe.exe')) {
  Assert-WindowsX64Binary -FilePath (Join-Path $FfmpegBundleDirectory $relative)
}

if (-not $SkipFlutterBuild) {
  if ($null -eq (Get-Command 'flutter' -ErrorAction SilentlyContinue)) {
    throw 'flutter was not found on PATH. Install the Flutter Windows toolchain.'
  }
  Push-Location $repoRoot
  try {
    if ($CleanFlutterBuild) {
      Write-Host 'Cleaning stale Flutter build artifacts before the Windows Release build...'
      & flutter clean
      if ($LASTEXITCODE -ne 0) {
        throw "Flutter clean failed with exit code $LASTEXITCODE."
      }
      & flutter pub get
      if ($LASTEXITCODE -ne 0) {
        throw "Flutter pub get failed with exit code $LASTEXITCODE."
      }
    }
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

# The app and Flutter engine must also match the installer architecture.
foreach ($relative in @('SubtitleStudio.exe', 'flutter_windows.dll')) {
  Assert-WindowsX64Binary -FilePath (Join-Path $releaseDir $relative)
}

# Use application-local C++ runtime deployment to avoid running a global
# redistributable installer as admin from a per-user installation. The DLLs
# must originate from a properly licensed Microsoft Visual Studio toolchain.
$vcRuntimeFiles = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
$missingVcRuntimeFiles = @($vcRuntimeFiles | Where-Object {
  -not (Test-Path -LiteralPath (Join-Path $releaseDir $_) -PathType Leaf)
})
if ($missingVcRuntimeFiles.Count -gt 0) {
  if ([string]::IsNullOrWhiteSpace($VcRuntimeSourceDirectory)) {
    # The developer prompt exposes this when using Visual Studio build tools.
    # Otherwise search standard Visual Studio installation locations, including
    # Community, Professional, Enterprise, and Build Tools installations.
    $vcRedistRoots = @()
    if (-not [string]::IsNullOrWhiteSpace($env:VCToolsRedistDir)) {
      $vcRedistRoots += $env:VCToolsRedistDir
    }
    foreach ($programFilesRoot in @(
      [Environment]::GetFolderPath('ProgramFiles'),
      [Environment]::GetFolderPath('ProgramFilesX86')
    ) | Select-Object -Unique) {
      if ([string]::IsNullOrWhiteSpace($programFilesRoot)) {
        continue
      }
      $vsRoot = Join-Path $programFilesRoot 'Microsoft Visual Studio'
      if (-not (Test-Path -LiteralPath $vsRoot -PathType Container)) {
        continue
      }
      foreach ($vsYear in Get-ChildItem -LiteralPath $vsRoot -Directory) {
        foreach ($vsEdition in Get-ChildItem -LiteralPath $vsYear.FullName -Directory) {
          $redistRoot = Join-Path $vsEdition.FullName 'VC\Redist\MSVC'
          if (Test-Path -LiteralPath $redistRoot -PathType Container) {
            foreach ($vcVersion in Get-ChildItem -LiteralPath $redistRoot -Directory) {
              $vcRedistRoots += $vcVersion.FullName
            }
          }
        }
      }
    }

    foreach ($redistRoot in @($vcRedistRoots | Sort-Object -Unique -Descending)) {
      $x64Root = Join-Path $redistRoot 'x64'
      if (-not (Test-Path -LiteralPath $x64Root -PathType Container)) {
        continue
      }
      foreach ($crtFolder in (Get-ChildItem -LiteralPath $x64Root -Directory -Filter 'Microsoft.VC*.CRT' |
          Sort-Object -Property Name -Descending)) {
        $complete = $true
        foreach ($runtime in $vcRuntimeFiles) {
          if (-not (Test-Path -LiteralPath (Join-Path $crtFolder.FullName $runtime) -PathType Leaf)) {
            $complete = $false
            break
          }
        }
        if ($complete) {
          $VcRuntimeSourceDirectory = $crtFolder.FullName
          Write-Host "Using Visual Studio x64 VC runtime: $VcRuntimeSourceDirectory"
          break
        }
      }
      if (-not [string]::IsNullOrWhiteSpace($VcRuntimeSourceDirectory)) {
        break
      }
    }
  }

  if ([string]::IsNullOrWhiteSpace($VcRuntimeSourceDirectory)) {
    throw "Missing application-local VC runtime DLLs: $($missingVcRuntimeFiles -join ', '). No complete x64 Microsoft VC runtime found under Visual Studio. Install the MSVC C++ redistributable components in Visual Studio Installer, or pass -VcRuntimeSourceDirectory pointing to x64\Microsoft.VC143.CRT."
  }

  # Check the entire source set before copying anything. A partial Release
  # bundle must not mix DLL versions from different Visual Studio toolchains.
  foreach ($runtime in $vcRuntimeFiles) {
    $source = Join-Path $VcRuntimeSourceDirectory $runtime
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
      throw "VC runtime source is incomplete: $source. Pass a directory containing all three x64 runtime DLLs."
    }
    Assert-WindowsX64Binary -FilePath $source
  }
  foreach ($runtime in $vcRuntimeFiles) {
    Copy-Item -LiteralPath (Join-Path $VcRuntimeSourceDirectory $runtime) -Destination (Join-Path $releaseDir $runtime) -Force
  }
}
foreach ($runtime in $vcRuntimeFiles) {
  $target = Join-Path $releaseDir $runtime
  Assert-WindowsX64Binary -FilePath $target
}

# The Windows app resolves these two executables next to itself, so the user
# never needs to install FFmpeg, edit PATH, or enable package-manager access.
$ffmpegDestination = Join-Path $releaseDir 'tools\ffmpeg'
foreach ($relative in $ffmpegFiles) {
  $source = $ffmpegSourceFiles[$relative]
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
