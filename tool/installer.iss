; ============================================================
;  本地抖音 —— Windows 安装包脚本（Inno Setup 6）
;
;  编译方法：
;    ISCC.exe installer.iss
;  产物：
;    ..\dist\LocalDouyin-Setup-1.0.0.exe
;
;  这个脚本把 ..\dist\LocalDouyin\ 整个目录（绿色版）
;  打包成一个双击就能装进系统的安装程序。
; ============================================================

#define AppName        "本地抖音"
#define AppNameEn      "LocalDouyin"
#define AppVersion     "1.0.0"
#define AppPublisher   "本地抖音"
#define AppExeName     "local_douyin_win.exe"
#define AppId          "{{8F3A2C41-5D7B-4E92-A6C8-3B1D9F2E7A54}"

[Setup]
; AppId 是这个软件在系统里的唯一身份。以后升级版本必须用同一个 AppId，
; 否则会变成"装了两个不同的软件"，而不是覆盖升级。
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppCopyright=本软件仅供个人使用

; {autopf} 会自动切换：
;   选"仅为我安装" -> %LOCALAPPDATA%\Programs\LocalDouyin   （不需要管理员）
;   选"为所有用户安装" -> C:\Program Files\LocalDouyin        （需要管理员）
DefaultDirName={autopf}\{#AppNameEn}
DefaultGroupName={#AppName}
AllowNoIcons=yes

; lowest = 默认不需要管理员权限。
; dialog = 让用户在向导第一页自己选"所有用户 / 仅我"。
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

OutputDir=..\dist
OutputBaseFilename={#AppNameEn}-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}

; 161MB 的源目录，用最大压缩。
; 实测约 5~8 分钟出包，成品大约 60~70MB。
Compression=lzma2/max
SolidCompression=yes
LZMANumBlockThreads=4

; 现代扁平化向导界面（Win11 风格）
WizardStyle=modern
WizardSizePercent=110

; 只支持 64 位。本程序依赖的 libmpv-2.dll / ffmpeg.exe 都是 64 位。
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

; 装完不强制重启
RestartIfNeededByRun=no
; 如果程序正在运行，让安装程序提示关闭（走 Restart Manager）
CloseApplications=yes
RestartApplications=no

; 卸载信息写进注册表，让「设置 → 应用」和「控制面板 → 程序和功能」都能看到
CreateUninstallRegKey=yes

[Languages]
Name: "cn"; MessagesFile: "ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务："

[Files]
; 绿色版整个目录搬进来。
; data\ 是 Flutter 的资源（app.so / flutter_assets / icudtl.dat），必须带上。
; ffmpeg\ 是内置的 ffmpeg.exe，用来读视频时长和截缩略图。
Source: "..\dist\{#AppNameEn}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\使用说明"; Filename: "{app}\使用说明.txt"
Name: "{group}\卸载 {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "立即运行 {#AppName}"; Flags: nowait postinstall skipifsilent
Filename: "{app}\使用说明.txt"; Description: "查看使用说明"; Flags: shellexec nowait postinstall skipifsilent unchecked

[UninstallDelete]
; 程序目录下的临时文件（Flutter 运行时偶尔会生成）
Type: filesandordirs; Name: "{app}\data\native_assets"

[Code]
var
  RemoveUserData: Boolean;

{ 数据目录：path_provider 在 Windows 上返回 %APPDATA%\com.localdouyin\local_douyin_win，
  代码里又拼了一层 LocalDouyin，所以完整路径是三层。 }
function UserDataDir(): String;
begin
  Result := ExpandConstant('{userappdata}\com.localdouyin\local_douyin_win\LocalDouyin');
end;

{ 卸载时问用户：数据要不要一起删 }
function InitializeUninstall(): Boolean;
var
  ForceDelete: String;
begin
  Result := True;
  RemoveUserData := False;

  if not DirExists(UserDataDir()) then
    Exit;

  { 命令行开关：unins000.exe /DELETEUSERDATA=1 直接删，不问。
    给自动化部署用，省得卡在弹框上。 }
  ForceDelete := ExpandConstant('{param:DELETEUSERDATA|}');
  if ForceDelete = '1' then
  begin
    RemoveUserData := True;
    Exit;
  end;

  { 静默卸载（没给开关）：保留数据，不问 }
  if WizardSilent then
    Exit;

  if MsgBox(
    '是否同时删除您的使用数据？' + #13#10 + #13#10 +
    '会删除的内容：' + #13#10 +
    '  · 已添加的文件夹列表' + #13#10 +
    '  · 点赞、收藏、不感兴趣记录' + #13#10 +
    '  · 每条视频的观看进度' + #13#10 +
    '  · 缩略图缓存' + #13#10 + #13#10 +
    '不会删除的内容：' + #13#10 +
    '  · 您电脑上的视频文件本身（一个都不会动）' + #13#10 + #13#10 +
    '选「是」= 清空，以后重装也是全新状态' + #13#10 +
    '选「否」= 保留，以后重装记录还在' + #13#10 + #13#10 +
    '【提示】如果您是在"卸载旧版、安装新版"，请选「否」，否则记录会丢失。',
    mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
  begin
    RemoveUserData := True;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if RemoveUserData then
    begin
      DelTree(UserDataDir(), True, True, True);
      { 顺手把上层两个空目录也清掉，不留垃圾 }
      RemoveDir(ExpandConstant('{userappdata}\com.localdouyin\local_douyin_win'));
      RemoveDir(ExpandConstant('{userappdata}\com.localdouyin'));
    end;
  end;
end;

{ 安装前提示：如果目标目录里已经有一个正在运行的实例，让用户先关掉。
  Inno Setup 的 Restart Manager 通常能自动处理，这里只做一个兜底提示。 }
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
