@echo off
REM Double-click me to make Claude Tray launch automatically every login.
REM Run "Uninstall.cmd" to undo it.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
