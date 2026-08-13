@echo off
REM Double-click me to start Claude Tray. Windows opens .ps1 files in Notepad
REM instead of running them, so this .cmd is the friendly entry point.
REM %~dp0 = this file's folder, so the repo can live anywhere.
start "" powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0claude-tray.ps1"
