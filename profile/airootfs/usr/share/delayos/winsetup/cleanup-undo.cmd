@echo off
rem DelayOS hidden Windows: puts back what the "gaming cleanup" changed at install time
rem (registry values, services, scheduled tasks). ASCII only. Asks for administrator rights.
net session >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0cleanup.ps1" -Phase Undo
echo.
pause
