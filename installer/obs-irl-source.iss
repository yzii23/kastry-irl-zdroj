; Inno Setup script for the Windows release of kastry-irl-source.
;
; Build it with:
;   iscc /DPluginVersion=1.3.4 /DPayloadDir=..\dist\windows installer\obs-irl-source.iss
;
; PayloadDir must hold the same layout as the release zip
; (obs-plugins\64bit\kastry-irl-source.dll), so CI stages the zip contents and
; points this at them rather than maintaining a second file list.
;
; Note on the OBS version check below: the plugin bundles its own FFmpeg, so
; unlike plugins that link obs-deps' FFmpeg there is no exact-version coupling
; to enforce. libobs gates a module on major/minor only and a build against the
; oldest supported line loads on every newer one, which makes the correct check
; a *minimum*, not a match.

#ifndef PluginVersion
  #define PluginVersion "0.0.0"
#endif
#ifndef PayloadDir
  #define PayloadDir "..\dist\windows"
#endif

#define PluginId "kastry-irl-source"
#define AppName "Kastry IRL Source for OBS Studio"

[Setup]
AppId={{904F8590-4645-4CC5-A818-6099F97825CF}
AppName={#AppName}
AppVersion={#PluginVersion}
AppPublisher=Kastry
AppPublisherURL=https://github.com/yzii23/kastry-irl-zdroj
AppSupportURL=https://github.com/yzii23/kastry-irl-zdroj/issues
AppUpdatesURL=https://github.com/yzii23/kastry-irl-zdroj/releases
DefaultDirName={code:GetDefaultObsPath}
AppendDefaultDirName=no
DirExistsWarning=no
DisableProgramGroupPage=yes
Uninstallable=yes
UninstallFilesDir={app}\data\obs-plugins\{#PluginId}
UninstallDisplayName={#AppName}
PrivilegesRequired=admin
; x64compatible arrived in Inno Setup 6.3 and replaced the older x64 spelling,
; which 6.3 then started warning about. Accept either so the script compiles on
; whatever version a contributor or the CI runner happens to have.
#if VER >= EncodeVer(6,3,0)
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#else
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
#endif
MinVersion=10.0.17763
WizardStyle=modern
ShowLanguageDialog=auto
Compression=lzma2/ultra64
SolidCompression=yes
SetupLogging=yes
; OBS holds the plugin DLL open, so it has to be closed before the copy.
CloseApplications=yes
RestartApplications=no
LicenseFile=..\LICENSE
OutputDir=..\dist
OutputBaseFilename={#PluginId}-{#PluginVersion}-windows-x64-setup
VersionInfoVersion={#PluginVersion}.0
VersionInfoCompany=Kastry
VersionInfoDescription=Kastry IRL Source for OBS Studio
VersionInfoProductName={#PluginId}
VersionInfoProductVersion={#PluginVersion}

; Czech for a Czech Windows, English otherwise (ShowLanguageDialog=auto asks
; only when neither matches). The file is UTF-8 with a BOM, which is how the
; compiler knows the Czech texts are UTF-8.
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "czech"; MessagesFile: "compiler:Languages\Czech.isl"

[Messages]
english.SelectDirLabel3=Setup will install the plugin into your OBS Studio folder.
english.SelectDirBrowseLabel=To continue, click Next. To install into a different OBS Studio folder (a portable install, for example), click Browse.
czech.SelectDirLabel3=Instalátor nainstaluje plugin do složky OBS Studia.
czech.SelectDirBrowseLabel=Pokračuj tlačítkem Další. Pro instalaci do jiné složky OBS Studia (třeba přenosné verze) klikni na Procházet.

[CustomMessages]
english.LaunchObs=Launch OBS Studio
czech.LaunchObs=Spustit OBS Studio
english.UserCopy=Another copy of this plugin is installed for your user account at:%n%n%1%n%nOBS loads both and the second one fails to register. Delete that folder after Setup finishes.
czech.UserCopy=Pro tvůj uživatelský účet je nainstalovaná ještě jedna kopie tohoto pluginu:%n%n%1%n%nOBS načte obě a druhá se nezaregistruje. Po dokončení instalace tu složku smaž.
english.NotObsFolder=Please select the OBS Studio root folder.%n%n%1 was not found in the selected directory.
czech.NotObsFolder=Vyber hlavní složku OBS Studia.%n%nVe vybrané složce není %1.
english.ObsTooOld=This plugin needs OBS Studio %1 or newer.%n%nDetected version: %2%n%nIt will not load on this version. Install anyway?
czech.ObsTooOld=Tenhle plugin potřebuje OBS Studio %1 nebo novější.%n%nNalezená verze: %2%n%nV téhle verzi se nenačte. Přesto nainstalovat?

[Files]
Source: "{#PayloadDir}\obs-plugins\64bit\kastry-irl-source.dll"; DestDir: "{app}\obs-plugins\64bit"; Flags: ignoreversion
; Not optional: obs_module_text() falls back to the lookup key, so without the
; locale file the properties dialog renders as bare identifiers.
Source: "..\data\locale\*"; DestDir: "{app}\data\obs-plugins\{#PluginId}\locale"; Flags: ignoreversion
; The Provider dropdown's list. A host that edited it re-applies its copy after
; an upgrade; see docs/provider-protocol.md.
Source: "..\data\providers.json"; DestDir: "{app}\data\obs-plugins\{#PluginId}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}\data\obs-plugins\{#PluginId}"; Flags: ignoreversion
Source: "..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}\data\obs-plugins\{#PluginId}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}\data\obs-plugins\{#PluginId}"; Flags: ignoreversion

[InstallDelete]
; Versions up to 1.x shipped w32-pthreads.dll beside the plugin, because the
; C build linked pthreads through it. The Rust plugin never calls pthreads, so
; the file is no longer part of the payload; an in-place upgrade would
; otherwise leave a stale copy shadowing the one OBS ships in bin\64bit.
Type: files; Name: "{app}\obs-plugins\64bit\w32-pthreads.dll"

[Run]
; runasoriginaluser keeps OBS out of the elevated token the installer runs under.
Filename: "{app}\bin\64bit\obs64.exe"; WorkingDir: "{app}\bin\64bit"; Description: "{cm:LaunchObs}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[Code]
const
  ObsExecutable = 'bin\64bit\obs64.exe';
  MinObsMajor = 32;
  MinObsMinor = 1;

function IsValidObsPath(const Path: String): Boolean;
begin
  Result := FileExists(AddBackslash(Path) + ObsExecutable);
end;

{ OBS's own installer records its location in two places, and a per-user
  install only writes HKCU, so both hives are probed before falling back. }
function RegistryObsPath(): String;
var
  Candidate: String;
begin
  Result := '';

  if RegQueryStringValue(HKLM64,
       'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OBS Studio',
       'InstallLocation', Candidate) and IsValidObsPath(Candidate) then
  begin
    Result := RemoveBackslashUnlessRoot(Candidate);
    Exit;
  end;

  if RegQueryStringValue(HKCU,
       'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OBS Studio',
       'InstallLocation', Candidate) and IsValidObsPath(Candidate) then
  begin
    Result := RemoveBackslashUnlessRoot(Candidate);
    Exit;
  end;

  if RegQueryStringValue(HKLM64, 'SOFTWARE\OBS Studio', '', Candidate)
     and IsValidObsPath(Candidate) then
  begin
    Result := RemoveBackslashUnlessRoot(Candidate);
    Exit;
  end;
end;

function GetDefaultObsPath(Param: String): String;
begin
  Result := RegistryObsPath();
  if Result = '' then
    Result := ExpandConstant('{autopf}\obs-studio');
end;

{ Returns False only when the version could be read *and* is too old. An
  unreadable version is not treated as a failure: better to install than to
  block a portable or custom build whose obs64.exe carries no version info. }
function ObsVersionIsSupported(const Path: String; var Detected: String): Boolean;
var
  VersionMS, VersionLS: Cardinal;
  Major, Minor, Patch: Integer;
begin
  Result := True;
  Detected := '';

  if not GetVersionNumbers(AddBackslash(Path) + ObsExecutable, VersionMS, VersionLS) then
    Exit;

  Major := VersionMS shr 16;
  Minor := VersionMS and $FFFF;
  Patch := VersionLS shr 16;
  Detected := IntToStr(Major) + '.' + IntToStr(Minor) + '.' + IntToStr(Patch);

  Result := (Major > MinObsMajor) or
            ((Major = MinObsMajor) and (Minor >= MinObsMinor));
end;

{ A second copy under the per-user plugin directory would make OBS load the
  module twice and fail the second registration, so warn if one is there.
  `cmake --install` on Windows writes exactly this path, so developers who
  built from source are the ones most likely to hit it. }
procedure WarnAboutUserInstall();
var
  UserCopy: String;
begin
  UserCopy := ExpandConstant('{userappdata}\obs-studio\plugins\{#PluginId}');
  if DirExists(UserCopy) then
    MsgBox(FmtMessage(CustomMessage('UserCopy'), [UserCopy]), mbInformation, MB_OK);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  DetectedVersion: String;
  MinVersion: String;
begin
  Result := True;
  if CurPageID <> wpSelectDir then
    Exit;

  if not IsValidObsPath(WizardDirValue) then
  begin
    MsgBox(FmtMessage(CustomMessage('NotObsFolder'), [ObsExecutable]), mbError, MB_OK);
    Result := False;
    Exit;
  end;

  if not ObsVersionIsSupported(WizardDirValue, DetectedVersion) then
  begin
    MinVersion := IntToStr(MinObsMajor) + '.' + IntToStr(MinObsMinor);
    Result := MsgBox(FmtMessage(CustomMessage('ObsTooOld'), [MinVersion, DetectedVersion]),
                     mbConfirmation, MB_YESNO) = IDYES;
    if not Result then
      Exit;
  end;

  WarnAboutUserInstall();
end;
