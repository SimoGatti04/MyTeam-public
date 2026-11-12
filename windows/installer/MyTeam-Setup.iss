; MyTeam Windows Inno Setup Script
; Per-user installation; stable AppId and user data are kept outside the app folder.

#define MyAppName "MyTeam"
#ifndef MyAppVersion
  #define MyAppVersion "0.2.0"
#endif
#ifndef MyAppBuildNumber
  #define MyAppBuildNumber "2"
#endif
#define MyAppPublisher "Simone Gatti"
#define MyAppURL "https://myteam.simogatti.it"
#define MyAppExeName "myteam.exe"
#define MyAppSourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{9B7E3E5C-62E8-4DA4-8FB7-F58552309AA2}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputBaseFilename=MyTeam-Setup-{#MyAppVersion}-{#MyAppBuildNumber}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; In silent updater mode, use Windows Restart Manager for a graceful close and wait
; for loaded app DLLs to be released before replacement. Never relaunch the old app.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\LICENSE"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "..\..\assets\licenses\*"; DestDir: "{app}\licenses"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
