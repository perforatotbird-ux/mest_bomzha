@echo off
setlocal
if not defined GODOT set "GODOT=K:\Godot_v4.7.2-stable_win64.exe"
set "PROJECT=%~dp0."

if not exist "%GODOT%" (
    echo Godot executable not found: "%GODOT%"
    echo Set GODOT to the full path to your Godot 4.7.2 executable.
    pause
    exit /b 1
)

rem A fresh ZIP/checkout contains source PNGs, not Godot's generated .ctex cache.
rem Running the game without this step leaves the player and its script unloaded.
echo [1/3] Importing project assets. The first launch may take longer...
"%GODOT%" --headless --editor --path "%PROJECT%" --import
if errorlevel 1 goto failed

echo [2/3] Checking that the player, animation frames and level load...
"%GODOT%" --headless --path "%PROJECT%" --fixed-fps 60 --script res://tests/startup_smoke_runner.gd
if errorlevel 1 goto failed

if /i "%~1"=="-c" (
    echo Startup check passed.
    exit /b 0
)
if /i "%~1"=="-e" (
    "%GODOT%" --path "%PROJECT%" --editor
    exit /b %errorlevel%
)

echo [3/3] Starting game...
"%GODOT%" --path "%PROJECT%"
exit /b %errorlevel%

:failed
echo.
echo Startup stopped: import or resource validation failed.
echo See the errors above. The game was not started with a missing player.
pause
exit /b 1
