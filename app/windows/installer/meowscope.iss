; Windows 版のインストーラー（デプロイ設計書 6.2）。Inno Setup 6.7.3 で作る
; 先に flutter build windows --release --dart-define=API_BASE_URL=<サーバーの URL> を行い、app フォルダーで次を動かす
;   ISCC.exe /DAppVersion=<pubspec.yaml の版> windows\installer\meowscope.iss
; 出力：build\installer\MeowScope-Setup-<版>.exe。署名はしない（技術選定書 5章）

; 開発版（デプロイ設計書 6.3）：flutter build windows --profile の後に /DDev を足すと、
; 配布版と別のアプリ「MeowScope Dev」として別のフォルダーに入る（配布版を上書きしない）
;   ISCC.exe /DDev /DAppVersion=<版> windows\installer\meowscope.iss

#ifndef AppVersion
  #error AppVersion を /DAppVersion=1.0.0 のように渡してください
#endif

#ifdef Dev
  #define AppIdValue "{{AF7018C5-ADAB-4914-8153-F586BE0A2DE0}"
  #define AppNameValue "MeowScope Dev"
  #define BuildDir "Profile"
  #define OutputName "MeowScope-Dev-Setup-" + AppVersion
#else
  #define AppIdValue "{{0C638A3C-C3A5-4A67-A25A-5B32B076DF7B}"
  #define AppNameValue "MeowScope"
  #define BuildDir "Release"
  #define OutputName "MeowScope-Setup-" + AppVersion
#endif

[Setup]
; 同じアプリとして上書き・アンインストールできるよう、AppId は変えない（開発版は別の AppId）
AppId={#AppIdValue}
AppName={#AppNameValue}
AppVersion={#AppVersion}
AppPublisher=major182
DefaultDirName={autopf}\{#AppNameValue}
DefaultGroupName={#AppNameValue}
DisableProgramGroupPage=yes
; 管理者の権限なしで、使う人のフォルダーに入れる
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SourceDir=..\..
OutputDir=build\installer
OutputBaseFilename={#OutputName}
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
Source: "build\windows\x64\runner\{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppNameValue}"; Filename: "{app}\meowscope.exe"
Name: "{autodesktop}\{#AppNameValue}"; Filename: "{app}\meowscope.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\meowscope.exe"; Description: "{cm:LaunchProgram,{#AppNameValue}}"; Flags: nowait postinstall skipifsilent
; アプリからの更新（F-UP-02）：アプリが確認なしのモード（/VERYSILENT）で動かしたときは、入れた後に開き直す
Filename: "{app}\meowscope.exe"; Flags: nowait skipifnotsilent
