# DelayOS hidden Windows: "gaming cleanup" of an official Windows 11 image at install time.
# Keep this file ASCII only. Documentation: docs/windows-switch.md (section "gaming cleanup").
#
# Goal: a lighter Windows that starts faster and only has to run anti-cheat games, WITHOUT touching
# anything an anti-cheat or Windows security depends on. Only documented switches are used
# (policies, per-user settings, service start types, scheduled tasks, provisioned Store apps);
# no system file is deleted and no component is removed from the component store.
#
# NEVER touched here (on purpose): TPM, Secure Boot, VBS / memory integrity (HVCI), Microsoft
# Defender and Windows Security, SmartScreen, the firewall, Windows Update and its services
# (wuauserv, UsoSvc, WaaSMedicSvc, BITS, DoSvc), WMI (Winmgmt), the Store, the Xbox app and Xbox
# services (Game Pass), Gaming Services, Game Bar itself, Game Mode, VC++ / .NET / DirectX /
# WebView2 / Edge, and every anti-cheat service (vgc, vgk, EasyAntiCheat, BEService, ...).
#
#   -Phase Machine   "specialize" pass (SYSTEM, before the first logon): machine policies, the
#                    default user profile, provisioned Store apps
#   -Phase User      first logon of the DelayOS account (elevated, from finish.ps1): that user's
#                    settings, services, scheduled tasks, startup entries
#   -Phase Undo      put back every registry value, service and task that was changed (the removed
#                    Store apps are listed; they come back from the Microsoft Store)
#   -Phase Report    JSON: disk / memory / process numbers and the security state (nothing changes)
#
# Everything that is changed is recorded with its previous value in cleanup-state.json next to
# this script, which is what Undo reads.
param([ValidateSet('Machine', 'User', 'Undo', 'Report')][string]$Phase = 'Report')

$ErrorActionPreference = 'Continue'
$Base = $PSScriptRoot
if (-not $Base) { $Base = Join-Path $env:ProgramData 'DelayOS\winsetup' }
$Log = Join-Path $Base 'cleanup.log'
$StateFile = Join-Path $Base 'cleanup-state.json'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$DefMount = 'DelayOSDefaultUser'

function Write-Log([string]$msg) {
    try { [IO.File]::AppendAllText($Log, ('{0} [{1}] {2}' -f (Get-Date -Format s), $Phase, $msg) + "`r`n", $Utf8) } catch {}
}

function Invoke-Quiet([string]$cmdline) {
    & cmd.exe /c "$cmdline >nul 2>&1"
    return $LASTEXITCODE
}

# ---- what is changed -------------------------------------------------------------------------------
# Provisioned Store apps that are removed (exact package names; anything not listed stays).
$AppxRemove = @(
    'Clipchamp.Clipchamp', 'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch',
    'Microsoft.BingFinance', 'Microsoft.BingSports', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
    'Microsoft.MicrosoftOfficeHub', 'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.MicrosoftStickyNotes',
    'Microsoft.People', 'Microsoft.PowerAutomateDesktop', 'Microsoft.Todos', 'Microsoft.WindowsFeedbackHub',
    'Microsoft.WindowsMaps', 'Microsoft.ZuneVideo', 'Microsoft.YourPhone', 'Microsoft.549981C3F5F10',
    'Microsoft.Copilot', 'Microsoft.Windows.Ai.Copilot.Provider', 'Microsoft.Windows.DevHome',
    'Microsoft.OutlookForWindows', 'microsoft.windowscommunicationsapps', 'MicrosoftTeams', 'MSTeams',
    'MicrosoftCorporationII.MicrosoftFamily', 'MicrosoftCorporationII.QuickAssist', 'Microsoft.SkypeApp',
    'Microsoft.MixedReality.Portal', 'Microsoft.Microsoft3DViewer', 'Microsoft.Wallet', 'Microsoft.Messaging',
    'Microsoft.OneConnect', 'Microsoft.Office.OneNote', 'Microsoft.StartExperiencesApp',
    'MicrosoftWindows.Client.WebExperience', 'Microsoft.WidgetsPlatformRuntime', 'MicrosoftWindows.CrossDevice',
    'Microsoft.M365Companions', 'Microsoft.Edge.GameAssist', 'Microsoft.LinkedIn'
)
# Safety net: a package whose name matches this is never removed, whatever the list above says.
$AppxKeep = '(?i)Store|DesktopAppInstaller|Xbox|GamingApp|GamingServices|VCLibs|UI\.Xaml|NET\.Native|WindowsAppRuntime|' +
            'WebView|SecHealthUI|Defender|MicrosoftEdge|Winget|Photos|Notepad|Calculator|Paint|Terminal|ScreenSketch|' +
            'Extension|LanguageExperiencePack|Camera|ZuneMusic|Alarms|SoundRecorder'

# Registry values. Scope M = HKLM, U = the user (default profile in the Machine phase, the DelayOS
# account in the User phase). Value $null = delete the value.
$Reg = @(
    # consumer features, suggested apps, tips, account nags
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableWindowsConsumerFeatures', 1),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableSoftLanding', 1),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableCloudOptimizedContent', 1),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableConsumerAccountStateContent', 1),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'OemPreInstalledAppsEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'PreInstalledAppsEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'PreInstalledAppsEverEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SilentInstalledAppsEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'FeatureManagementEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SoftLandingEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SystemPaneSuggestionsEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContentEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-310093Enabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338387Enabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338388Enabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338389Enabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338393Enabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-353694Enabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-353696Enabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-353698Enabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-88000326Enabled', 0),
    # lock screen: no rotating pictures / tips, and no lock screen at all (the account logs on by itself)
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'RotatingLockScreenEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'RotatingLockScreenOverlayEnabled', 0),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\Personalization', 'NoLockScreen', 1),
    @('M', 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System', 'EnableFirstLogonAnimation', 0),
    # Start menu / Settings / Explorer suggestions
    @('U', 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'Start_IrisRecommendations', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'Start_AccountNotifications', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'ShowSyncProviderNotifications', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'TaskbarMn', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'ShowCopilotButton', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement', 'ScoobeSystemSettingEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\Privacy', 'TailoredExperiencesWithDiagnosticDataEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo', 'Enabled', 0),
    @('U', 'Software\Microsoft\Siuf\Rules', 'NumberOfSIUFInPeriod', 0),
    # web results and "highlights" in search
    @('U', 'Software\Policies\Microsoft\Windows\Explorer', 'DisableSearchBoxSuggestions', 1),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\Search', 'BingSearchEnabled', 0),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\Windows Search', 'EnableDynamicContentInWSB', 0),
    # Copilot, Recall, Click to Do
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot', 'TurnOffWindowsCopilot', 1),
    @('U', 'Software\Policies\Microsoft\Windows\WindowsCopilot', 'TurnOffWindowsCopilot', 1),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'DisableAIDataAnalysis', 1),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'AllowRecallEnablement', 0),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'DisableClickToDo', 1),
    # widgets, news, chat icon
    @('M', 'SOFTWARE\Policies\Microsoft\Dsh', 'AllowNewsAndInterests', 0),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\Windows Feeds', 'EnableFeeds', 0),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\Windows Chat', 'ChatIcon', 3),
    # OneDrive: not set up for new accounts, no sync client
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\OneDrive', 'DisableFileSyncNGSC', 1),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\Run', 'OneDriveSetup', $null),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\Run', 'OneDrive', $null),
    # diagnostic data at the lowest level this edition allows, no feedback prompts, no CEIP
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'AllowTelemetry', 0),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'DoNotShowFeedbackNotifications', 1),
    @('M', 'SOFTWARE\Policies\Microsoft\SQMClient\Windows', 'CEIPEnable', 0),
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\AppCompat', 'AITEnable', 0),
    # Windows Update stays on; only the upload of updates to other PCs is off (downloads still work)
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization', 'DODownloadMode', 0),
    # Game Bar stays installed and Game Mode stays on; background recording / capture is off
    @('M', 'SOFTWARE\Policies\Microsoft\Windows\GameDVR', 'AllowGameDVR', 0),
    @('U', 'System\GameConfigStore', 'GameDVR_Enabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\GameDVR', 'AppCaptureEnabled', 0),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\GameDVR', 'HistoricalCaptureEnabled', 0),
    @('U', 'Software\Microsoft\GameBar', 'ShowStartupPanel', 0),
    @('U', 'Software\Microsoft\GameBar', 'AutoGameModeEnabled', 1),
    # startup: Edge does not preload or stay in the background (Edge and WebView2 stay installed)
    @('M', 'SOFTWARE\Policies\Microsoft\Edge', 'StartupBoostEnabled', 0),
    @('M', 'SOFTWARE\Policies\Microsoft\Edge', 'BackgroundModeEnabled', 0),
    @('M', 'SOFTWARE\Policies\Microsoft\Edge', 'HideFirstRunExperience', 1),
    @('U', 'Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize', 'StartupDelayInMSec', 0)
)
# Machine phase only: no 7 GB "reserved storage" (it is created at the end of setup when this is 1)
$RegMachineOnly = @(
    @('M', 'SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager', 'ShippedWithReserves', 0)
)
# Services set to "disabled" (start type 4). Short on purpose: nothing a game, an anti-cheat,
# Windows Update, Defender, the Store or the Xbox app uses.
$ServicesOff = @('DiagTrack', 'dmwappushservice', 'MapsBroker', 'RetailDemo', 'Fax', 'WMPNetworkSvc')
# Scheduled tasks that are disabled (telemetry / CEIP / maps)
$TasksOff = @(
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp',
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
    '\Microsoft\Windows\Application Experience\MareBackup',
    '\Microsoft\Windows\Autochk\Proxy',
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
    '\Microsoft\Windows\Feedback\Siuf\DmClient',
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
    '\Microsoft\Windows\Maps\MapsUpdateTask',
    '\Microsoft\Windows\Maps\MapsToastTask'
)
# Startup entries of the user that are removed when present (name patterns under ...\Run)
$RunRemove = '^(OneDrive|OneDriveSetup|MicrosoftEdgeAutoLaunch_.*|com\.squirrel\.Teams\.Teams|Teams|MSTeams)$'

# ---- state -----------------------------------------------------------------------------------------
$State = [ordered]@{ version = 1; reg = @(); services = @(); tasks = @(); appx = @(); phases = @() }
function Read-State {
    try {
        $s = [IO.File]::ReadAllText($StateFile, $Utf8) | ConvertFrom-Json
        foreach ($k in 'reg', 'services', 'tasks', 'appx', 'phases') { if ($s.$k) { $State[$k] = @($s.$k) } }
    } catch {}
}
function Save-State {
    try { [IO.File]::WriteAllText($StateFile, ($State | ConvertTo-Json -Depth 5), $Utf8) } catch { Write-Log "state: $_" }
}

# ---- registry --------------------------------------------------------------------------------------
function Open-Root([string]$scope) {
    if ($scope -eq 'M') { return [Microsoft.Win32.Registry]::LocalMachine }
    if ($script:UserRoot) { return $script:UserRoot }
    return [Microsoft.Win32.Registry]::CurrentUser
}

# Set (or delete, when $value is $null) one value and remember what was there before.
function Set-Value([string]$scope, [string]$path, [string]$name, $value, [string]$target) {
    try {
        $root = Open-Root $scope
        $key = $root.OpenSubKey($path, $true)
        $had = $false; $old = $null; $kind = 'DWord'
        if ($key) {
            if ($key.GetValueNames() -contains $name) {
                $had = $true
                $old = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $kind = [string]$key.GetValueKind($name)
            }
        }
        if ($null -eq $value) {
            if (-not $had) { if ($key) { $key.Close() }; return }
            $key.DeleteValue($name, $false)
        } else {
            if ($had -and ($kind -eq 'DWord') -and ([int]$old -eq [int]$value)) { $key.Close(); return }
            if (-not $key) { $key = $root.CreateSubKey($path) }
            $key.SetValue($name, [int]$value, [Microsoft.Win32.RegistryValueKind]::DWord)
        }
        $key.Close()
        if ($old -is [byte[]]) { $old = [Convert]::ToBase64String($old) }
        $script:State.reg += [pscustomobject]@{ scope = $scope; target = $target; path = $path; name = $name; had = $had; kind = $kind; old = $old }
    } catch { Write-Log "reg $scope\$path\$name : $($_.Exception.Message)" }
}

function Set-AllValues([string]$only, [string]$target) {
    $n = $script:State.reg.Count
    foreach ($r in $Reg) { if ((-not $only) -or ($r[0] -eq $only)) { Set-Value $r[0] $r[1] $r[2] $r[3] $target } }
    Write-Log ("registry ({0}): {1} value(s) changed" -f $target, ($script:State.reg.Count - $n))
}

function Undo-Value($r) {
    try {
        $root = [Microsoft.Win32.Registry]::LocalMachine
        if ($r.scope -eq 'U') { $root = [Microsoft.Win32.Registry]::CurrentUser }
        if (-not $r.had) {
            $key = $root.OpenSubKey($r.path, $true)
            if ($key) { $key.DeleteValue($r.name, $false); $key.Close() }
            return
        }
        $key = $root.CreateSubKey($r.path)
        $kind = [Microsoft.Win32.RegistryValueKind]$r.kind
        $v = $r.old
        if ($kind -eq 'DWord') { $v = [int]$v }
        elseif ($kind -eq 'QWord') { $v = [long]$v }
        elseif ($kind -eq 'Binary') { $v = [Convert]::FromBase64String([string]$v) }
        elseif ($kind -eq 'MultiString') { $v = [string[]]@($v) }
        else { $v = [string]$v }
        $key.SetValue($r.name, $v, $kind)
        $key.Close()
    } catch { Write-Log "undo reg $($r.path)\$($r.name): $($_.Exception.Message)" }
}

# ---- Store apps ------------------------------------------------------------------------------------
function Remove-ProvisionedApps {
    if (-not (Get-Command Get-AppxProvisionedPackage -ErrorAction SilentlyContinue)) { Write-Log 'appx: DISM cmdlets not available, skipped'; return }
    $all = @()
    try { $all = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) } catch { Write-Log "appx: $($_.Exception.Message)"; return }
    Write-Log ("appx: {0} provisioned package(s) in the image" -f $all.Count)
    foreach ($p in $all) {
        if (($AppxRemove -notcontains $p.DisplayName) -or ($p.DisplayName -match $AppxKeep)) { continue }
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null
            $script:State.appx += [string]$p.DisplayName
            Write-Log "appx: removed $($p.DisplayName)"
        } catch { Write-Log "appx: $($p.DisplayName): $($_.Exception.Message)" }
    }
}

function Remove-UserApps {
    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) { return }
    try {
        foreach ($p in @(Get-AppxPackage -ErrorAction Stop)) {
            if (($AppxRemove -notcontains $p.Name) -or ($p.Name -match $AppxKeep) -or $p.NonRemovable) { continue }
            try {
                Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop
                if ($script:State.appx -notcontains $p.Name) { $script:State.appx += [string]$p.Name }
                Write-Log "appx (user): removed $($p.Name)"
            } catch { Write-Log "appx (user): $($p.Name): $($_.Exception.Message)" }
        }
    } catch { Write-Log "appx (user): $($_.Exception.Message)" }
}

# ---- services and tasks ----------------------------------------------------------------------------
function Disable-Services {
    foreach ($s in $ServicesOff) {
        try {
            $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Services\$s")
            if (-not $k) { continue }
            $old = [int]$k.GetValue('Start', 3); $k.Close()
            if ($old -eq 4) { continue }
            if ((Invoke-Quiet "sc.exe config $s start= disabled") -ne 0) { Write-Log "service $s : could not be changed"; continue }
            [void](Invoke-Quiet "sc.exe stop $s")
            $script:State.services += [pscustomobject]@{ name = $s; old = $old }
            Write-Log "service $s : start $old -> 4"
        } catch { Write-Log "service $s : $($_.Exception.Message)" }
    }
}

function Get-Task([string]$full) {
    $svc = New-Object -ComObject Schedule.Service
    $svc.Connect()
    $i = $full.LastIndexOf('\')
    return $svc.GetFolder($full.Substring(0, [Math]::Max($i, 1))).GetTask($full.Substring($i + 1))
}

function Disable-Tasks {
    foreach ($t in $TasksOff) {
        try {
            $task = Get-Task $t
            if (-not $task.Enabled) { continue }
            $task.Enabled = $false
            $script:State.tasks += $t
            Write-Log "task disabled: $t"
        } catch {}     # the task does not exist in this build
    }
}

function Remove-RunEntries {
    try {
        $path = 'Software\Microsoft\Windows\CurrentVersion\Run'
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($path)
        if (-not $key) { return }
        $names = @($key.GetValueNames() | Where-Object { $_ -match $RunRemove })
        $key.Close()
        foreach ($n in $names) { Set-Value 'U' $path $n $null 'user' }
    } catch { Write-Log "run: $($_.Exception.Message)" }
}

# ---- report ----------------------------------------------------------------------------------------
function Get-Report {
    $r = [ordered]@{ time = (Get-Date -Format s) }
    try {
        $os = Get-WmiObject Win32_OperatingSystem
        $r.build = $os.BuildNumber
        $r.ram_total_mb = [int]($os.TotalVisibleMemorySize / 1024)
        $r.ram_used_mb = [int](($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024)
        $r.uptime_s = [int]((Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)).TotalSeconds
    } catch {}
    try {
        $d = New-Object IO.DriveInfo($env:SystemDrive)
        $r.disk_used_gb = [Math]::Round(($d.TotalSize - $d.TotalFreeSpace) / 1GB, 2)
        $r.disk_total_gb = [Math]::Round($d.TotalSize / 1GB, 1)
    } catch {}
    try { $r.processes = @([Diagnostics.Process]::GetProcesses()).Count } catch {}
    try { $r.services_running = @(Get-Service | Where-Object { $_.Status -eq 'Running' }).Count } catch {}
    try { $r.appx_provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop).Count } catch {}
    try {
        # last boot as Windows measured it (Diagnostics-Performance, event 100): total and until the desktop
        $e = Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; Id = 100 } -MaxEvents 1 -ErrorAction Stop
        $x = [xml]$e.ToXml()
        foreach ($n in $x.Event.EventData.Data) {
            if ($n.Name -eq 'BootTime') { $r.boot_ms = [int]$n.'#text' }
            if ($n.Name -eq 'MainPathBootTime') { $r.boot_main_ms = [int]$n.'#text' }
        }
    } catch {}
    try { $r.hiberfil = [IO.File]::Exists("$env:SystemDrive\hiberfil.sys") } catch {}
    # security state: all of this must stay on
    try { $r.secure_boot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { $r.secure_boot = $null }
    try { $t = Get-WmiObject -Namespace 'root\cimv2\Security\MicrosoftTpm' -Class Win32_Tpm -ErrorAction Stop; $r.tpm_present = [bool]$t; $r.tpm_spec = [string]$t.SpecVersion } catch { $r.tpm_present = $null }
    try {
        $dg = Get-WmiObject -Namespace 'root\Microsoft\Windows\DeviceGuard' -Class Win32_DeviceGuard -ErrorAction Stop
        $r.vbs_status = [int]$dg.VirtualizationBasedSecurityStatus
        $r.hvci_configured = [bool]($dg.SecurityServicesConfigured -contains 2)
        $r.hvci_running = [bool]($dg.SecurityServicesRunning -contains 2)
    } catch {}
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $r.defender_service = [bool]$mp.AMServiceEnabled
        $r.defender_realtime = [bool]$mp.RealTimeProtectionEnabled
        $r.defender_tamper = [bool]$mp.IsTamperProtected
    } catch { $r.defender_service = $null }
    foreach ($s in 'WinDefend', 'wuauserv', 'UsoSvc', 'BITS', 'Winmgmt', 'mpssvc', 'wscsvc') {
        try { $r["svc_$s"] = [string](Get-Service -Name $s -ErrorAction Stop).StartType } catch { $r["svc_$s"] = 'missing' }
    }
    $r.cleanup_applied = [bool](Test-Path -LiteralPath $StateFile)
    return $r
}

# ---- phases ----------------------------------------------------------------------------------------
if ($Phase -eq 'Report') {
    Get-Report | ConvertTo-Json
    exit 0
}

Write-Log 'start'
Read-State

if ($Phase -eq 'Machine') {
    Set-AllValues 'M' 'machine'
    foreach ($r in $RegMachineOnly) { Set-Value $r[0] $r[1] $r[2] $r[3] 'machine' }
    # these two would install the new Outlook and Dev Home at the first update check
    foreach ($k in 'OutlookUpdate', 'DevHomeUpdate') {
        try { [Microsoft.Win32.Registry]::LocalMachine.DeleteSubKeyTree("SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\$k", $false) } catch {}
    }
    # default user profile: every account created from now on (the DelayOS account) starts clean
    $ntuser = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    if ((Test-Path -LiteralPath $ntuser) -and ((Invoke-Quiet "reg load HKU\$DefMount `"$ntuser`"") -eq 0)) {
        try {
            $script:UserRoot = [Microsoft.Win32.Registry]::Users.OpenSubKey($DefMount, $true)
            Set-AllValues 'U' 'default-user'
        } finally {
            if ($script:UserRoot) { $script:UserRoot.Close() }
            $script:UserRoot = $null
            [GC]::Collect(); [GC]::WaitForPendingFinalizers()
            $rc = Invoke-Quiet "reg unload HKU\$DefMount"
            if ($rc -ne 0) { Start-Sleep -Seconds 2; [GC]::Collect(); $rc = Invoke-Quiet "reg unload HKU\$DefMount" }
            Write-Log "default user hive unloaded rc=$rc"
        }
    } else { Write-Log 'default user hive could not be loaded; the user settings are applied at the first logon' }
    Remove-ProvisionedApps
}
elseif ($Phase -eq 'User') {
    Set-AllValues $null 'user'
    Remove-RunEntries
    Remove-UserApps
    Disable-Services
    Disable-Tasks
    [void](Invoke-Quiet 'powercfg.exe /hibernate off')
}
elseif ($Phase -eq 'Undo') {
    # newest change first, so a value changed in two phases ends at its original state
    $regs = @($State.reg | Where-Object { $_.target -ne 'default-user' })
    [array]::Reverse($regs)
    foreach ($r in $regs) { Undo-Value $r }
    foreach ($s in $State.services) {
        $mode = @{ 0 = 'boot'; 1 = 'system'; 2 = 'auto'; 3 = 'demand'; 4 = 'disabled' }[[int]$s.old]
        if ($mode) { [void](Invoke-Quiet "sc.exe config $($s.name) start= $mode") }
    }
    foreach ($t in $State.tasks) { try { (Get-Task $t).Enabled = $true } catch {} }
    try { [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager', $true).SetValue('ShippedWithReserves', 1, 'DWord') } catch {}
    Write-Log ("undo: {0} registry value(s), {1} service(s), {2} task(s) restored" -f $regs.Count, @($State.services).Count, @($State.tasks).Count)
    Write-Host ''
    Write-Host 'DelayOS: the gaming cleanup settings were put back. Restart Windows to apply them.'
    Write-Host 'Hibernation and Fast Startup stay off (DelayOS shares this PC with Windows).'
    if (@($State.appx).Count) {
        Write-Host ''
        Write-Host 'These apps were removed and can be installed again from the Microsoft Store:'
        foreach ($a in $State.appx) { Write-Host "  $a" }
    }
    try { Move-Item -LiteralPath $StateFile -Destination ($StateFile + '.undone') -Force } catch {}
    exit 0
}

$State.phases = @($State.phases) + $Phase
Save-State
Write-Log 'end'
exit 0
