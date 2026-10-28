@echo off
rem ---------------------------------------------------------------
rem  打包成可直接分发的绿色版目录 dist\LocalDouyin
rem  用法：双击本文件，或在项目根目录执行 tool\package.bat
rem ---------------------------------------------------------------
setlocal enabledelayedexpansion
cd /d "%~dp0.."

echo [1/3] 编译 release ...
call flutter build windows --release
if errorlevel 1 goto :fail

set OUT=dist\LocalDouyin
echo [2/3] 复制产物到 %OUT% ...
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
xcopy /E /I /Y /Q "build\windows\x64\runner\Release" "%OUT%" >nul
if errorlevel 1 goto :fail

echo [3/3] 内置 ffmpeg ...
set FF=
for /f "delims=" %%i in ('where ffmpeg.exe 2^>nul') do (
  if "!FF!"=="" set FF=%%i
)
if "!FF!"=="" (
  if exist "vendor\ffmpeg\ffmpeg.exe" set FF=%CD%\vendor\ffmpeg\ffmpeg.exe
)
if "!FF!"=="" (
  echo    警告：没找到 ffmpeg.exe，跳过。软件仍可播放，但没有缩略图。
) else (
  mkdir "%OUT%\ffmpeg" 2>nul
  copy /Y "!FF!" "%OUT%\ffmpeg\ffmpeg.exe" >nul
  echo    已内置：!FF!
)

echo.
echo 完成：%CD%\%OUT%
echo 直接把 LocalDouyin 整个文件夹拷走就能用，无需安装。
goto :eof

:fail
echo.
echo 打包失败，请看上面的报错。
exit /b 1
