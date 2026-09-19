; windows/installer/mitso_schedule.iss
;
; Установщик «Расписания» для Windows (Inno Setup 6).
;
; Ставится в профиль пользователя, без прав администратора и без выбора
; папки: %LOCALAPPDATA%\Programs\Расписание МИТСО. Настройки и кэш лежат
; отдельно, в %APPDATA%\com.z43studios\mitso_schedule — установщик и
; деинсталлятор их не трогают.
;
; Сборка: tool/build_windows_installer.ps1, или вручную из этой папки:
;   iscc /DAppVersion=1.0.0 mitso_schedule.iss
;
; Тихое обновление из приложения (lib/features/updater/update_installer.dart):
;   mitso-schedule-setup.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /update=1 /LOG=...
; Установщик ждёт, пока приложение закроется, заменяет файлы (при сбое Inno
; Setup откатывает изменения) и с /update=1 запускает приложение снова.

#ifndef AppVersion
  #error Не задана версия: iscc /DAppVersion=X.Y.Z mitso_schedule.iss
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\installer"
#endif

#define AppName "Расписание МИТСО"
#define AppPublisher "Z43 Studios"
#define AppExeName "mitso_schedule.exe"
; Совпадает с kSingleInstanceMutex в windows/runner/main.cpp.
#define AppMutexName "Z43Studios.MitsoSchedule.SingleInstance"

[Setup]
; AppId — постоянный идентификатор установки. НИКОГДА не менять: по нему
; новая версия находит и обновляет старую.
AppId={{0B09A952-55F2-44F7-BF5C-DE8BA78BD532}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppSupportURL=https://github.com/OrionZ43/mitso_schedule
AppUpdatesURL=https://github.com/OrionZ43/mitso_schedule/releases
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoProductName={#AppName}
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
; Папку не выбираем: установщик чистит в ней файлы прошлой версии
; (см. [InstallDelete]), чужая папка под это попасть не должна.
DisableDirPage=yes
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=force
RestartApplications=no
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
OutputDir={#OutputDir}
OutputBaseFilename=mitso-schedule-setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
SetupLogging=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Файлы прошлой версии, которых может не быть в новой: ассеты Flutter и DLL
; плагинов. Пользовательских данных в папке программы нет.
Type: filesandordirs; Name: "{app}\data"
Type: files; Name: "{app}\*.dll"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; Обычная установка — флажок «Запустить» на последней странице.
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent
; Тихое обновление из приложения (/update=1) — запустить сразу.
Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Flags: nowait; Check: IsUpdateRun

[Code]
const
  AppMutexName = '{#AppMutexName}';

function IsUpdateRun: Boolean;
begin
  Result := ExpandConstant('{param:update|0}') = '1';
end;

{ Ждёт, пока приложение закроется. True — закрылось. }
function WaitForAppExit(TimeoutMs: Integer): Boolean;
var
  Waited: Integer;
begin
  Waited := 0;
  while CheckForMutexes(AppMutexName) and (Waited < TimeoutMs) do
  begin
    Sleep(250);
    Waited := Waited + 250;
  end;
  Result := not CheckForMutexes(AppMutexName);
end;

{ Просит закрыть приложение, пока оно запущено. False — пользователь отказался. }
function AskToCloseApp(const Action: String): Boolean;
begin
  Result := True;
  while CheckForMutexes(AppMutexName) do
    if MsgBox('«Расписание» сейчас запущено. Закройте его и нажмите «OK», ' +
      'чтобы ' + Action + '.', mbInformation, MB_OKCANCEL) = IDCANCEL then
    begin
      Result := False;
      Exit;
    end;
end;

function InitializeSetup: Boolean;
begin
  if WizardSilent then
  begin
    { Тихое обновление: приложение закрывается само сразу после запуска
      установщика, ждём до 15 секунд. }
    Result := WaitForAppExit(15000);
    if not Result then
      Log('Расписание всё ещё запущено — установка отменена');
  end
  else
    Result := AskToCloseApp('продолжить установку');
end;

function InitializeUninstall: Boolean;
begin
  if UninstallSilent then
    Result := WaitForAppExit(15000)
  else
    Result := AskToCloseApp('продолжить удаление');
end;
