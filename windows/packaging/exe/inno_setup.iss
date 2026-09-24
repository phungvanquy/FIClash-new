[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={{INSTALL_DIR_NAME}}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
WizardStyle=modern
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed={{ARCH}}
ArchitecturesInstallIn64BitMode={{ARCH}}

[Code]
procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  Processes := ['FlClash.exe', 'FlClashCore.exe', 'FlClashHelperService.exe'];

  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure UnregisterHelperService;
var
  HelperPath: String;
  ResultCode: Integer;
begin
  HelperPath := ExpandConstant('{app}\\FlClashHelperService.exe');
  if FileExists(HelperPath) then
  begin
    Exec(HelperPath, 'uninstall', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  UnregisterHelperService;
  KillProcesses;
  Result := '';
end;

function ExpandEnvironmentStrings(Source: String; Destination: String; Size: Cardinal): Cardinal;
  external 'ExpandEnvironmentStringsW@kernel32.dll stdcall';

function DataFileAttributes(Path: String): Cardinal;
  external 'GetFileAttributesW@kernel32.dll stdcall';

function ExpandedPath(Value: String): String;
var
  Size: Cardinal;
begin
  Size := ExpandEnvironmentStrings(Value, '', 0);
  SetLength(Result, Size);
  if Size > 0 then
  begin
    ExpandEnvironmentStrings(Value, Result, Size);
    SetLength(Result, Size - 1);
  end;
end;

procedure RemoveAppData(Base: String);
var
  Directory: String;
  Attributes: Cardinal;
begin
  if Base = '' then Exit;
  Attributes := DataFileAttributes(AddBackslash(Base) + 'com.follow');
  if (Attributes = $FFFFFFFF) or ((Attributes and $400) <> 0) then Exit;
  Directory := AddBackslash(Base) + 'com.follow\clash';
  if DirExists(Directory) and not DelTree(Directory, True, True, True) then
    Log('Could not remove app data: ' + Directory);
  RemoveDir(AddBackslash(Base) + 'com.follow');
end;

function OwnsCommand(Command: String): Boolean;
var
  Executable: String;
begin
  Executable := ExpandConstant('{app}\FlClash.exe');
  Result := (CompareText(Command, Executable) = 0) or
    (CompareText(Command, '"' + Executable + '"') = 0) or
    (Pos(Lowercase('"' + Executable + '" '), Lowercase(Command)) = 1);
end;

procedure RemoveUserRegistration(Root: HKEY; Prefix: String);
var
  Schemes: TArrayOfString;
  Key, Command: String;
  I: Integer;
begin
  Schemes := ['clash', 'clashmeta', 'flclash'];
  for I := 0 to GetArrayLength(Schemes) - 1 do
  begin
    Key := Prefix + 'Software\Classes\' + Schemes[I];
    if RegQueryStringValue(Root, Key + '\shell\open\command', '', Command) and
      OwnsCommand(Command) then
      RegDeleteKeyIncludingSubkeys(Root, Key);
  end;
  Key := Prefix + 'Software\Microsoft\Windows\CurrentVersion\Run';
  if RegQueryStringValue(Root, Key, 'FlClash', Command) and OwnsCommand(Command) then
  begin
    RegDeleteValue(Root, Key, 'FlClash');
    RegDeleteValue(Root, Prefix +
      'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', 'FlClash');
  end;
end;

procedure RemoveSavedData;
var
  Profiles: TArrayOfString;
  Profile, Base, Key: String;
  I: Integer;
begin
  RemoveAppData(ExpandConstant('{userappdata}'));
  RemoveAppData(ExpandConstant('{localappdata}'));
  RemoveUserRegistration(HKCU, '');
  if not RegGetSubkeyNames(HKLM,
    'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList', Profiles) then Exit;
  for I := 0 to GetArrayLength(Profiles) - 1 do
  begin
    Key := 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + Profiles[I];
    if RegQueryStringValue(HKLM, Key, 'ProfileImagePath', Profile) then
    begin
      Profile := ExpandedPath(Profile);
      if Profile <> '' then
      begin
        RemoveAppData(AddBackslash(Profile) + 'AppData\Roaming');
        RemoveAppData(AddBackslash(Profile) + 'AppData\Local');
      end;
    end;
    Key := Profiles[I] + '\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders';
    if RegQueryStringValue(HKU, Key, 'AppData', Base) then RemoveAppData(Base);
    if RegQueryStringValue(HKU, Key, 'Local AppData', Base) then RemoveAppData(Base);
    RemoveUserRegistration(HKU, Profiles[I] + '\');
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    UnregisterHelperService;
    KillProcesses;
    RemoveSavedData;
  end;
end;

[Languages]
{% for locale in LOCALES %}
{% if locale.lang == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% if locale.lang == 'hy' %}Name: "armenian"; MessagesFile: "compiler:Languages\\Armenian.isl"{% endif %}
{% if locale.lang == 'bg' %}Name: "bulgarian"; MessagesFile: "compiler:Languages\\Bulgarian.isl"{% endif %}
{% if locale.lang == 'ca' %}Name: "catalan"; MessagesFile: "compiler:Languages\\Catalan.isl"{% endif %}
{% if locale.lang == 'zh' %}
Name: "chineseSimplified"; MessagesFile: {% if locale.file %}{{ locale.file }}{% else %}"compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% endif %}
{% if locale.lang == 'co' %}Name: "corsican"; MessagesFile: "compiler:Languages\\Corsican.isl"{% endif %}
{% if locale.lang == 'cs' %}Name: "czech"; MessagesFile: "compiler:Languages\\Czech.isl"{% endif %}
{% if locale.lang == 'da' %}Name: "danish"; MessagesFile: "compiler:Languages\\Danish.isl"{% endif %}
{% if locale.lang == 'nl' %}Name: "dutch"; MessagesFile: "compiler:Languages\\Dutch.isl"{% endif %}
{% if locale.lang == 'fi' %}Name: "finnish"; MessagesFile: "compiler:Languages\\Finnish.isl"{% endif %}
{% if locale.lang == 'fr' %}Name: "french"; MessagesFile: "compiler:Languages\\French.isl"{% endif %}
{% if locale.lang == 'de' %}Name: "german"; MessagesFile: "compiler:Languages\\German.isl"{% endif %}
{% if locale.lang == 'he' %}Name: "hebrew"; MessagesFile: "compiler:Languages\\Hebrew.isl"{% endif %}
{% if locale.lang == 'is' %}Name: "icelandic"; MessagesFile: "compiler:Languages\\Icelandic.isl"{% endif %}
{% if locale.lang == 'it' %}Name: "italian"; MessagesFile: "compiler:Languages\\Italian.isl"{% endif %}
{% if locale.lang == 'ja' %}Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"{% endif %}
{% if locale.lang == 'no' %}Name: "norwegian"; MessagesFile: "compiler:Languages\\Norwegian.isl"{% endif %}
{% if locale.lang == 'pl' %}Name: "polish"; MessagesFile: "compiler:Languages\\Polish.isl"{% endif %}
{% if locale.lang == 'pt' %}Name: "portuguese"; MessagesFile: "compiler:Languages\\Portuguese.isl"{% endif %}
{% if locale.lang == 'ru' %}Name: "russian"; MessagesFile: "compiler:Languages\\Russian.isl"{% endif %}
{% if locale.lang == 'sk' %}Name: "slovak"; MessagesFile: "compiler:Languages\\Slovak.isl"{% endif %}
{% if locale.lang == 'sl' %}Name: "slovenian"; MessagesFile: "compiler:Languages\\Slovenian.isl"{% endif %}
{% if locale.lang == 'es' %}Name: "spanish"; MessagesFile: "compiler:Languages\\Spanish.isl"{% endif %}
{% if locale.lang == 'tr' %}Name: "turkish"; MessagesFile: "compiler:Languages\\Turkish.isl"{% endif %}
{% if locale.lang == 'uk' %}Name: "ukrainian"; MessagesFile: "compiler:Languages\\Ukrainian.isl"{% endif %}
{% endfor %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: files; Name: "{autoprograms}\\FlClash.lnk"
Type: files; Name: "{autodesktop}\\FlClash.lnk"

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
[Run]
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: runasoriginaluser nowait postinstall skipifsilent
