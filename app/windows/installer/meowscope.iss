; Windows 版のインストーラー（デプロイ設計書 6.2）。Inno Setup 6.7.3 で作る
; 先に flutter build windows --release --dart-define=API_BASE_URL=<サーバーの URL> を行い、app フォルダーで次を動かす
;   ISCC.exe /DAppVersion=<pubspec.yaml の版> windows\installer\meowscope.iss
; 出力：build\installer\MeowScope-Setup-<版>.exe。署名はしない（技術選定書 5章）

#ifndef AppVersion
  #error AppVersion を /DAppVersion=1.0.0 のように渡してください
#endif

[Setup]
; 同じアプリとして上書き・アンインストールできるよう、AppId は変えない
AppId={{0C638A3C-C3A5-4A67-A25A-5B32B076DF7B}
AppName=MeowScope
AppVersion={#AppVersion}
AppPublisher=major182
DefaultDirName={autopf}\MeowScope
DefaultGroupName=MeowScope
DisableProgramGroupPage=yes
; 管理者の権限なしで、使う人のフォルダーに入れる
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SourceDir=..\..
OutputDir=build\installer
OutputBaseFilename=MeowScope-Setup-{#AppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\meowscope.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MeowScope"; Filename: "{app}\meowscope.exe"
Name: "{autodesktop}\MeowScope"; Filename: "{app}\meowscope.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\meowscope.exe"; Description: "{cm:LaunchProgram,MeowScope}"; Flags: nowait postinstall skipifsilent
