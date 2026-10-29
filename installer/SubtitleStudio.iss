; Subtitle Studio - Windows x64 installer (Inno Setup 6.5.2+).
; Compile via tool/build_windows_installer.ps1. Do not edit version numbers here.

#ifndef AppVersion
  #error AppVersion must be supplied by the packaging script.
#endif
#ifndef BuildNumber
  #error BuildNumber must be supplied by the packaging script.
#endif
#ifndef ReleaseDir
  #error ReleaseDir must point to a complete Flutter Windows Release directory.
#endif
#ifndef InstallerOutputDir
  #error InstallerOutputDir must be supplied by the packaging script.
#endif

#define StudioName "Subtitle Studio"
#define StudioExe "SubtitleStudio.exe"
#define StudioPublisher "Anzil R"

[Setup]
; Stable ID for future upgrades. This differs from the placeholder used in
; the old prototype setup; uninstall that prototype before installing.
AppId={{EDB77F3B-8849-4E77-96E0-66F75805AC63}
AppName={#StudioName}
AppVersion={#AppVersion}
AppVerName={#StudioName} {#AppVersion} (build {#BuildNumber})
AppPublisher={#StudioPublisher}
AppPublisherURL=https://github.com/anzilr/SubtitleStudio
AppSupportURL=https://github.com/anzilr/SubtitleStudio/issues
AppUpdatesURL=https://github.com/anzilr/SubtitleStudio/releases
VersionInfoVersion={#AppVersion}.{#BuildNumber}
VersionInfoProductVersion={#AppVersion}
DefaultDirName={autopf}\SubtitleStudio
DefaultGroupName={#StudioName}
DisableProgramGroupPage=yes
DisableDirPage=auto
UsePreviousAppDir=yes
UsePreviousTasks=yes
UninstallDisplayName={#StudioName}
UninstallDisplayIcon={app}\{#StudioExe}
LicenseFile=..\LICENSE.txt
OutputDir={#InstallerOutputDir}
OutputBaseFilename=SubtitleStudio_{#AppVersion}_{#BuildNumber}_Windows_x64_Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
WizardStyle=modern
WizardSmallImageFile=..\assets\subtitle_studio_brand_icon.png
WizardSmallImageBackColor=$202020
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
CloseApplications=yes
RestartApplications=yes
ChangesAssociations=yes
Compression=lzma2/max
SolidCompression=yes
SetupLogging=yes

#ifdef SigningEnabled
; The build script registers the 'studio' Authenticode sign tool. Inno signs
; both the setup executable and its embedded uninstaller.
SignTool=studio
SignedUninstaller=yes
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked
Name: "srtopenwith"; Description: "Add Subtitle Studio to Open with for SRT subtitles"; GroupDescription: "File integration:"; Flags: unchecked
Name: "projectopenwith"; Description: "Add Subtitle Studio to Open with for .msone projects"; GroupDescription: "File integration:"

[Files]
; Include the complete Flutter Windows Release bundle: application, all DLLs,
; generated native assets, flutter_assets and runtime data. No EXE renaming.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb,*.ilk,*.exp"
Source: "..\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#StudioName}"; Filename: "{app}\{#StudioExe}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#StudioName}"; Filename: "{app}\{#StudioExe}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
; Register *only* supported SRT and .msone files, as Open with candidates.
; Do not claim a default, touch UserChoice, or delete third-party associations.
Root: HKA; Subkey: "Software\Classes\SubtitleStudio.SRT"; ValueType: string; ValueData: "SubRip subtitle"; Flags: uninsdeletekey; Tasks: srtopenwith
Root: HKA; Subkey: "Software\Classes\SubtitleStudio.SRT\DefaultIcon"; ValueType: string; ValueData: "{app}\{#StudioExe},0"; Tasks: srtopenwith
Root: HKA; Subkey: "Software\Classes\SubtitleStudio.SRT\shell\open\command"; ValueType: string; ValueData: """{app}\{#StudioExe}"" ""%1"""; Tasks: srtopenwith
Root: HKA; Subkey: "Software\Classes\.srt\OpenWithProgids"; ValueType: string; ValueName: "SubtitleStudio.SRT"; ValueData: ""; Flags: uninsdeletevalue; Tasks: srtopenwith

Root: HKA; Subkey: "Software\Classes\SubtitleStudio.Project"; ValueType: string; ValueData: "Subtitle Studio project"; Flags: uninsdeletekey; Tasks: projectopenwith
Root: HKA; Subkey: "Software\Classes\SubtitleStudio.Project\DefaultIcon"; ValueType: string; ValueData: "{app}\{#StudioExe},0"; Tasks: projectopenwith
Root: HKA; Subkey: "Software\Classes\SubtitleStudio.Project\shell\open\command"; ValueType: string; ValueData: """{app}\{#StudioExe}"" ""%1"""; Tasks: projectopenwith
Root: HKA; Subkey: "Software\Classes\.msone\OpenWithProgids"; ValueType: string; ValueName: "SubtitleStudio.Project"; ValueData: ""; Flags: uninsdeletevalue; Tasks: projectopenwith

[Run]
Filename: "{app}\{#StudioExe}"; Description: "Launch {#StudioName}"; Flags: nowait postinstall skipifsilent

; Intentionally no forced FFmpeg/winget, legacy DirectX web installer, or
; arbitrary uninstall cleanup. User projects and preferences are preserved.
