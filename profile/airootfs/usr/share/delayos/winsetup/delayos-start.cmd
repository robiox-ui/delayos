@echo off
rem DelayOS hidden Windows: runs in WinPE instead of Windows Setup (winpeshl.ini; fallback: the
rem windowsPE pass of X:\autounattend.xml). Finds the DelayOS staging partition by its marker file
rem and runs \delayos\install.cmd from it. ASCII only. The PC restarts when this script ends.
if exist X:\delayos-ran.flag exit /b 0
echo 1 > X:\delayos-ran.flag
wpeinit
set DSTG=
for %%d in (C D E F G H I J K L M N O P Q R T U V W Y Z) do if not defined DSTG if exist %%d:\delayos\staging.tag if exist %%d:\delayos\install.cmd set DSTG=%%d
if not defined DSTG goto nostg
call %DSTG%:\delayos\install.cmd %DSTG%
goto done
:nostg
echo DelayOS: the Windows setup files were not found. Restarting to DelayOS...
ping -n 15 127.0.0.1 >nul
:done
wpeutil reboot
