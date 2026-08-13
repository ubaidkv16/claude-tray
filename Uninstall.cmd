@echo off
REM Double-click me to stop Claude Tray and remove it from startup.
REM Nothing is installed system-wide, so deleting this folder afterwards
REM removes every trace.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall
echo.
pause
