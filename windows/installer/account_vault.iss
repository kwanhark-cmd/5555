; 윈도우 설치 파일(Inno Setup). CI 가 ISCC 로 만든다.
; ★ AppId 는 절대 바꾸지 말 것: 같은 AppId 여야 새 버전이 기존 앱을 "덮어쓰기" 한다.
; 금고·설정은 %APPDATA%\com.kwanhark.vaultassistant\account_vault 에 있어 설치·제거와 무관하게 남는다.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6F1D7A3E-6C1B-4D2A-9B7E-1C2D3E4F5A6B}
AppName=구독·계정 비서
AppVersion={#AppVersion}
AppPublisher=kwanhark
DefaultDirName={localappdata}\Programs\AccountVault
DefaultGroupName=구독·계정 비서
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=account_vault-{#AppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
UninstallDisplayName=구독·계정 비서
SetupIconFile=..\runner\resources\app_icon.ico
WizardStyle=modern

[Languages]
#if FileExists(AddBackslash(CompilerPath) + "Languages\Korean.isl")
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
#else
Name: "english"; MessagesFile: "compiler:Default.isl"
#endif

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\구독·계정 비서"; Filename: "{app}\account_vault.exe"
Name: "{userdesktop}\구독·계정 비서"; Filename: "{app}\account_vault.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "바탕 화면에 아이콘 만들기"; Flags: unchecked

[Run]
Filename: "{app}\account_vault.exe"; Description: "지금 실행"; Flags: nowait postinstall skipifsilent
