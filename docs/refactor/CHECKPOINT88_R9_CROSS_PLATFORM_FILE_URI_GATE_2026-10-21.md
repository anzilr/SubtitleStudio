# CP88 R9 — Cross-platform Source View file URIs and Flutter CI

Date: October 21, 2026  
Branch: `refactor/riverpod-architecture`  
Base: CP88 R8 `f2d31e0be3b7a94bce0140ca72e68aa3383d696b`

## Motivation

The R8 suite was run only on Ubuntu. Simulated Windows/Android cases were
useful, but they did not exercise the native Windows/macOS Dart file APIs.
Source View also rejected `file://` sources that the import/secondary readers
could already open, affecting native file-picker compatibility.

## Changes

- `SourceViewFileTarget` recognizes native `file://` sources as eligible for
  local I/O. It still rejects remote/opaque/content URIs as local fallbacks.
- `SourceViewFileAccessImpl` decodes file URIs at the I/O boundary, using an
  injected Windows-vs-POSIX choice. It keeps the persisted URI unchanged,
  honors a separate Android SAF document first and never treats `content://`
  as a native path. Non-Windows network file authorities cannot silently
  become POSIX local paths.
- `SecondarySubtitleDocumentReader` now receives an injectable Windows path
  decision rather than implicitly using the host platform in fake tests.
- Source View load-error diagnostics no longer stringify potentially
  path-bearing filesystem exceptions.
- Added real temporary-file URI read/write tests and fake-adapter Windows,
  macOS/POSIX and iOS sandbox route tests. Confirmed iOS existing `.msone`
  update policy remains Save As, regardless of URI/path shape.

## GitHub Actions scope

The quality workflow now has three distinct Flutter-only gates:

| Runner | Commands | Scope |
| --- | --- | --- |
| Ubuntu Linux | `flutter pub get`, `flutter analyze`, `flutter test -j 1` | Entire unit/widget/integration test suite plus host POSIX file I/O |
| Windows | `flutter pub get`, `flutter analyze`, targeted `flutter test -j 1` | Real host Windows file-URI/path I/O, UNC identity, Source View, subtitle imports, project updates and encoding |
| macOS | `flutter pub get`, `flutter analyze`, targeted `flutter test -j 1` | Real host macOS/POSIX file-URI I/O, file access, encoding and simulated iOS adapter rules |

**iOS qualification boundary:** `flutter test` on macOS is not running an iOS
simulator or a physical iPhone. iOS document, sandboxed picker and Save As
policy are exercised by injected platform-adapter tests; native security-scoped
URLs, Files-provider lifecycle, entitlements and dialogs still require local
iOS testing. No `flutter build`, Gradle, Xcode packaging, or other platform
build runs in GitHub Actions.

## Verification

- Local diff whitespace: `git diff --check` passed.
- Final [GitHub Actions run 39631680679](https://github.com/anzilr/SubtitleStudio/actions/runs/39631680679)
  on commit `a9184121591e76169a7aad7b8ef92a005e02ad2d`:
  - Linux: **614 passed**, analyzer **No issues found**.
  - Windows: **71 passed**, analyzer **No issues found**.
  - macOS: **71 passed**, analyzer **No issues found**.
  - All three jobs and the workflow: **success**.
- Native Android, Windows desktop app, macOS desktop app and iOS device
  acceptance: pending and intentionally distinct from Flutter CI.

This is a CP88 cross-platform code gate, not full CP88 device acceptance or
CP89 encoding closure. Native picker permission and file provider behavior
cannot be proven by mocked Dart adapters alone.
