@echo off
setlocal
set "GODOT=K:\Godot_v4.7.2-stable_win64.exe"
set "PROJECT=%~dp0."

if not exist "%GODOT%" (
	echo Godot exe not found: %GODOT%
	exit /b 1
)

if /i "%~1"=="-e" (
	"%GODOT%" --path "%PROJECT%" -e
	goto :eof
)
if /i "%~1"=="-c" (
	"%GODOT%" --path "%PROJECT%" --headless --quit-after 120
	goto :eof
)

"%GODOT%" --path "%PROJECT%"
