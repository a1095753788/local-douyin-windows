@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

rem ============================================================
rem  一键打包 Windows 安装包
rem
rem  前置条件：
rem    1. 已经跑过 tool\package.bat，dist\LocalDouyin\ 存在
rem    2. 装了 Inno Setup 6（https://jrsoftware.org/isdl.php）
rem
rem  产出：dist\LocalDouyin-Setup-1.0.0.exe
rem ============================================================

cd /d "%~dp0.."

if not exist "dist\LocalDouyin\local_douyin_win.exe" (
    echo [错误] 找不到 dist\LocalDouyin\local_douyin_win.exe
    echo        请先运行 tool\package.bat 生成绿色版
    pause
    exit /b 1
)

rem --- 找 ISCC.exe ---
set "ISCC="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if exist "C:\Program Files\Inno Setup 6\ISCC.exe"       set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if exist "%USERPROFILE%\Tools\InnoSetup6\ISCC.exe"       set "ISCC=%USERPROFILE%\Tools\InnoSetup6\ISCC.exe"

if "%ISCC%"=="" (
    where iscc >nul 2>&1
    if !errorlevel! equ 0 (
        set "ISCC=iscc"
    ) else (
        echo [错误] 找不到 Inno Setup 的 ISCC.exe
        echo        请从 https://jrsoftware.org/isdl.php 安装 Inno Setup 6
        pause
        exit /b 1
    )
)

echo 使用编译器: %ISCC%
echo 开始编译安装包（约 25 秒）...
echo.

"%ISCC%" "tool\installer.iss"

if errorlevel 1 (
    echo.
    echo [失败] 编译出错，请检查上面的输出
    pause
    exit /b 1
)

echo.
echo [完成] dist\LocalDouyin-Setup-1.0.0.exe
pause
