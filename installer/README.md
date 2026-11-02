# Subtitle Studio — Windows installer

The old `MSoneSubEditor_Standalone.iss` archive is a prototype. This folder
contains its replacement: a native **Inno Setup** installer for Subtitle
Studio's Windows x64 Flutter Release build.

## Build locally on Windows

Requirements:

1. Flutter with the Windows desktop toolchain, Visual Studio C++ components,
   and a successful `flutter doctor -v`.
2. [Inno Setup](https://jrsoftware.org/isinfo.php) **6.5.2 or later**.
3. Redistributable **x64 Microsoft Visual C++ runtime DLLs** from a properly
   licensed Visual Studio toolchain. The Flutter Release folder may already
   contain them. The script refuses to package an incomplete runtime.
4. The `ffmpeg_kit_flutter_new_min_gpl` dependency resolved through
   `flutter pub get`. Its Windows plugin supplies native FFmpeg and FFprobe
   libraries during the Flutter build.

### FFmpegKit native libraries (no separate download)

Subtitle Studio now invokes FFmpeg and FFprobe through
[`ffmpeg_kit_flutter_new_min_gpl`](https://pub.dev/packages/ffmpeg_kit_flutter_new_min_gpl)
on Android, iOS, macOS, Windows and Linux. The plugin installs the matching
Windows x64 native libraries into the Flutter Release bundle. There is no need
to download a standalone `ffmpeg.exe` / `ffprobe.exe`, modify PATH, or
run a separate FFmpeg installer.

The Windows build also installs its required redistribution notices at
`build/windows/x64/runner/Release/licenses/ffmpeg_kit_flutter_new_min_gpl/NOTICE.txt`.
The packaging script checks that file and Inno Setup includes the complete
Release folder (native DLLs, plugin notices and Flutter assets).

If an older local installer build left
`build/windows/x64/runner/Release/tools/ffmpeg/`, the script stops rather
than silently repackage the obsolete CLI executables. Move that **generated**
folder out of Release and rebuild. Your original downloaded source folder
(such as `installer/ffmpeg-9.0.2-essentials_build/`) is left untouched and
is no longer used by the script.

**Licensing:** this plugin's GPL variant includes GPL-licensed codecs.
Review the plugin's exact FFmpegKit and third-party library notices and
corresponding-source obligations before public redistribution.

From the repository root in PowerShell:

```powershell
.\tool\build_windows_installer.ps1
```

For an existing Windows Release bundle:

```powershell
.\tool\build_windows_installer.ps1 -SkipFlutterBuild
```

If switching from a Debug build causes missing `cpp_client_wrapper/*.cc` files
in the Windows Release build, request a clean rebuild explicitly:

```powershell
.\tool\build_windows_installer.ps1 -CleanFlutterBuild
```

This runs `flutter clean` and `flutter pub get` before building Release.
It is slower than an incremental build, so it is optional and cannot be combined
with `-SkipFlutterBuild`.

If any app-local VC runtime DLLs are missing, the script automatically
locates a complete **x64** runtime set in installed Visual Studio C++
redistributable folders (or via `VCToolsRedistDir` in a developer shell).
It checks their Windows x64 PE headers and copies all three DLLs as a matching
set into the existing Release folder. **No separate VC++ installer is run.**

If auto-discovery cannot find the files (for example, with a custom Visual
Studio installation), locate the `x64\Microsoft.VC143.CRT` folder in your
Visual Studio `VC\Redist\MSVC` installation and supply it explicitly:

```powershell
.\tool\build_windows_installer.ps1 -SkipFlutterBuild -VcRuntimeSourceDirectory 'C:\path\to\x64\Microsoft.VC143.CRT'
```

An explicitly supplied folder must contain `msvcp140.dll`,
`vcruntime140.dll`, and `vcruntime140_1.dll`. If the files are not
installed, use Visual Studio Installer to add the MSVC C++ redistributable
components. Do not copy DLLs from `System32` or arbitrary download sites.

The script builds the **complete** Flutter release folder, checks its engine,
assets, application executable and three principal x64 VC runtime DLLs,
includes the FFmpegKit native libraries and notices, then passes the version and
build number from `pubspec.yaml` to Inno Setup.

Example when `pubspec.yaml` says `3.0.1+31`:

- Installer: `installer/output/SubtitleStudio_3.0.1_31_Windows_x64_Setup.exe`
- Checksum: matching `.exe.sha256` file

The output directory is ignored by Git. The installer includes the GPL v3
license and will allow per-user installation without admin rights, with an
optional all-users choice. Start Menu and optional desktop shortcuts are
created by Windows-aware paths.

### Signing for public releases

An unsigned build is suitable for internal testing only. Public release
installers should use a trusted Authenticode signing certificate. With the
Windows SDK `signtool.exe` on PATH and a suitable certificate accessible in
the Windows certificate store:

```powershell
.\tool\build_windows_installer.ps1 -SigningCertificateThumbprint 'YOUR_40_HEX_CHARACTER_THUMBPRINT'
```

This signs `SubtitleStudio.exe` before packaging, and Inno Setup signs the
installer **and its uninstaller**. Timestamping uses DigiCert's RFC 3161
service. No private keys or passwords belong in this repository.

If the versioned installer already exists, rebuild explicitly with
`-ReplaceExistingInstaller`. If only installer resources changed, skip the
Flutter rebuild:

```powershell
.\tool\build_windows_installer.ps1 -SkipFlutterBuild -ReplaceExistingInstaller
```

The packaging script renders the original green Windows application icon
into a standard **24-bit BMP** for the wizard's upper-right artwork. This
avoids unsupported PNG encodings surfacing as a `Bitmap image not valid`
error when switching from the installation-scope page to the next page.
The generated bitmap is local to `installer/output`; the original icon and
in-app branding images are not modified.

Verify the final signature with:

```powershell
Get-AuthenticodeSignature .\installer\output\SubtitleStudio_3.0.1_31_Windows_x64_Setup.exe
```

## Important behavior

- The Windows executable, shortcuts and installer use the original green-background
  icon in `windows/runner/resources/app_icon.ico`. Keep the separate SVG branding
  assets for the in-app interface; do not replace the Windows icon with them.
- Register supported `.srt` and `.msone` files as optional **Open with**
  choices. The installer does not take over the user's default apps.
- Do **not** register `.ass`, `.ssa`, or `.vtt` until true format support is
  implemented. These file types are not currently imported in Studio Dock.
- **FFmpegKit native libraries** support waveform generation and subtitle
  extraction. The setup includes their notices and does not run `winget`,
  download standalone FFmpeg, or modify PATH.
- The installer uses application-local VC runtime DLLs rather than running a
  machine-wide redist installer. No old DirectX web setup is bundled.
- Upgrades reuse the stable Inno `AppId` in `SubtitleStudio.iss`.
- Uninstall removes installed application files and only our own optional
  registry values; **user subtitles, .msone projects, app data, caches, and
  preferences are not deliberately deleted**.
- The prototype's placeholder `AppId` cannot be reliably upgraded in place.
  Uninstall older prototype setups before adopting this installer. Keep the
  new `AppId` unchanged for every subsequent release.

## Windows release acceptance checklist

Perform on a clean Windows 10/11 x64 VM and on an upgrading installation.

- [ ] `flutter analyze` and `flutter test` pass in the VS Code workspace.
- [ ] The exact Flutter Windows Release folder launches before packaging.
- [ ] Installer build reports a SHA-256 digest and matching version numbers.
- [ ] Installer starts on a fresh x64 Windows machine without relying on
      Flutter or Visual Studio being installed on that machine.
- [ ] Both **Install only for me** and **Install for all users** choices
      proceed past the wizard artwork without bitmap errors.
- [ ] Current-user mode installs without an elevation prompt; optional
      all-users mode requests elevation intentionally.
- [ ] Launch from Start Menu/desktop shortcut works; application icon and
      version metadata display correctly.
- [ ] Optional **Open with** on `.srt` opens Studio Dock's SRT import options;
      `.msone` opens the full project import options.
- [ ] `.ass` and `.vtt` are not claimed as supported file associations.
- [ ] On a clean Windows VM **without system FFmpeg**, waveform generation,
      subtitle-track detection and extraction work via FFmpegKit native libraries.
- [ ] The installed `licenses/ffmpeg_kit_flutter_new_min_gpl/NOTICE.txt`
      exists alongside FFmpegKit native DLLs; review provenance and licensing.
- [ ] An outdated `tools/ffmpeg` folder in the generated Release directory
      prevents packaging until moved out of that directory.
- [ ] Upgrading from a prior installer with the new `AppId` preserves the
      user's sessions and choices.
- [ ] Uninstall removes application, shortcuts, and only our registration;
      user-created `.srt`/`.msone` files and app preferences remain.
- [ ] Authenticode signature (including the uninstaller) verifies before
      publishing an internet-facing installer.

**Build policy:** Windows installers are built and tested **locally**. Do not
add Windows/Android/macOS/Linux platform builds to GitHub Actions; use Actions
only for dependency resolution, Flutter analysis and tests when the connected
VS Code workspace is unavailable.
