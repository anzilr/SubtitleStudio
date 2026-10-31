import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String installer;
  late String builder;

  setUpAll(() {
    installer = File('installer/SubtitleStudio.iss').readAsStringSync();
    builder = File('tool/build_windows_installer.ps1').readAsStringSync();
  });

  test('installer packaging uses a complete Windows Release bundle', () {
    expect(installer, contains(r'Source: "{#ReleaseDir}\*"'));
    expect(installer, contains('recursesubdirs createallsubdirs'));
    expect(installer, contains(r'Filename: "{app}\{#StudioExe}"'));
    expect(installer, contains('AppVersion={#AppVersion}'));
    expect(installer, contains('VersionInfoVersion={#AppVersion}.{#BuildNumber}'));
    expect(builder, contains('flutter build windows --release'));
    expect(builder, contains('data\\flutter_assets\\AssetManifest.bin'));
    expect(builder, contains('vcruntime140_1.dll'));
    expect(builder, contains('Get-FileHash'));
  });

  test('missing app-local VC runtime is found in installed Visual Studio', () {
    expect(builder, contains(r'$env:VCToolsRedistDir'));
    expect(builder, contains("'Microsoft Visual Studio'"));
    expect(builder, contains(r"'VC\Redist\MSVC'"));
    expect(builder, contains(r"'Microsoft.VC*.CRT'"));
    expect(builder, contains(r'$missingVcRuntimeFiles.Count -gt 0'));
    expect(builder, contains(r'$VcRuntimeSourceDirectory = $crtFolder.FullName'));
    expect(builder, contains('No complete x64 Microsoft VC runtime found'));
    expect(builder, contains('VC runtime source is incomplete'));
    expect(builder, contains(r'Assert-WindowsX64Binary -FilePath $source'));
    expect(builder, contains(r'Copy-Item -LiteralPath (Join-Path $VcRuntimeSourceDirectory $runtime)'));
    expect(builder, isNot(contains(r"'C:\Windows\System32'")));
  });

  test('Windows release includes an offline FFmpeg and FFprobe bundle', () {
    expect(builder, contains('FfmpegBundleDirectory'));
    expect(builder, contains(r"'bin\ffmpeg.exe'"));
    expect(builder, contains(r"'bin\ffprobe.exe'"));
    expect(builder, contains("'LICENSE.txt'"));
    expect(builder, contains("'SOURCE.txt'"));
    expect(builder, contains(r"'tools\ffmpeg'"));
    expect(builder, contains(r'Copy-Item -LiteralPath $source'));
    expect(builder, isNot(contains('winget install')));
  });

  test('installer wizard image is a standard BMP built from the Windows icon',
      () {
    expect(installer, contains('WizardSmallImageFile={#WizardSmallBitmap}'));
    expect(installer, isNot(contains(
      r'WizardSmallImageFile=..\assets\subtitle_studio_brand_icon.png',
    )));
    expect(builder, contains(r"'windows\runner\resources\app_icon.ico'"));
    expect(builder, contains('Format24bppRgb'));
    expect(builder, contains('ImageFormat]::Bmp'));
    expect(builder, contains(r'/DWizardSmallBitmap=$wizardBitmapPath'));
    expect(builder, contains('Could not create a valid installer wizard BMP'));

    final icon = File('windows/runner/resources/app_icon.ico');
    expect(icon.existsSync(), isTrue);
    final bytes = icon.openSync();
    try {
      expect(bytes.readSync(4), [0, 0, 1, 0]);
    } finally {
      bytes.closeSync();
    }
  });

  test('installer rejects mismatched Windows architectures before packaging',
      () {
    expect(builder, contains('function Assert-WindowsX64Binary'));
    expect(builder, contains('0x5A4D')); // DOS MZ header
    expect(builder, contains('0x00004550')); // PE signature
    expect(builder, contains('0x8664')); // AMD64 machine
    expect(builder, contains(r'Assert-WindowsX64Binary -FilePath $target'));
    expect(builder, contains(
      r'Assert-WindowsX64Binary -FilePath (Join-Path $FfmpegBundleDirectory',
    ));
    expect(builder, contains(
      r'Assert-WindowsX64Binary -FilePath (Join-Path $releaseDir',
    ));
    // Reading PE headers must never launch downloaded binaries.
    expect(builder, isNot(contains(r'& $source -version')));
  });

  test('supplied Gyan.dev essentials bundle is staged without extra tools', () {
    expect(builder, contains("-Filter 'ffmpeg-*-essentials_build'"));
    expect(builder, contains(r"Join-Path $FfmpegBundleDirectory 'LICENSE'"));
    expect(builder, contains(r"Join-Path $FfmpegBundleDirectory 'README.txt'"));
    expect(builder, contains(r'$ffmpegSourceFiles[$relative] = $source'));
    expect(builder, contains(r'$source = $ffmpegSourceFiles[$relative]'));
    expect(builder, contains('Unrecognized FFmpeg build manifest'));
    expect(builder, contains('third-party licensing'));
    expect(builder, isNot(contains("'bin\\ffplay.exe'")));
    expect(File('.gitignore').readAsStringSync(),
        contains('/installer/ffmpeg-*-essentials_build/'));
  });

  test('local FFmpeg tools have Windows AMD64 headers when provided', () async {
    final bundles = Directory('installer').listSync(followLinks: false)
        .whereType<Directory>()
        .where((folder) {
          final name = folder.path.split(Platform.pathSeparator).last;
          return name.startsWith('ffmpeg-') &&
              name.endsWith('-essentials_build');
        }).toList();
    if (bundles.isEmpty) return; // CI has no downloaded vendor assets.
    expect(bundles, hasLength(1));
    final bundle = bundles.single;
    for (final name in ['ffmpeg.exe', 'ffprobe.exe']) {
      final file = File('${bundle.path}${Platform.pathSeparator}bin'
          '${Platform.pathSeparator}$name');
      expect(file.existsSync(), isTrue, reason: name);
      final input = await file.open();
      try {
        final length = await input.length();
        expect(length, greaterThan(70), reason: name);
        await input.setPosition(0);
        expect(await input.read(2), [0x4d, 0x5a], reason: name);
        await input.setPosition(0x3c);
        final bytes = await input.read(4);
        expect(bytes.length, 4, reason: name);
        final offset = bytes[0] | (bytes[1] << 8) |
            (bytes[2] << 16) | (bytes[3] << 24);
        expect(offset, inInclusiveRange(64, length - 6), reason: name);
        await input.setPosition(offset);
        expect(await input.read(6), [0x50, 0x45, 0, 0, 0x64, 0x86],
            reason: name);
      } finally {
        await input.close();
      }
    }
  });

  test('installer offers safe per-user and optional all-users mode', () {
    expect(installer, contains('PrivilegesRequired=lowest'));
    expect(installer, contains('PrivilegesRequiredOverridesAllowed=dialog'));
    expect(installer, contains('MinVersion=10.0.17763'));
    expect(installer, contains('ArchitecturesAllowed=x64compatible'));
    expect(installer, contains('ChangesAssociations=yes'));
    expect(installer, contains('CloseApplications=yes'));
    expect(installer, contains('SignedUninstaller=yes'));
  });

  test('file integration registers only supported Open with choices', () {
    final registry = installer.split('[Registry]').last.split('[Run]').first
        .split('\n').where((line) => line.trimLeft().startsWith('Root:'))
        .join('\n');
    expect(registry, contains(r'Software\Classes\.srt\OpenWithProgids'));
    expect(registry, contains(r'Software\Classes\.msone\OpenWithProgids'));
    expect(registry, isNot(contains(r'Software\Classes\.vtt')));
    expect(registry, isNot(contains(r'Software\Classes\.ass')));
    expect(registry, isNot(contains('HKCR')));
    expect(registry, isNot(contains('UserChoice')));
    expect(registry, isNot(contains('RegDeleteKeyIncludingSubkeys')));
    expect(installer, isNot(contains('Filename: "cmd.exe"')));
    expect(installer, isNot(contains('dxwebsetup.exe')));
  });

  test('installer does not remove user files on uninstall', () {
    expect(installer, isNot(contains('[UninstallDelete]')));
    expect(installer, contains('uninsdeletevalue'));
    expect(installer, contains('uninsdeletekey'));
    expect(installer, contains('LicenseFile=..\\LICENSE.txt'));
    expect(builder, contains('SigningCertificateThumbprint'));
  });
}
