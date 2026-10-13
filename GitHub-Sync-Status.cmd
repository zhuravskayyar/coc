@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\github_sync.ps1" -Action Status
pause
