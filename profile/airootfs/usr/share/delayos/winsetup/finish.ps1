# DelayOS hidden Windows: last step, runs once at the first (automatic) logon of the "DelayOS"
# account (FirstLogonCommands, elevated). Keep this file ASCII only.
#   1. permanent password-less auto-logon, hibernation off
#   2. activation, legitimate ways only: a key typed in the DelayOS installer, else the OEM key stored
#      in the PC firmware (ACPI MSDM). Without either, Windows activates by itself once it is online
#      if this PC has a digital license for this edition; otherwise it stays unactivated.
#   3. install the DelayOS <-> Windows helper without questions (install.ps1 -Unattended)
#   3b. gaming cleanup, user part (cleanup.ps1 -Phase User), only when DelayOS staged "cleanup.on"
#   4. tell DelayOS the result (done.json on the EFI system partition), remove the "pending" marker
#   5. restart into DelayOS
# Every step is independent and guarded: a custom Windows image may lack a component used here
# (licensing WMI classes, the ScheduledTasks module, Device Guard, ...). A missing piece is logged,
# listed in done.json ("skipped") and skipped; only a missing helper makes the result "not ok".
$ErrorActionPreference = 'Continue'
$Base = Join-Path $env:ProgramData 'DelayOS\winsetup'
$Log = Join-Path $Base 'finish.log'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-Log([string]$msg) {
    try { [IO.File]::AppendAllText($Log, ('{0} {1}' -f (Get-Date -Format s), $msg) + "`r`n", $Utf8) } catch {}
}

function Invoke-Quiet([string]$cmdline) {
    & cmd.exe /c "$cmdline >nul 2>&1"
    return $LASTEXITCODE
}

function Install-Key([string]$key, [string]$source) {
    # slmgr /ipk; the key itself is never written to the log
    $rc = Invoke-Quiet ('cscript.exe //B //Nologo "{0}" /ipk {1}' -f (Join-Path $env:SystemRoot 'System32\slmgr.vbs'), $key)
    Write-Log "product key from $source : slmgr /ipk rc=$rc"
    return ($rc -eq 0)
}

Write-Log 'finish.ps1 start'
$result = [ordered]@{ ok = $true; version = 1; key_source = 'none'; key_installed = $false; activated = $false
                      oem_key = $false; oem_description = ''; helper = $false; hvci = $false; edition = ''; build = ''
                      cleanup = $false; cleanup_apps = 0; skipped = @() }

function Skip([string]$what, $err) {
    $result.skipped += $what
    Write-Log "$what skipped: $err"
}

# CIM first, classic WMI when the CIM cmdlets or WinRM pieces are missing in the image
function Get-Wmi([string]$class, [string]$filter = '', [string]$namespace = 'root\cimv2') {
    try {
        if ($filter) { return Get-CimInstance -Namespace $namespace -ClassName $class -Filter $filter -ErrorAction Stop }
        return Get-CimInstance -Namespace $namespace -ClassName $class -ErrorAction Stop
    } catch {
        if ($filter) { return Get-WmiObject -Namespace $namespace -Class $class -Filter $filter -ErrorAction Stop }
        return Get-WmiObject -Namespace $namespace -Class $class -ErrorAction Stop
    }
}

# ---- 1. logon and power ------------------------------------------------------------------------
try {
    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty -LiteralPath $wl -Name AutoAdminLogon -Value '1' -Type String
    Set-ItemProperty -LiteralPath $wl -Name DefaultUserName -Value 'DelayOS' -Type String
    Set-ItemProperty -LiteralPath $wl -Name DefaultPassword -Value '' -Type String
    Remove-ItemProperty -LiteralPath $wl -Name AutoLogonCount -ErrorAction SilentlyContinue
} catch { Write-Log "autologon: $_" }
[void](Invoke-Quiet 'powercfg.exe /hibernate off')
[void](Invoke-Quiet 'reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f')

# ---- 2. activation -----------------------------------------------------------------------------
try {
    $svc = Get-Wmi 'SoftwareLicensingService'
    $oem = [string]$svc.OA3xOriginalProductKey
    $result.oem_key = [bool]$oem
    $result.oem_description = [string]$svc.OA3xOriginalProductKeyDescription
    $keyFile = Join-Path $Base 'productkey.txt'
    $userKey = ''
    if (Test-Path -LiteralPath $keyFile) {
        $userKey = ([IO.File]::ReadAllText($keyFile)).Trim()
        Remove-Item -LiteralPath $keyFile -Force
    }
    if ($userKey -match '^[A-Za-z0-9]{5}(-[A-Za-z0-9]{5}){4}$') {
        $result.key_source = 'user'
        $result.key_installed = Install-Key $userKey 'the DelayOS installer'
    } elseif ($oem) {
        $result.key_source = 'firmware'
        $result.key_installed = Install-Key $oem 'the PC firmware (OEM)'
    }
    # online activation; fails quietly without a network connection (Windows retries on its own)
    [void](Invoke-Quiet ('cscript.exe //B //Nologo "{0}" /ato' -f (Join-Path $env:SystemRoot 'System32\slmgr.vbs')))
    $lic = Get-Wmi 'SoftwareLicensingProduct' "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL"
    $result.activated = [bool]($lic | Where-Object { $_.LicenseStatus -eq 1 })
} catch { Skip 'activation' $_ }
try {
    $cv = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $result.edition = [string]$cv.EditionID
    $result.build = ('{0}.{1}' -f $cv.CurrentBuild, $cv.UBR)
} catch {}
try {
    $dg = Get-Wmi 'Win32_DeviceGuard' '' 'root\Microsoft\Windows\DeviceGuard'
    $result.hvci = [bool]($dg.SecurityServicesConfigured -contains 2)
} catch { Skip 'deviceguard' $_ }
Write-Log ("activation: source={0} installed={1} activated={2} oem='{3}'" -f $result.key_source, $result.key_installed, $result.activated, $result.oem_description)

# ---- 3. DelayOS <-> Windows helper -------------------------------------------------------------
try {
    $inst = Join-Path $Base 'helper\install.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $inst -Unattended *>> (Join-Path $Base 'helper-install.log')
    # schtasks.exe, not Get-ScheduledTask: also works without the ScheduledTasks PowerShell module
    $result.helper = (Test-Path -LiteralPath (Join-Path $env:ProgramData 'DelayOS\winboot\agent.ps1')) -and
                     ((Invoke-Quiet 'schtasks.exe /Query /TN "\DelayOS\WinBoot-Agent"') -eq 0)
} catch { Write-Log "helper: $_" }
Write-Log "helper installed: $($result.helper)"
if (-not $result.helper) { $result.ok = $false }

# ---- 3b. gaming cleanup (official image; DelayOS does not stage "cleanup.on" for a custom image) ----
if (Test-Path -LiteralPath (Join-Path $Base 'cleanup.on')) {
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Base 'cleanup.ps1') -Phase User *>> (Join-Path $Base 'cleanup-run.log')
        $cs = [IO.File]::ReadAllText((Join-Path $Base 'cleanup-state.json'), $Utf8) | ConvertFrom-Json
        $result.cleanup = (@($cs.phases) -contains 'User')
        $result.cleanup_apps = @($cs.appx).Count
    } catch { Skip 'cleanup' $_ }
    Write-Log "gaming cleanup: applied=$($result.cleanup) apps removed=$($result.cleanup_apps)"
} else { Write-Log 'gaming cleanup: not requested' }

# ---- 4. report to DelayOS on the EFI system partition ------------------------------------------
$guid = $null
try { $guid = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $env:ProgramData 'DelayOS\winboot\agent.ps1') -Mode Probe | Select-Object -First 1 } catch {}
Write-Log "DelayOS firmware entry: $guid"
$esp = $null
foreach ($l in 'S', 'T', 'U', 'V', 'W', 'Y', 'Z') {
    if (-not (Test-Path -LiteralPath "${l}:\")) {
        if ((Invoke-Quiet "mountvol ${l}: /S") -eq 0) { $esp = "${l}:" }
        break
    }
}
if ($esp -and (Test-Path -LiteralPath "$esp\EFI\DelayOS\winsetup")) {
    $d = "$esp\EFI\DelayOS\winsetup"
    try {
        $result['time'] = (Get-Date -Format s)
        [IO.File]::WriteAllText("$d\done.json", ($result | ConvertTo-Json), $Utf8)
        Copy-Item -LiteralPath $Log -Destination "$d\finish.log" -Force
        Remove-Item -LiteralPath "$d\pending" -Force -ErrorAction SilentlyContinue
    } catch { Write-Log "esp: $_" }
    [void](Invoke-Quiet "mountvol $esp /D")
} else {
    Write-Log 'EFI system partition with the DelayOS setup folder not found'
}

# ---- 5. back to DelayOS ------------------------------------------------------------------------
# Put DelayOS first in the firmware boot order again (Windows may have moved itself to the front)
# and select it for the next start.
if ($guid) {
    [void](Invoke-Quiet "bcdedit /set {fwbootmgr} displayorder $guid /addfirst")
    [void](Invoke-Quiet "bcdedit /set {fwbootmgr} bootsequence $guid")
}
Write-Log 'restarting into DelayOS'
& shutdown.exe /r /t 5 /c "DelayOS"
