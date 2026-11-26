# DelayOS <-> Windows link: one-time setup, run as administrator through DelayOS-Windows-*.cmd.
# Keep this file ASCII only (Windows PowerShell 5.1 reads BOM-less scripts in the ANSI code page);
# Korean text is in messages.ko.json. Documentation: docs/windows-switch.md in DelayOS.
#
# Installs %ProgramData%\DelayOS\winboot\agent.ps1 and three scheduled tasks for the current user:
#   \DelayOS\WinBoot-Agent   at logon and on resume, elevated: launch request -> game -> back to DelayOS
#   \DelayOS\WinBoot-Launch  on demand, not elevated: starts the game
#   \DelayOS\WinBoot-Return  on demand, elevated: "back to DelayOS" (Start menu shortcut)
# Nothing here stores a password. Run again to update or remove.
param([switch]$Uninstall)

$ErrorActionPreference = 'Continue'
$Version = '1.0'
$Src = $PSScriptRoot
$Base = Join-Path $env:ProgramData 'DelayOS\winboot'
$TaskPath = '\DelayOS\'
$Tasks = 'WinBoot-Agent', 'WinBoot-Launch', 'WinBoot-Return'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$M = New-Object psobject
try { $M = [IO.File]::ReadAllText((Join-Path $Src 'messages.ko.json'), $Utf8) | ConvertFrom-Json } catch {}

function T([string]$key) {
    $v = $M.$key
    if ($v) { return [string]$v }
    return $key
}

function Say([string]$key, $a0 = $null) {
    $t = T $key
    if ($null -ne $a0) { $t = $t -f $a0 }
    Write-Host $t
}

function Ask([string]$key) {
    Write-Host ''
    Write-Host (T $key)
    $a = Read-Host (T 'i_yes_no')
    return ($a -match '^\s*[yY]')
}

function Invoke-Quiet([string]$cmdline) {
    & cmd.exe /c "$cmdline >nul 2>&1"
    return $LASTEXITCODE
}

function Invoke-Agent([string]$mode) {
    return (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Base 'agent.ps1') -Mode $mode)
}

function Get-ShortcutPath {
    return (Join-Path $env:ProgramData ('Microsoft\Windows\Start Menu\Programs\' + (T 'shortcut_name') + '.lnk'))
}

function New-TaskXml([string]$mode, [bool]$elevated, [bool]$triggers, [string]$user) {
    $e = { param($s) [System.Security.SecurityElement]::Escape([string]$s) }
    $arguments = '--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}" -Mode {1}' -f (Join-Path $Base 'agent.ps1'), $mode
    $query = "<QueryList><Query Id=`"0`" Path=`"System`"><Select Path=`"System`">*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and (EventID=1)]]</Select></Query></QueryList>"
    $trig = '<Triggers />'
    if ($triggers) {
        $trig = '<Triggers><LogonTrigger><Enabled>true</Enabled><UserId>' + (& $e $user) + '</UserId></LogonTrigger>' +
                '<EventTrigger><Enabled>true</Enabled><Subscription>' + (& $e $query) + '</Subscription></EventTrigger></Triggers>'
    }
    $level = 'LeastPrivilege'
    if ($elevated) { $level = 'HighestAvailable' }
    return @(
        '<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">'
        '<RegistrationInfo><Description>DelayOS - Windows link (' + $mode + '). Remove with DelayOS-Windows setup.</Description></RegistrationInfo>'
        $trig
        '<Principals><Principal id="Author"><UserId>' + (& $e $user) + '</UserId><LogonType>InteractiveToken</LogonType><RunLevel>' + $level + '</RunLevel></Principal></Principals>'
        '<Settings>'
        '<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>'
        '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>'
        '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>'
        '<AllowHardTerminate>true</AllowHardTerminate>'
        '<StartWhenAvailable>false</StartWhenAvailable>'
        '<RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>'
        '<IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd><RestartOnIdle>false</RestartOnIdle></IdleSettings>'
        '<AllowStartOnDemand>true</AllowStartOnDemand>'
        '<Enabled>true</Enabled>'
        '<Hidden>false</Hidden>'
        '<RunOnlyIfIdle>false</RunOnlyIfIdle>'
        '<WakeToRun>false</WakeToRun>'
        '<ExecutionTimeLimit>PT0S</ExecutionTimeLimit>'
        '<Priority>4</Priority>'
        '</Settings>'
        '<Actions Context="Author"><Exec><Command>conhost.exe</Command><Arguments>' + (& $e $arguments) + '</Arguments></Exec></Actions>'
        '</Task>'
    ) -join "`n"
}

function Remove-Link {
    foreach ($t in $Tasks) {
        try { Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $t -Confirm:$false -ErrorAction Stop } catch {}
    }
    try { if (Test-Path -LiteralPath (Get-ShortcutPath)) { Remove-Item -LiteralPath (Get-ShortcutPath) -Force } } catch {}
    if (Test-Path -LiteralPath (Join-Path $Base 'agent.ps1')) {
        try { [void](Invoke-Agent 'Cleanup') } catch {}
    }
    $cfg = $null
    try { $cfg = [IO.File]::ReadAllText((Join-Path $Base 'config.json'), $Utf8) | ConvertFrom-Json } catch {}
    if ($cfg -and $cfg.bootux_set) { [void](Invoke-Quiet 'bcdedit /deletevalue {current} bootuxdisabled') }
    try { if (Test-Path -LiteralPath $Base) { Remove-Item -LiteralPath $Base -Recurse -Force } } catch {}
}

# ---- start -----------------------------------------------------------------------------------------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
try { $Host.UI.RawUI.WindowTitle = T 'i_title' } catch {}
Write-Host ''
Say 'i_title'
Write-Host '----------------------------------------------------------------'
if (-not $isAdmin) { Say 'i_need_admin'; exit 1 }

$installed = Test-Path -LiteralPath (Join-Path $Base 'agent.ps1')
if ($Uninstall) { Remove-Link; Say 'i_uninstalled'; exit 0 }
if ($installed) {
    Say 'i_already'
    $a = Read-Host '>'
    if ($a -eq '2') { Remove-Link; Say 'i_uninstalled'; exit 0 }
    if ($a -ne '1') { exit 0 }
} else {
    Say 'i_intro'
    Write-Host ''
    [void](Read-Host (T 'i_continue'))
}

# 1. files (administrators write, users read)
Say 'i_copy'
[void][IO.Directory]::CreateDirectory($Base)
foreach ($f in 'agent.ps1', 'install.ps1', 'messages.ko.json') {
    $from = Join-Path $Src $f
    $to = Join-Path $Base $f
    if ($from -ne $to) { Copy-Item -LiteralPath $from -Destination $to -Force }
}
[void](Invoke-Quiet ('icacls "{0}" /inheritance:r /grant:r *S-1-5-32-544:(OI)(CI)F *S-1-5-18:(OI)(CI)F *S-1-5-32-545:(OI)(CI)RX' -f $Base))

$cfgFile = Join-Path $Base 'config.json'
$cfg = $null
try { $cfg = [IO.File]::ReadAllText($cfgFile, $Utf8) | ConvertFrom-Json } catch {}
if (-not $cfg) { $cfg = New-Object psobject }
$cfg | Add-Member -NotePropertyName version -NotePropertyValue $Version -Force
$cfg | Add-Member -NotePropertyName user -NotePropertyValue $id.Name -Force
[IO.File]::WriteAllText($cfgFile, ($cfg | ConvertTo-Json -Depth 6), $Utf8)

# 2. scheduled tasks
Say 'i_tasks'
$ok = $true
try {
    Register-ScheduledTask -TaskPath $TaskPath -TaskName 'WinBoot-Agent' -Xml (New-TaskXml 'Agent' $true $true $id.Name) -Force -ErrorAction Stop | Out-Null
    Register-ScheduledTask -TaskPath $TaskPath -TaskName 'WinBoot-Launch' -Xml (New-TaskXml 'Launch' $false $false $id.Name) -Force -ErrorAction Stop | Out-Null
    Register-ScheduledTask -TaskPath $TaskPath -TaskName 'WinBoot-Return' -Xml (New-TaskXml 'Return' $true $false $id.Name) -Force -ErrorAction Stop | Out-Null
} catch {
    $ok = $false
    Say 'i_tasks_failed' $_.Exception.Message
}
if (-not $ok) { exit 1 }

# 3. "back to DelayOS" shortcut in the Start menu (runs the elevated task, no UAC prompt)
try {
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut((Get-ShortcutPath))
    $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\schtasks.exe'
    $lnk.Arguments = '/run /tn "\DelayOS\WinBoot-Return"'
    $lnk.WindowStyle = 7
    $lnk.IconLocation = (Join-Path $env:SystemRoot 'System32\shell32.dll') + ',238'
    $lnk.Description = T 'shortcut_name'
    $lnk.Save()
    Say 'i_shortcut' (T 'shortcut_name')
} catch {}

# 4. the firmware boot entry of DelayOS (for the one-time boot back)
$guid = $null
try { $guid = Invoke-Agent 'Probe' | Select-Object -First 1 } catch {}
if ($guid) { Say 'i_entry_ok' $guid } else { Say 'i_entry_missing' }

# 5. optional settings, each with consent
$bitlocker = $false
try { $bitlocker = ((Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop).ProtectionStatus -eq 'On') } catch {}
if ($bitlocker) { Say 'i_bitlocker' }
elseif (-not $cfg.bootux_set) {
    if (Ask 'i_bootux_q') {
        if ((Invoke-Quiet 'bcdedit /set {current} bootuxdisabled on') -eq 0) {
            $cfg = [IO.File]::ReadAllText($cfgFile, $Utf8) | ConvertFrom-Json
            $cfg | Add-Member -NotePropertyName bootux_set -NotePropertyValue $true -Force
            [IO.File]::WriteAllText($cfgFile, ($cfg | ConvertTo-Json -Depth 6), $Utf8)
        }
    }
}

$powerKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
$fast = 0
try { $fast = [int](Get-ItemProperty -LiteralPath $powerKey -ErrorAction Stop).HiberbootEnabled } catch {}
if ($fast -ne 0) {
    if (Ask 'i_fast_q') { try { Set-ItemProperty -LiteralPath $powerKey -Name HiberbootEnabled -Value 0 -Type DWord -ErrorAction Stop } catch {} }
}

$auto = $false
try { $auto = ((Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction Stop).AutoAdminLogon -eq '1') } catch {}
if ($auto) { Say 'i_autologon_on' }
else {
    Write-Host ''
    Say 'i_autologon_info'
    if (Ask 'i_autologon_q') {
        $pl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'
        $hidden = $false
        try { $hidden = ([int](Get-ItemProperty -LiteralPath $pl -ErrorAction Stop).DevicePasswordLessBuildVersion -ne 0) } catch {}
        if ($hidden) {
            if (Ask 'i_autologon_checkbox_q') { try { Set-ItemProperty -LiteralPath $pl -Name DevicePasswordLessBuildVersion -Value 0 -Type DWord -ErrorAction Stop } catch {} }
        }
        try { Start-Process -FilePath netplwiz.exe } catch {}
    }
}

# 6. first inventory for DelayOS (also tells DelayOS that the helper is installed)
Say 'i_inventory'
try { [void](Invoke-Agent 'Inventory') } catch {}

Write-Host ''
Say 'i_done'
