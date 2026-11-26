@echo off
rem DelayOS hidden Windows: runs once in the "specialize" pass (as SYSTEM, before the first logon).
rem ASCII only. Every setting is a documented Windows registry value.
set LOG=C:\ProgramData\DelayOS\winsetup\specialize.log
echo %date% %time% specialize > %LOG%
rem No forced Microsoft account / network page in the first-run experience
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f >> %LOG% 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /t REG_DWORD /d 1 /f >> %LOG% 2>&1
rem VBS + memory integrity (HVCI): asked for by the user; some anti-cheats require or recommend it
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 1 /f >> %LOG% 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v RequirePlatformSecurityFeatures /t REG_DWORD /d 1 /f >> %LOG% 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 1 /f >> %LOG% 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v WasEnabledBy /t REG_DWORD /d 2 /f >> %LOG% 2>&1
rem BitLocker / automatic device encryption stays OFF (DelayOS shares the EFI partition and the firmware)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\BitLocker" /v PreventDeviceEncryption /t REG_DWORD /d 1 /f >> %LOG% 2>&1
rem Fast Startup off: every start is a real boot (dual boot, shared EFI partition)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >> %LOG% 2>&1
rem The restart that follows this pass must come straight back into Windows (DelayOS is first in the
rem firmware boot order and would otherwise have to pass the PC on once more)
bcdedit /set {fwbootmgr} bootsequence {bootmgr} >> %LOG% 2>&1
rem DelayOS keeps the hardware clock in UTC: make Windows do the same, or the clocks differ by 9 hours
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f >> %LOG% 2>&1
rem Privacy: optional diagnostics, advertising id, tailored experiences and suggested apps off
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >> %LOG% 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f >> %LOG% 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >> %LOG% 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f >> %LOG% 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f >> %LOG% 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d Deny /f >> %LOG% 2>&1
rem Gaming cleanup of an official image (docs/windows-switch.md); only when DelayOS staged "cleanup.on"
if exist C:\ProgramData\DelayOS\winsetup\cleanup.on powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\DelayOS\winsetup\cleanup.ps1 -Phase Machine >> %LOG% 2>&1
echo %date% %time% specialize end >> %LOG%
exit /b 0
