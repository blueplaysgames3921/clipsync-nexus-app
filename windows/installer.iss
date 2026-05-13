; windows/installer.iss
; Inno Setup 6 script — creates ClipSyncNexus_Setup_1.0.0.exe

#define AppName      "ClipSync Nexus"
#define AppVersion   "1.0.0"
#define AppPublisher "ClipSync Inc."
#define AppURL       "https://clipsync.app"
#define AppExeName   "clipsync_nexus.exe"
#define BuildDir     "..\build\windows\x64\runner\Release"

[Setup]
AppId={{A4E2F3B1-8C7D-4A9E-B2F0-1D3C5E7A9B0C}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/support
AppUpdatesURL={#AppURL}/releases
DefaultDirName={autopf}\ClipSyncNexus
DefaultGroupName={#AppName}
AllowNoIcons=yes
LicenseFile=..\LICENSE
OutputDir=..\build\windows
OutputBaseFilename=ClipSyncNexus_Setup_{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequiredOverridesAllowed=dialog
; Windows 10 1903+
MinVersion=10.0.18362
ArchitecturesInstallIn64BitMode=x64compatible
; DPI awareness
SetupIconFile=..\assets\icons\icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
; Run at startup (optional — user can disable in settings)
ChangesEnvironment=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon";    Description: "{cm:CreateDesktopIcon}";    GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupentry";   Description: "Start ClipSync Nexus when Windows starts"; GroupDescription: "Startup:"; Flags: unchecked

[Files]
; Main executable and all Flutter DLLs/assets from release build
Source: "{#BuildDir}\{#AppExeName}";     DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*";            DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}";                  Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}";        Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}";            Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Registry]
; Startup entry
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
  ValueType: string; ValueName: "ClipSyncNexus"; \
  ValueData: """{app}\{#AppExeName}"""; \
  Flags: uninsdeletevalue; Tasks: startupentry

; File associations (optional — .csn scratchpad files)
Root: HKCR; Subkey: ".csn";                 ValueType: string; ValueData: "ClipSyncNexus.Scratchpad"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "ClipSyncNexus.Scratchpad"; ValueType: string; ValueData: "ClipSync Nexus Scratchpad"; Flags: uninsdeletekey
Root: HKCR; Subkey: "ClipSyncNexus.Scratchpad\DefaultIcon"; ValueType: string; ValueData: "{app}\{#AppExeName},0"
Root: HKCR; Subkey: "ClipSyncNexus.Scratchpad\shell\open\command"; ValueType: string; ValueData: """{app}\{#AppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Remove database and settings on uninstall (user-confirmed)
Type: filesandordirs; Name: "{localappdata}\com.clipsync.nexus"
