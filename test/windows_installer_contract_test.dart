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
