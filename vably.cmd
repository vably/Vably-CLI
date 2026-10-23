@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0vably.ps1" %*
exit /b %ERRORLEVEL%

