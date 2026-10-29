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

From the repository root in PowerShell:

```powershell
.\tool\build_windows_installer.ps1
```

For an existing Windows Release bundle:

```powershell
.\tool\build_windows_installer.ps1 -SkipFlutterBuild
```

If the app-local VC runtime DLLs are missing, locate the `x64\Microsoft.VC143.CRT`
folder in your Visual Studio `VC\Redist\MSVC` installation and supply:

```powershell
.\tool\build_windows_installer.ps1 -VcRuntimeSourceDirectory 'C:\path\to\x64\Microsoft.VC143.CRT'
```

The script builds the **complete** Flutter release folder, checks its engine,
assets, application executable and three principal x64 VC runtime DLLs, then
passes the version and build number from `pubspec.yaml` to Inno Setup.

Example when `pubspec.yaml` says `3.0.0+30`:

- Installer: `installer/output/SubtitleStudio_3.0.0_30_Windows_x64_Setup.exe`
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
`-ReplaceExistingInstaller`. Verify the final signature with:

```powershell
Get-AuthenticodeSignature .\installer\output\SubtitleStudio_3.0.0_30_Windows_x64_Setup.exe
```

## Important behavior

- Register supported `.srt` and `.msone` files as optional **Open with**
  choices. The installer does not take over the user's default apps.
- Do **not** register `.ass`, `.ssa`, or `.vtt` until true format support is
  implemented. These file types are not currently imported in Studio Dock.
- **FFmpeg and FFprobe are external prerequisites** for video extraction and
  some media workflows. The setup does not run `winget`, download FFmpeg,
  or silently modify PATH. See [FFmpeg downloads](https://ffmpeg.org/download.html)
  when you need those features.
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
- [ ] Current-user mode installs without an elevation prompt; optional
      all-users mode requests elevation intentionally.
- [ ] Launch from Start Menu/desktop shortcut works; application icon and
      version metadata display correctly.
- [ ] Optional **Open with** on `.srt` opens Studio Dock's SRT import options;
      `.msone` opens the full project import options.
- [ ] `.ass` and `.vtt` are not claimed as supported file associations.
- [ ] A Windows test with FFmpeg available can extract subtitles from video;
      missing FFmpeg reports a clear dependency message.
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
