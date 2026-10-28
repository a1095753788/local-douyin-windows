; *** 本地抖音 —— 简体中文语言包 ***
;
; 这是给 Inno Setup 6 用的自定义语言文件。
; 只需要写「想翻译的条目」，没写的会自动沿用 Default.isl 的英文，
; 不会报错、也不会影响功能。

[LangOptions]
LanguageName=简体中文
LanguageID=$0804
LanguageCodePage=936
; 中文界面用微软雅黑，比默认的 Tahoma 好看
DialogFontName=Microsoft YaHei UI
DialogFontSize=9
WelcomeFontName=Microsoft YaHei UI
WelcomeFontSize=12

[Messages]

; *** 程序标题
SetupAppTitle=安装程序
SetupWindowTitle=%1 安装程序
UninstallAppTitle=卸载
UninstallAppFullTitle=%1 卸载

; *** 通用
InformationTitle=提示
ConfirmTitle=确认
ErrorTitle=错误

; *** 启动器
SetupLdrStartupMessage=即将安装 %1，是否继续？
LdrCannotCreateTemp=无法创建临时文件，安装程序已终止
LdrCannotExecTemp=无法在临时目录中运行文件，安装程序已终止

; *** 启动错误
LastErrorMessage=%1.%n%n错误 %2：%3
SetupFileMissing=安装目录中缺少文件 %1。请修正此问题，或重新获取一份程序。
SetupFileCorrupt=安装文件已损坏。请重新获取一份程序。
SetupFileCorruptOrWrongVer=安装文件已损坏，或与本版本安装程序不兼容。请修正此问题，或重新获取一份程序。
InvalidParameter=命令行中传入了无效参数：%n%n%1
SetupAlreadyRunning=安装程序已经在运行。
WindowsVersionNotSupported=本程序不支持您当前使用的 Windows 版本。
NotOnThisPlatform=本程序无法在 %1 上运行。
OnlyOnThisPlatform=本程序必须在 %1 上运行。
OnlyOnTheseArchitectures=本程序只能安装在支持以下处理器架构的 Windows 上：%n%n%1
WinVersionTooLowError=本程序需要 %1 版本 %2 或更高。
WinVersionTooHighError=本程序无法安装在 %1 版本 %2 或更高版本上。
AdminPrivilegesRequired=安装本程序需要以管理员身份登录。
SetupAppRunningError=安装程序检测到 %1 正在运行。%n%n请先关闭它的所有窗口，然后点击「确定」继续，或点击「取消」退出。
UninstallAppRunningError=卸载程序检测到 %1 正在运行。%n%n请先关闭它的所有窗口，然后点击「确定」继续，或点击「取消」退出。

; *** 安装模式选择
PrivilegesRequiredOverrideTitle=选择安装方式
PrivilegesRequiredOverrideInstruction=请选择安装方式
PrivilegesRequiredOverrideText1=%1 可以安装给所有用户（需要管理员权限），也可以只安装给您自己。
PrivilegesRequiredOverrideText2=%1 可以只安装给您自己，也可以安装给所有用户（需要管理员权限）。
PrivilegesRequiredOverrideAllUsers=为所有用户安装(&A)
PrivilegesRequiredOverrideAllUsersRecommended=为所有用户安装(&A)（推荐）
PrivilegesRequiredOverrideCurrentUser=仅为我安装(&M)
PrivilegesRequiredOverrideCurrentUserRecommended=仅为我安装(&M)（推荐）

; *** 错误
ErrorCreatingDir=安装程序无法创建目录「%1」
ErrorTooManyFilesInDir=无法在目录「%1」中创建文件，因为该目录中的文件过多

; *** 通用提示
ExitSetupTitle=退出安装
ExitSetupMessage=安装尚未完成。如果现在退出，程序将不会被安装。%n%n您可以稍后再次运行安装程序来完成安装。%n%n确定要退出吗？
AboutSetupMenuItem=关于安装程序(&A)...
AboutSetupTitle=关于安装程序
AboutSetupMessage=%1 版本 %2%n%3%n%n%1 主页：%n%4

; *** 按钮
ButtonBack=< 上一步(&B)
ButtonNext=下一步(&N) >
ButtonInstall=安装(&I)
ButtonOK=确定
ButtonCancel=取消
ButtonYes=是(&Y)
ButtonYesToAll=全部是(&A)
ButtonNo=否(&N)
ButtonNoToAll=全部否(&O)
ButtonFinish=完成(&F)
ButtonBrowse=浏览(&B)...
ButtonWizardBrowse=浏览(&R)...
ButtonNewFolder=新建文件夹(&M)

; *** 选择语言
SelectLanguageTitle=选择安装语言
SelectLanguageLabel=请选择安装过程中使用的语言。

; *** 向导通用文本
ClickNext=点击「下一步」继续，或点击「取消」退出安装。
BrowseDialogTitle=浏览文件夹
BrowseDialogLabel=请在下面的列表中选择一个文件夹，然后点击「确定」。
NewFolderName=新建文件夹

; *** 欢迎页
WelcomeLabel1=欢迎使用 [name] 安装向导
WelcomeLabel2=这将在您的电脑上安装 [name/ver]。%n%n建议在继续之前关闭所有其他应用程序。

; *** 目标位置
WizardSelectDir=选择安装位置
SelectDirDesc=[name] 应该安装到哪里？
SelectDirLabel3=安装程序将把 [name] 安装到以下文件夹。
SelectDirBrowseLabel=要继续，请点击「下一步」。如果您想选择其他文件夹，请点击「浏览」。
DiskSpaceGBLabel=至少需要 [gb] GB 可用磁盘空间。
DiskSpaceMBLabel=至少需要 [mb] MB 可用磁盘空间。
CannotInstallToNetworkDrive=安装程序无法安装到网络驱动器。
CannotInstallToUNCPath=安装程序无法安装到 UNC 路径。
InvalidPath=您必须输入带盘符的完整路径，例如：%n%nC:\APP%n%n或以下形式的 UNC 路径：%n%n\\server\share
InvalidDrive=您选择的驱动器或 UNC 共享不存在或无法访问，请重新选择。
DiskSpaceWarningTitle=磁盘空间不足
DiskSpaceWarning=安装至少需要 %1 KB 可用空间，但所选驱动器只有 %2 KB 可用。%n%n是否仍要继续？
DirNameTooLong=文件夹名或路径过长。
InvalidDirName=文件夹名无效。
BadDirName32=文件夹名不能包含以下字符：%n%n%1
DirExistsTitle=文件夹已存在
DirExists=文件夹：%n%n%1%n%n已经存在。是否仍要安装到该文件夹？
DirDoesntExistTitle=文件夹不存在
DirDoesntExist=文件夹：%n%n%1%n%n不存在。是否要创建该文件夹？

; *** 附加任务
WizardSelectTasks=选择附加任务
SelectTasksDesc=需要执行哪些附加任务？
SelectTasksLabel2=请选择在安装 [name] 时希望安装程序执行的附加任务，然后点击「下一步」。

; *** 开始菜单文件夹
WizardSelectProgramGroup=选择开始菜单文件夹
SelectStartMenuFolderDesc=安装程序应该把程序的快捷方式放在哪里？
SelectStartMenuFolderLabel3=安装程序将在以下开始菜单文件夹中创建程序的快捷方式。
SelectStartMenuFolderBrowseLabel=要继续，请点击「下一步」。如果您想选择其他文件夹，请点击「浏览」。
MustEnterGroupName=您必须输入文件夹名。
GroupNameTooLong=文件夹名或路径过长。
InvalidGroupName=文件夹名无效。
BadGroupName=文件夹名不能包含以下字符：%n%n%1
NoProgramGroupCheck2=不创建开始菜单文件夹(&D)

; *** 准备安装
WizardReady=准备安装
ReadyLabel1=安装程序已准备好，即将在您的电脑上安装 [name]。
ReadyLabel2a=点击「安装」开始安装；如果您想查看或修改设置，请点击「上一步」。
ReadyLabel2b=点击「安装」开始安装。
ReadyMemoDir=安装位置：
ReadyMemoType=安装类型：
ReadyMemoGroup=开始菜单文件夹：
ReadyMemoTasks=附加任务：

; *** 安装前准备
WizardPreparing=正在准备安装
PreparingDesc=安装程序正在准备在您的电脑上安装 [name]。
PreviousInstallNotCompleted=之前程序的安装/卸载尚未完成。您需要重启电脑来完成那次安装。%n%n重启后请再次运行安装程序，以完成 [name] 的安装。
CannotContinue=安装程序无法继续，请点击「取消」退出。
ApplicationsFound=以下应用程序正在使用安装程序需要更新的文件。建议允许安装程序自动关闭这些应用程序。
ApplicationsFound2=以下应用程序正在使用安装程序需要更新的文件。建议允许安装程序自动关闭这些应用程序。安装完成后，安装程序会尝试重新启动这些应用程序。
CloseApplications=自动关闭这些应用程序(&A)
DontCloseApplications=不关闭这些应用程序(&D)
ErrorCloseApplications=安装程序无法自动关闭所有应用程序。建议您先关闭所有正在使用待更新文件的应用程序，然后再继续。
PrepareToInstallNeedsRestart=安装程序必须重启您的电脑。重启后请再次运行安装程序，以完成 [name] 的安装。%n%n是否现在重启？

; *** 正在安装
WizardInstalling=正在安装
InstallingLabel=请稍候，安装程序正在您的电脑上安装 [name]。

; *** 安装完成
FinishedHeadingLabel=[name] 安装完成
FinishedLabelNoIcons=安装程序已完成 [name] 的安装。
FinishedLabel=安装程序已完成 [name] 的安装。您可以通过已创建的快捷方式启动本程序。
ClickFinish=点击「完成」退出安装程序。
FinishedRestartLabel=要完成 [name] 的安装，必须重启电脑。是否现在重启？
FinishedRestartMessage=要完成 [name] 的安装，必须重启电脑。%n%n是否现在重启？
ShowReadmeCheck=是，我想查看说明文件
YesRadio=是，现在重启电脑(&Y)
NoRadio=不，我稍后自己重启(&N)
RunEntryExec=运行 %1
RunEntryShellExec=查看 %1

; *** 安装过程状态
SetupAborted=安装未完成。%n%n请修正问题后重新运行安装程序。
AbortRetryIgnoreSelectAction=请选择操作
AbortRetryIgnoreRetry=重试(&T)
AbortRetryIgnoreIgnore=忽略错误并继续(&I)
AbortRetryIgnoreCancel=取消安装
RetryCancelSelectAction=请选择操作
RetryCancelRetry=重试(&T)
RetryCancelCancel=取消
StatusClosingApplications=正在关闭应用程序...
StatusCreateDirs=正在创建目录...
StatusExtractFiles=正在解压文件...
StatusCreateIcons=正在创建快捷方式...
StatusCreateRegistryEntries=正在写入注册表...
StatusSavingUninstall=正在保存卸载信息...
StatusRunProgram=正在完成安装...
StatusRollback=正在回滚更改...

; *** 其他错误
ErrorInternal2=内部错误：%1
ErrorFunctionFailedNoCode=%1 失败
ErrorFunctionFailed=%1 失败；代码 %2
ErrorFunctionFailedWithMessage=%1 失败；代码 %2。%n%3
ErrorExecutingProgram=无法执行文件：%n%1

; *** 注册表错误
ErrorRegOpenKey=打开注册表项时出错：%n%1\%2
ErrorRegCreateKey=创建注册表项时出错：%n%1\%2
ErrorRegWriteKey=写入注册表项时出错：%n%1\%2

; *** 文件复制错误
ExistingFileReadOnly2=无法替换已有文件，因为它被标记为只读。
ExistingFileReadOnlyRetry=去掉只读属性并重试(&R)
ExistingFileReadOnlyKeepExisting=保留已有文件(&K)
ErrorReadingExistingDest=读取已有文件时出错：
FileExistsSelectAction=请选择操作
FileExists2=文件已存在。
FileExistsOverwriteExisting=覆盖已有文件(&O)
FileExistsKeepExisting=保留已有文件(&K)
FileExistsOverwriteOrKeepAll=对后续冲突都这样做(&D)
ExistingFileNewerSelectAction=请选择操作
ExistingFileNewer2=已有文件比安装程序要安装的文件更新。
ExistingFileNewerOverwriteExisting=覆盖已有文件(&O)
ExistingFileNewerKeepExisting=保留已有文件(&K)（推荐）
ExistingFileNewerOverwriteOrKeepAll=对后续冲突都这样做(&D)
ErrorChangingAttr=尝试修改已有文件属性时出错：
ErrorCreatingTemp=尝试在目标目录中创建文件时出错：
ErrorReadingSource=尝试读取源文件时出错：
ErrorCopying=尝试复制文件时出错：
ErrorReplacingExistingFile=尝试替换已有文件时出错：
ErrorRenamingTemp=尝试重命名目标目录中的文件时出错：

; *** 卸载显示名后缀
UninstallDisplayNameMark=%1 (%2)
UninstallDisplayNameMarks=%1 (%2, %3)
UninstallDisplayNameMark32Bit=32 位
UninstallDisplayNameMark64Bit=64 位
UninstallDisplayNameMarkAllUsers=所有用户
UninstallDisplayNameMarkCurrentUser=当前用户

; *** 安装后错误
ErrorOpeningReadme=尝试打开说明文件时出错。
ErrorRestartingComputer=安装程序无法重启电脑，请手动重启。

; *** 卸载程序
UninstallNotFound=文件「%1」不存在，无法卸载。
UninstallOpenError=无法打开文件「%1」，无法卸载。
UninstallUnsupportedVer=卸载日志文件「%1」的格式不被此版本卸载程序识别，无法卸载。
UninstallUnknownEntry=卸载日志中出现了未知条目（%1）。
ConfirmUninstall=确定要完全移除 %1 及其所有组件吗？
UninstallOnlyOnWin64=此安装只能在 64 位 Windows 上卸载。
OnlyAdminCanUninstall=此安装只能由具有管理员权限的用户卸载。
UninstallStatusLabel=请稍候，正在从您的电脑上移除 %1。
UninstalledAll=%1 已成功从您的电脑上移除。
UninstalledMost=%1 卸载完成。%n%n部分元素无法移除，可以手动删除。
UninstalledAndNeedsRestart=要完成 %1 的卸载，必须重启电脑。%n%n是否现在重启？
UninstallDataCorrupted=「%1」文件已损坏，无法卸载。

; *** 卸载过程
WizardUninstalling=卸载状态
StatusUninstalling=正在卸载 %1...

; *** 关机阻止原因
ShutdownBlockReasonInstallingApp=正在安装 %1。
ShutdownBlockReasonUninstallingApp=正在卸载 %1。

; *** 以下是补齐条目（本程序不一定会用到，但补齐后向导不会出现英文）
HelpTextNote=
AboutSetupNote=
TranslatorNote=简体中文语言包由本地抖音项目自制
BeveledLabel=
WindowsServicePackRequired=本程序需要 %1 Service Pack %2 或更高版本。
PowerUserPrivilegesRequired=安装本程序需要以管理员或 Power Users 组成员身份登录。

; *** 密码页（本程序未启用）
WizardPassword=密码
PasswordLabel1=此安装受密码保护。
PasswordLabel3=请输入密码，然后点击「下一步」继续。密码区分大小写。
PasswordEditLabel=密码(&P)：
IncorrectPassword=您输入的密码不正确，请重试。

; *** 许可协议页（本程序未启用）
WizardLicense=许可协议
LicenseLabel=请在继续之前阅读以下重要信息。
LicenseLabel3=请阅读以下许可协议。您必须接受本协议条款才能继续安装。
LicenseAccepted=我接受本协议(&A)
LicenseNotAccepted=我不接受本协议(&D)

; *** 信息页（本程序未启用）
WizardInfoBefore=信息
InfoBeforeLabel=请在继续之前阅读以下重要信息。
InfoBeforeClickLabel=准备好继续时，请点击「下一步」。
WizardInfoAfter=信息
InfoAfterLabel=请在继续之前阅读以下重要信息。
InfoAfterClickLabel=准备好继续时，请点击「下一步」。

; *** 用户信息页（本程序未启用）
WizardUserInfo=用户信息
UserInfoDesc=请输入您的信息。
UserInfoName=用户名(&U)：
UserInfoOrg=单位(&O)：
UserInfoSerial=序列号(&S)：
UserInfoNameRequired=必须输入用户名。

; *** 组件选择页（本程序未启用）
WizardSelectComponents=选择组件
SelectComponentsDesc=需要安装哪些组件？
SelectComponentsLabel2=请选择要安装的组件；清除不想安装的组件。准备好后点击「下一步」。
FullInstallation=完全安装
CompactInstallation=精简安装
CustomInstallation=自定义安装
NoUninstallWarningTitle=组件已存在
NoUninstallWarning=安装程序检测到您的电脑上已安装以下组件：%n%n%1%n%n取消选择这些组件并不会卸载它们。%n%n是否仍要继续？
ComponentSize1=%1 KB
ComponentSize2=%1 MB
ComponentsDiskSpaceGBLabel=当前选择至少需要 [gb] GB 磁盘空间。
ComponentsDiskSpaceMBLabel=当前选择至少需要 [mb] MB 磁盘空间。
ReadyMemoUserInfo=用户信息：
ReadyMemoComponents=已选组件：

; *** 下载 / 解压页（本程序未启用）
DownloadingLabel2=正在下载文件...
ButtonStopDownload=停止下载(&S)
StopDownload=确定要停止下载吗？
ErrorDownloadAborted=下载已中止
ErrorDownloadFailed=下载失败：%1 %2
ErrorDownloadSizeFailed=获取大小失败：%1 %2
ErrorProgress=进度无效：%2 中的 %1
ErrorFileSize=文件大小无效：期望 %1，实际 %2
ExtractingLabel=正在解压文件...
ButtonStopExtraction=停止解压(&S)
StopExtraction=确定要停止解压吗？
ErrorExtractionAborted=解压已中止
ErrorExtractionFailed=解压失败：%1
ArchiveIncorrectPassword=密码不正确
ArchiveIsCorrupted=压缩包已损坏
ArchiveUnsupportedFormat=不支持该压缩包格式

; *** 换盘提示（本程序未启用）
ChangeDiskTitle=需要下一张磁盘
SelectDiskLabel2=请插入第 %1 张磁盘，然后点击「确定」。%n%n如果该磁盘上的文件在下面显示之外的文件夹中，请输入正确的路径或点击「浏览」。
PathLabel=路径(&P)：
FileNotInDir2=在「%2」中找不到文件「%1」。请插入正确的磁盘，或选择其他文件夹。
SelectDirectoryLabel=请指定下一张磁盘的位置。

; *** 安装状态（会短暂出现在进度条上）
StatusDownloadFiles=正在下载文件...
StatusCreateIniEntries=正在写入 INI 项...
StatusRegisterFiles=正在注册文件...
StatusRestartingApplications=正在重新启动应用程序...

; *** INI / 文件复制错误
ErrorIniEntry=在文件「%1」中创建 INI 项时出错。
FileAbortRetryIgnoreSkipNotRecommended=跳过此文件(&S)（不推荐）
FileAbortRetryIgnoreIgnoreNotRecommended=忽略错误并继续(&I)（不推荐）
SourceIsCorrupted=源文件已损坏
SourceDoesntExist=源文件「%1」不存在
SourceVerificationFailed=源文件校验失败：%1
VerificationSignatureDoesntExist=签名文件「%1」不存在
VerificationSignatureInvalid=签名文件「%1」无效
VerificationKeyNotFound=签名文件「%1」使用了未知密钥
VerificationFileNameIncorrect=文件名不正确
VerificationFileTagIncorrect=文件标记不正确
VerificationFileSizeIncorrect=文件大小不正确
VerificationFileHashIncorrect=文件哈希不正确
ErrorDownloading=尝试下载文件时出错：
ErrorExtracting=尝试解压压缩包时出错：
ErrorRestartReplace=RestartReplace 失败：
ErrorRegisterServer=无法注册 DLL/OCX：%1
ErrorRegSvr32Failed=RegSvr32 失败，退出代码 %1
ErrorRegisterTypeLib=无法注册类型库：%1

; *** 卸载时的共享文件提示
ConfirmDeleteSharedFileTitle=移除共享文件？
ConfirmDeleteSharedFile2=系统显示以下共享文件已不再被任何程序使用。是否让卸载程序移除这个共享文件？%n%n如果有程序仍在使用该文件而它被删除了，那些程序可能无法正常工作。如果不确定，请选择「否」。把文件留在系统上不会造成任何损害。
SharedFileNameLabel=文件名：
SharedFileLocationLabel=位置：

[CustomMessages]

NameAndVersion=%1 版本 %2
AdditionalIcons=附加快捷方式：
CreateDesktopIcon=创建桌面快捷方式(&D)
CreateQuickLaunchIcon=创建快速启动栏快捷方式(&Q)
ProgramOnTheWeb=%1 官方网站
UninstallProgram=卸载 %1
LaunchProgram=启动 %1
AddonHostProgramNotFound=在您选择的文件夹中找不到 %1。%n%n是否仍要继续？
