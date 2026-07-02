; Inno Setup script for Textractor Websocket Edition.
; Builds ONE installer that installs BOTH the x86 and x64 builds side by
; side (into x64\ and x86\ subfolders), with separate shortcuts for each.
; Textractor needs both because the hook injector must match the bitness
; of the game you're attaching to.
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
#define MyAppExeNameX64 "Textractor-x64.exe"
#define MyAppExeNameX86 "Textractor-x86.exe"

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
; 64-bit build - always installed, into its own subfolder. Textractor.exe
; is renamed to Textractor-x64.exe so the two builds are distinguishable
; if you ever copy/zip the install folder up instead of using shortcuts.
Source: "..\builds\RelWithDebInfo_x64\Textractor.exe"; DestDir: "{app}\x64"; DestName: "{#MyAppExeNameX64}"; Flags: ignoreversion
Source: "..\builds\RelWithDebInfo_x64\*"; DestDir: "{app}\x64"; Flags: recursesubdirs ignoreversion; \
    Excludes: "*.pdb,*.lib,*.exp,*.ilk,Textractor.exe"
; 32-bit build - always installed, into its own subfolder. Kept separate
; from x64\ because a 32-bit Qt5Core.dll etc. can't coexist in the same
; folder as the 64-bit copy of the same filename.
Source: "..\builds\RelWithDebInfo_x86\Textractor.exe"; DestDir: "{app}\x86"; DestName: "{#MyAppExeNameX86}"; Flags: ignoreversion
Source: "..\builds\RelWithDebInfo_x86\*"; DestDir: "{app}\x86"; Flags: recursesubdirs ignoreversion; \
    Excludes: "*.pdb,*.lib,*.exp,*.ilk,Textractor.exe"

[Icons]
Name: "{group}\{#MyAppName} (x64)"; Filename: "{app}\x64\{#MyAppExeNameX64}"
Name: "{group}\{#MyAppName} (x86)"; Filename: "{app}\x86\{#MyAppExeNameX86}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName} (x64)"; Filename: "{app}\x64\{#MyAppExeNameX64}"; Tasks: desktopicon
Name: "{autodesktop}\{#MyAppName} (x86)"; Filename: "{app}\x86\{#MyAppExeNameX86}"; Tasks: desktopicon

[Run]
; Silently ensure both VC++ runtimes are present (windeployqt already
; copied the matching redistributable installer into each build's output).
Filename: "{app}\x64\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
    StatusMsg: "Installing 64-bit Visual C++ Runtime..."; Flags: waituntilterminated skipifdoesntexist
Filename: "{app}\x86\vc_redist.x86.exe"; Parameters: "/install /quiet /norestart"; \
    StatusMsg: "Installing 32-bit Visual C++ Runtime..."; Flags: waituntilterminated skipifdoesntexist
Filename: "{app}\x64\{#MyAppExeNameX64}"; Description: "Launch {#MyAppName} (x64)"; Flags: nowait postinstall skipifsilent unchecked
Filename: "{app}\x86\{#MyAppExeNameX86}"; Description: "Launch {#MyAppName} (x86)"; Flags: nowait postinstall skipifsilent unchecked
