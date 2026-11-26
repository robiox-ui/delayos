@echo off
rem DelayOS - Windows link: one-time setup. Asks for administrator rights, then runs install.ps1
rem from the same folder. ASCII only and no labels on purpose (LF line endings, any code page).
fltmc >nul 2>&1 || (powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs" & exit /b)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
