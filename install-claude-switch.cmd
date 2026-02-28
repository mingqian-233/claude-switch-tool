@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-claude-switch.ps1" %*
endlocal
