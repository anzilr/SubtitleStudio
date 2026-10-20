import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android clean-debug launcher remains parseable and accepts Dart defines',
      () async {
    final file = File('tool/run_android_clean_debug.ps1');
    expect(file.existsSync(), isTrue);
    final contents = await file.readAsString();

    expect(contents, contains(r'[string[]]$DartDefines = @()'));
    expect(contents, contains(r'foreach ($definition in $DartDefines)'));
    expect(contents, contains(r'$flutterArgs += "--dart-define=$definition"'));
    expect(contents, contains(r"'^[A-Za-z][A-Za-z0-9_]*=.+$'"));
    expect(contents, contains("'--dart-define=MS_ONE_WAVEFORM_TRACK_SYNC=true'"));
    expect(contents, contains('am force-stop'));
    expect(contents, isNot(contains('pm clear')));
    expect(contents, isNot(contains('adb uninstall')));

    // The initial R9 launcher had an unterminated expression and duplicate
    // fragments; syntax-check the entire script where PowerShell is installed.
    final executable = Platform.isWindows ? 'powershell.exe' : 'pwsh';
    const parser = r'''
$tokens = $null
$parseErrors = $null
$path = (Resolve-Path 'tool/run_android_clean_debug.ps1').Path
[System.Management.Automation.Language.Parser]::ParseFile(
  $path, [ref]$tokens, [ref]$parseErrors
) | Out-Null
if ($parseErrors.Count -gt 0) {
  foreach ($e in $parseErrors) { Write-Output $e.Message }
  exit 1
}
exit 0
''';
    try {
      final result = await Process.run(executable, [
        '-NoLogo', '-NoProfile', '-NonInteractive',
        '-Command', parser,
      ], workingDirectory: Directory.current.path);
      expect(result.exitCode, 0,
          reason: 'PowerShell syntax errors:\n${result.stdout}\n${result.stderr}');
    } on ProcessException {
      // Not all Flutter development hosts have PowerShell installed.
    }
  });
}
