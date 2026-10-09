@echo off
rem xv - shim para cmd.exe / PowerShell. Chama xv.ps1 sem depender da ExecutionPolicy.
rem Instalado: %LOCALAPPDATA%\xv\bin\xv.cmd -> %LOCALAPPDATA%\xv\xv.ps1
setlocal
set "XV_PS1=%~dp0xv.ps1"
if not exist "%XV_PS1%" set "XV_PS1=%~dp0..\xv.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%XV_PS1%" %*
exit /b %ERRORLEVEL%
