@echo off
setlocal
set "GODOT_BIN="
if not "%~1"=="" set "GODOT_BIN=%~1"
if defined GODOT_BIN goto launch
if exist "%~dp0Godot.exe" set "GODOT_BIN=%~dp0Godot.exe"
if defined GODOT_BIN goto launch
if exist "%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" set "GODOT_BIN=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if defined GODOT_BIN goto launch
for /f "delims=" %%G in ('where godot.exe 2^>nul') do set "GODOT_BIN=%%G"
if defined GODOT_BIN goto launch
echo Godot 4 was not found.
echo Drag your Godot executable onto this PLAY.cmd, or import project.godot in Godot and press F5.
pause
exit /b 1
:launch
if not exist "%GODOT_BIN%" exit /b 1
echo Preparing game assets...
start "" /wait "%GODOT_BIN%" --headless --editor --path "%~dp0." --import --quit
start "Debug Rush" "%GODOT_BIN%" --path "%~dp0."
exit /b 0
