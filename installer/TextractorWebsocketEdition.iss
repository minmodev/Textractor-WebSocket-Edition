; Inno Setup script for Textractor Websocket Edition.
; Builds ONE installer that bundles both the x86 and x64 builds and installs
; whichever matches the user's Windows at install time.
;
; Prerequisites before compiling this script:
;   1. Build both configs first (see docs in the repo root for exact commands):
;        builds\RelWithDebInfo_x64\Textractor.exe  (from build-x64)
;        builds\RelWithDebInfo_x86\Textractor.exe  (from build-x86)
;   2. Install Inno Setup (free): https://jrsoftware.org/isinfo.php
;
; To build the installer:
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\TextractorWebsocketEdition.iss
; Output goes to installer\Output\TextractorWebsocketEdition-Setup.exe

#define MyAppName "Textractor Websocket Edition"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "minmodev (fork of Textractor by Artikash)"
#define MyAppURL "https://github.com/minmodev/Textractor-WebSocket-Edition"
#define MyAppExeName "Textractor.exe"

[Setup]
AppId={{B6E1E9C0-6E0A-4B7C-9E3F-2C9F1E7A9C31}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
SetupIconFile=..\GUI\Textractor.ico
; Lets the installer run per-user without admin rights if the user picks a
; writable install dir; falls back to elevation if they pick Program Files.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Installs to the native Program Files (not the x86 one) on 64-bit Windows.
ArchitecturesInstallIn64BitMode=x64
OutputDir=Output
OutputBaseFilename=TextractorWebsocketEdition-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
; 64-bit build - only installed on 64-bit Windows.
Source: "..\builds\RelWithDebInfo_x64\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion; \
    Excludes: "*.pdb,*.lib,*.exp,*.ilk"; Check: Is64BitInstallMode
; 32-bit build - only installed on 32-bit Windows.
Source: "..\builds\RelWithDebInfo_x86\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion; \
    Excludes: "*.pdb,*.lib,*.exp,*.ilk"; Check: not Is64BitInstallMode

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Silently ensure the matching VC++ runtime is present (windeployqt already
; copied the redistributable installer into each build's output folder).
Filename: "{app}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
    StatusMsg: "Installing Visual C++ Runtime..."; Check: Is64BitInstallMode; Flags: waituntilterminated skipifdoesntexist
Filename: "{app}\vc_redist.x86.exe"; Parameters: "/install /quiet /norestart"; \
    StatusMsg: "Installing Visual C++ Runtime..."; Check: not Is64BitInstallMode; Flags: waituntilterminated skipifdoesntexist
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
