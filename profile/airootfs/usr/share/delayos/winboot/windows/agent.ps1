# DelayOS <-> Windows link: agent (installed to %ProgramData%\DelayOS\winboot by install.ps1).
# Keep this file ASCII only: Windows PowerShell 5.1 reads BOM-less scripts in the ANSI code page.
# All Korean text is in messages.ko.json (UTF-8). Documentation: docs/windows-switch.md in DelayOS.
#
#   -Mode Agent      scheduled task "\DelayOS\WinBoot-Agent" (logon + resume, elevated):
#                    reads and deletes the launch request DelayOS left on the EFI system partition,
#                    starts the game through the non-elevated task "\DelayOS\WinBoot-Launch", exports
#                    the game inventory for DelayOS, waits for the game to end and reboots to DelayOS.
#                    No request -> only the inventory is refreshed; Windows starts normally.
#   -Mode Launch     non-elevated: start the game described in pending.json
#   -Mode Return     elevated, on demand (Start menu shortcut): reboot to DelayOS now
#   -Mode Inventory  export the game inventory only
#   -Mode Probe      print the firmware boot entry of DelayOS (and cache it in config.json)
#   -Mode Cleanup    remove what the agent wrote to the EFI system partition (uninstall)
param([ValidateSet('Agent', 'Launch', 'Return', 'Inventory', 'Probe', 'Cleanup')][string]$Mode = 'Agent')

$ErrorActionPreference = 'Continue'
$Version = '1.0'
$Base = Join-Path $env:ProgramData 'DelayOS\winboot'
$EspRel = 'EFI\DelayOS\winboot'
$TaskPath = '\DelayOS\'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:EspLetter = $null
$script:EspRoot = $null
$script:NoGuidPath = $false
$script:ReturnInfo = $null
$script:M = $null

function Write-Log([string]$msg) {
    try {
        $f = Join-Path $Base 'agent.log'
        if ([IO.File]::Exists($f) -and ((New-Object IO.FileInfo($f)).Length -gt 200kb)) { [IO.File]::Delete($f) }
        [IO.File]::AppendAllText($f, ('{0} [{1}] {2}' -f (Get-Date -Format s), $Mode, $msg) + "`r`n", $Utf8)
    } catch {}
}

function T([string]$key) {
    if ($null -eq $script:M) {
        try { $script:M = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'messages.ko.json'), $Utf8) | ConvertFrom-Json }
        catch { $script:M = New-Object psobject }
    }
    $v = $script:M.$key
    if ($v) { return [string]$v }
    return $key
}

function Invoke-Quiet([string]$cmdline) {
    & cmd.exe /c "$cmdline >nul 2>&1"
    return $LASTEXITCODE
}

function Read-Json([string]$file) {
    try { if ([IO.File]::Exists($file)) { return ([IO.File]::ReadAllText($file, $Utf8) | ConvertFrom-Json) } } catch {}
    return $null
}

function Write-Json([string]$file, $obj) {
    [IO.File]::WriteAllText($file, ($obj | ConvertTo-Json -Depth 8), $Utf8)
}

function Get-Config {
    $c = Read-Json (Join-Path $Base 'config.json')
    if ($null -eq $c) { $c = New-Object psobject }
    return $c
}

function Set-ConfigValue([string]$name, $value) {
    try {
        $c = Get-Config
        $c | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force
        Write-Json (Join-Path $Base 'config.json') $c
    } catch { Write-Log "config: $_" }
}

# ---- EFI system partition ---------------------------------------------------------------------
# DelayOS writes to the ESP that holds the Windows boot manager. Try the volume GUID path first
# (no drive letter appears); fall back to "mountvol X: /S".
function Get-EspRoot {
    if ($script:EspRoot) { return $script:EspRoot }
    $found = $null
    if (-not $script:NoGuidPath) { try {
        $parts = Get-Partition -ErrorAction Stop | Where-Object { $_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' }
        foreach ($p in $parts) {
            foreach ($ap in $p.AccessPaths) {
                if ($ap -like '\\?\Volume*') {
                    $r = [string]$ap
                    if (-not $r.EndsWith('\')) { $r += '\' }
                    try {
                        if ([IO.File]::Exists($r + 'EFI\Microsoft\Boot\bootmgfw.efi') -and ([IO.Directory]::GetDirectories($r + 'EFI').Length -gt 0)) {
                            if ((-not $found) -or [IO.Directory]::Exists($r + $EspRel)) { $found = $r }
                        }
                    } catch {}
                }
            }
        }
    } catch {} }
    if (-not $found) {
        $used = @([IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0, 1).ToUpper() })
        foreach ($l in 'S', 'T', 'U', 'V', 'W', 'Y', 'Z', 'R', 'Q', 'P') {
            if ($used -notcontains $l) {
                $rc = Invoke-Quiet "mountvol ${l}: /S"
                if (($rc -eq 0) -and [IO.Directory]::Exists("${l}:\EFI")) {
                    $script:EspLetter = $l
                    $found = "${l}:\"
                }
                break
            }
        }
    }
    $script:EspRoot = $found
    return $found
}

function Close-Esp {
    if ($script:EspLetter) {
        [void](Invoke-Quiet "mountvol $($script:EspLetter): /D")
        $script:EspLetter = $null
    }
    $script:EspRoot = $null
}

function Read-Request {
    $cands = @()
    $esp = Get-EspRoot
    if ($esp) { $cands += ($esp + $EspRel + '\request.json') }
    $cands += (Join-Path $Base 'request.json')          # legacy BIOS installs: written through NTFS
    foreach ($f in $cands) {
        try {
            if ([IO.File]::Exists($f)) {
                $txt = [IO.File]::ReadAllText($f, $Utf8)
                [IO.File]::Delete($f)
                $r = $txt | ConvertFrom-Json
                if (($r.version -eq 1) -and $r.launch -and $r.launch.type) { return $r }
                Write-Log "ignored request in $f"
            }
        } catch { Write-Log "request error: $_" }
    }
    return $null
}

# ---- back to DelayOS ----------------------------------------------------------------------------
# bcdedit prints localized headings, so parse by structure: blocks separated by blank lines, the
# identifier is the first {..} on the third line, and the path/description values are not translated.
function Find-ReturnGuid($ret) {
    $out = & cmd.exe /c 'bcdedit /enum firmware 2>nul'
    if (-not $out) { return $null }
    $blocks = (($out -join "`n") -split "(`n\s*){2,}")
    $best = $null
    $bestScore = 0
    foreach ($b in $blocks) {
        $lines = @($b -split "`n" | Where-Object { $_.Trim() -ne '' })
        if ($lines.Count -lt 3) { continue }
        $m = [regex]::Match($lines[2], '\{[0-9a-fA-F]{8}-[0-9a-fA-F-]{27}\}')
        if (-not $m.Success) { continue }
        if ($b -match 'bootmgfw\.efi') { continue }
        $score = 0
        if ($ret -and $ret.path -and ($b.ToLower().Contains(([string]$ret.path).ToLower()))) { $score += 4 }
        if ($b -match '\\EFI\\DelayOS\\') { $score += 3 }
        if ($b -match 'DelayOS') { $score += 2 }
        if ($ret -and $ret.label -and ($b.Contains([string]$ret.label))) { $score += 1 }
        if ($score -gt $bestScore) { $bestScore = $score; $best = $m.Value }
    }
    return $best
}

function Get-ReturnGuid($ret) {
    if (-not $ret) { $ret = (Get-Config).last_return }
    $g = Find-ReturnGuid $ret
    if ($g) { Set-ConfigValue 'return_guid' $g; return $g }
    return $null
}

function Invoke-Return([bool]$manual) {
    $guid = Get-ReturnGuid $script:ReturnInfo
    if ($guid) {
        $rc = Invoke-Quiet "bcdedit /set {fwbootmgr} bootsequence $guid"
        Write-Log "bootsequence $guid rc=$rc"
    } else {
        Write-Log 'no DelayOS firmware entry found'
        if ($manual) {
            Add-Type -AssemblyName System.Windows.Forms
            [void][System.Windows.Forms.MessageBox]::Show((T 'return_noentry'), (T 'return_title'))
            return
        }
        # came from DelayOS: its entry is normally first in the firmware boot order, a plain restart returns
    }
    & shutdown.exe /r /t 0
}

# ---- launching (runs NOT elevated, as the logged-on user) ---------------------------------------
function Get-RiotClient {
    $j = Read-Json (Join-Path $env:ProgramData 'Riot Games\RiotClientInstalls.json')
    if ($j) {
        foreach ($k in 'rc_live', 'rc_default', 'rc_beta') {
            $p = $j.$k
            if ($p -and (Test-Path -LiteralPath $p)) { return [string]$p }
        }
    }
    $p = "$env:SystemDrive\Riot Games\Riot Client\RiotClientServices.exe"
    if (Test-Path -LiteralPath $p) { return $p }
    return $null
}

function Start-Game($req) {
    $l = $req.launch
    switch ([string]$l.type) {
        'riot' {
            $rc = Get-RiotClient
            if (-not $rc) { throw (T 'err_riot') }
            Start-Process -FilePath $rc -ArgumentList @("--launch-product=$($l.product)", "--launch-patchline=$($l.patchline)")
        }
        'uri' {
            $target = [string]$l.target
            $scheme = $target.Split(':')[0].ToLower()
            if (($scheme -eq 'http') -or ($scheme -eq 'https') -or (Test-Path -LiteralPath "Registry::HKEY_CLASSES_ROOT\$scheme")) {
                Start-Process -FilePath $target
            } else {
                $fb = [Environment]::ExpandEnvironmentVariables([string]$l.fallback_exe)
                if ($fb -and -not (Test-Path -LiteralPath $fb)) { $fb = $fb.Replace('\Win64\', '\Win32\') }
                if ($fb -and (Test-Path -LiteralPath $fb)) { Start-Process -FilePath $fb }
                else { throw ((T 'err_uri') -f $scheme) }
            }
        }
        'exe' {
            $path = [Environment]::ExpandEnvironmentVariables([string]$l.path)
            if (-not (Test-Path -LiteralPath $path)) { throw ((T 'err_exe') -f $path) }
            $sp = @{ FilePath = $path; WorkingDirectory = (Split-Path -Parent $path) }
            if ($l.args) { $sp.ArgumentList = [string]$l.args }
            Start-Process @sp
        }
        default { throw "unknown launch type $($l.type)" }
    }
}

function Start-GameAsUser($req) {
    # the agent is elevated; games must not be. Hand over to the non-elevated on-demand task.
    Write-Json (Join-Path $Base 'pending.json') $req
    try {
        Start-ScheduledTask -TaskPath $TaskPath -TaskName 'WinBoot-Launch' -ErrorAction Stop
        return
    } catch { Write-Log "launch task failed: $_" }
    $l = $req.launch
    if ($l.type -eq 'uri') { Start-Process -FilePath explorer.exe -ArgumentList ('"{0}"' -f $l.target) }
    elseif (($l.type -eq 'exe') -and (-not $l.args)) { Start-Process -FilePath explorer.exe -ArgumentList ('"{0}"' -f [Environment]::ExpandEnvironmentVariables([string]$l.path)) }
    elseif ($l.type -eq 'riot') { Start-Game $req }
}

# ---- game inventory for DelayOS -------------------------------------------------------------------
function ConvertTo-Id([string]$s) {
    $s = ($s.ToLower() -replace '[^a-z0-9._-]', '-').Trim('-', '.', '_')
    if ($s.Length -gt 60) { $s = $s.Substring(0, 60) }
    return $s
}

function Find-MainExe([string]$dir) {
    try {
        $skip = 'unins|crash|redist|setup|install|launcher|helper|report|vc_|dxsetup|anticheat|battleye|easyanti|prereq|dotnet|update|webview|cef'
        $c = Get-ChildItem -LiteralPath $dir -Filter *.exe -File -Recurse -Depth 3 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch $skip } | Sort-Object Length -Descending | Select-Object -First 1
        if ($c) { return $c.FullName }
    } catch {}
    return $null
}

function Save-Icon([string]$src, [string]$dst) {
    try {
        Add-Type -AssemblyName System.Drawing
        if ($src.ToLower().EndsWith('.ico')) { $ico = New-Object System.Drawing.Icon($src, 64, 64) }
        else { $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($src) }
        $bmp = New-Object System.Drawing.Bitmap(64, 64)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($ico.ToBitmap(), 0, 0, 64, 64)
        $g.Dispose()
        $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $ico.Dispose()
        return $true
    } catch { return $false }
}

function Get-SteamGames {
    $res = @()
    $root = $null
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
        try { $root = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallPath } catch {}
        if ($root) { break }
    }
    if (-not $root) { try { $root = ((Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath) -replace '/', '\' } catch {} }
    if ((-not $root) -or (-not (Test-Path -LiteralPath $root))) { return $res }
    $libs = @($root)
    $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf, $Utf8), '"path"\s+"([^"]+)"')) {
            $p = $m.Groups[1].Value -replace '\\\\', '\'
            if ($libs -notcontains $p) { $libs += $p }
        }
    }
    $tools = '228980', '250820', '1070560', '1391110', '1628350', '1493710', '2180100', '1887720', '2348590', '2805730', '3658110'
    foreach ($lib in $libs) {
        $sa = Join-Path $lib 'steamapps'
        if (-not (Test-Path -LiteralPath $sa)) { continue }
        foreach ($f in Get-ChildItem -LiteralPath $sa -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue) {
            try {
                $t = [IO.File]::ReadAllText($f.FullName, $Utf8)
                $id = [regex]::Match($t, '"appid"\s+"(\d+)"').Groups[1].Value
                $name = [regex]::Match($t, '"name"\s+"([^"]*)"').Groups[1].Value
                $dir = [regex]::Match($t, '"installdir"\s+"([^"]*)"').Groups[1].Value
                $flags = [int]([regex]::Match($t, '"StateFlags"\s+"(\d+)"').Groups[1].Value)
                if ((-not $id) -or (-not $name) -or (($flags -band 4) -eq 0)) { continue }
                if (($tools -contains $id) -or ($name -match '^(Steamworks |Steam Linux Runtime|Proton )')) { continue }
                $full = Join-Path $sa ('common\' + $dir)
                $res += @{ id = "steam-$id"; name = $name; source = 'steam'; install_dir = $full
                           launch = @{ type = 'uri'; target = "steam://rungameid/$id" }; exit_processes = @(); _icon = '' }
            } catch {}
        }
    }
    return $res
}

function Get-EpicGames {
    $res = @()
    $dir = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (-not (Test-Path -LiteralPath $dir)) { return $res }
    foreach ($f in Get-ChildItem -LiteralPath $dir -Filter '*.item' -File -ErrorAction SilentlyContinue) {
        $j = Read-Json $f.FullName
        if ((-not $j) -or (-not $j.AppName) -or (-not $j.DisplayName)) { continue }
        if ($j.bIsIncompleteInstall) { continue }
        if ($j.AppCategories -and (@($j.AppCategories) -notcontains 'games')) { continue }
        if ($j.MainGameAppName -and ($j.MainGameAppName -ne $j.AppName)) { continue }
        $app = [string]$j.AppName
        if ($j.CatalogNamespace -and $j.CatalogItemId) { $ref = '{0}%3A{1}%3A{2}' -f $j.CatalogNamespace, $j.CatalogItemId, $app } else { $ref = $app }
        $exe = ''
        $procs = @()
        if ($j.LaunchExecutable) {
            $exe = Join-Path ([string]$j.InstallLocation) (([string]$j.LaunchExecutable) -replace '/', '\')
            $procs = @([IO.Path]::GetFileNameWithoutExtension($exe))
        }
        $res += @{ id = 'epic-' + (ConvertTo-Id $app); name = [string]$j.DisplayName; source = 'epic'
                   install_dir = [string]$j.InstallLocation
                   launch = @{ type = 'uri'; target = "com.epicgames.launcher://apps/${ref}?action=launch&silent=true" }
                   exit_processes = $procs; _icon = $exe }
    }
    return $res
}

function Get-RiotGames {
    $res = @()
    $meta = Join-Path $env:ProgramData 'Riot Games\Metadata'
    $known = @(
        @{ product = 'valorant'; name = 'VALORANT'; procs = @('VALORANT-Win64-Shipping', 'VALORANT') },
        @{ product = 'league_of_legends'; name = 'League of Legends'; procs = @('LeagueClient', 'LeagueClientUx', 'League of Legends') }
    )
    foreach ($k in $known) {
        $d = Join-Path $meta ($k.product + '.live')
        if (Test-Path -LiteralPath $d) {
            $ico = Join-Path $d ($k.product + '.live.ico')
            if (-not (Test-Path -LiteralPath $ico)) { $ico = '' }
            $res += @{ id = 'riot-' + $k.product; name = $k.name; source = 'riot'; install_dir = ''
                       launch = @{ type = 'riot'; product = $k.product; patchline = 'live' }
                       exit_processes = $k.procs; _icon = $ico }
        }
    }
    return $res
}

function Get-UbisoftGames {
    $res = @()
    foreach ($root in 'HKLM:\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs', 'HKLM:\SOFTWARE\Ubisoft\Launcher\Installs') {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($k in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue) {
            try {
                $dir = ([string](Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction Stop).InstallDir) -replace '/', '\'
                $dir = $dir.TrimEnd('\')
                if ((-not $dir) -or (-not (Test-Path -LiteralPath $dir))) { continue }
                $id = $k.PSChildName
                $res += @{ id = "ubisoft-$id"; name = (Split-Path -Leaf $dir); source = 'ubisoft'; install_dir = $dir
                           launch = @{ type = 'uri'; target = "uplay://launch/$id/0" }; exit_processes = @(); _icon = '' }
            } catch {}
        }
        break
    }
    return $res
}

function Export-Inventory {
    $games = @()
    foreach ($fn in 'Get-RiotGames', 'Get-SteamGames', 'Get-EpicGames', 'Get-UbisoftGames') {
        try { $games += @(& $fn) } catch { Write-Log "$fn failed: $_" }
    }
    $iconDir = Join-Path $Base 'icons'
    $noDir = Join-Path $Base 'noicon'
    [void][IO.Directory]::CreateDirectory($iconDir)
    [void][IO.Directory]::CreateDirectory($noDir)
    $seen = @{}
    $list = @()
    foreach ($g in $games) {
        if ((-not $g.id) -or $seen.ContainsKey($g.id) -or ($list.Count -ge 300)) { continue }
        $seen[$g.id] = $true
        $png = Join-Path $iconDir ($g.id + '.png')
        $miss = Join-Path $noDir $g.id
        if ((-not [IO.File]::Exists($png)) -and (-not [IO.File]::Exists($miss))) {
            $src = [string]$g._icon
            if ((-not $src) -or (-not [IO.File]::Exists($src))) { $src = if ($g.install_dir) { Find-MainExe $g.install_dir } else { $null } }
            if ((-not $src) -or (-not (Save-Icon $src $png))) { try { [IO.File]::WriteAllText($miss, '') } catch {} }
        }
        $icon = ''
        if ([IO.File]::Exists($png)) { $icon = $g.id + '.png' }
        $list += [ordered]@{ id = $g.id; name = $g.name; source = $g.source; launch = $g.launch
                             exit_processes = @($g.exit_processes); install_dir = $g.install_dir; icon = $icon }
    }
    # stale icons
    foreach ($f in [IO.Directory]::GetFiles($iconDir, '*.png')) {
        if (-not $seen.ContainsKey([IO.Path]::GetFileNameWithoutExtension($f))) { try { [IO.File]::Delete($f) } catch {} }
    }

    $cfg = Get-Config
    $autologon = $false
    try { $autologon = ((Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction Stop).AutoAdminLogon -eq '1') } catch {}
    $helper = [ordered]@{ version = $Version; autologon = $autologon; bootux = [bool]$cfg.bootux_set
                          return_entry = [bool]$cfg.return_guid; user = $env:USERNAME }
    $sigSrc = (@{ helper = $helper; games = $list } | ConvertTo-Json -Depth 8 -Compress)
    $sha = [Security.Cryptography.SHA1]::Create()
    $sig = [BitConverter]::ToString($sha.ComputeHash($Utf8.GetBytes($sigSrc))) -replace '-', ''
    $helper.updated = (Get-Date).ToString('s')
    $doc = [ordered]@{ version = 1; signature = $sig; helper = $helper; games = $list }
    $local = Join-Path $Base 'inventory.json'
    $old = Read-Json $local
    if ((-not $old) -or ($old.signature -ne $sig)) { Write-Json $local $doc }

    try { Copy-InventoryToEsp $doc $list $sig $iconDir }
    catch {
        Write-Log "inventory export failed: $_"
        if ((-not $script:EspLetter) -and (-not $script:NoGuidPath)) {
            # the volume GUID path did not work with this .NET: retry once through a drive letter
            $script:NoGuidPath = $true
            $script:EspRoot = $null
            try { Copy-InventoryToEsp $doc $list $sig $iconDir } catch { Write-Log "inventory export failed again: $_" }
        }
    }
}

function Copy-InventoryToEsp($doc, $list, [string]$sig, [string]$iconDir) {
    $esp = Get-EspRoot
    if (-not $esp) { return }
    if ($true) {
        $dst = $esp + $EspRel
        [void][IO.Directory]::CreateDirectory($dst)
        $oldEsp = Read-Json ($dst + '\inventory.json')
        if ($oldEsp -and ($oldEsp.signature -eq $sig)) { return }
        $dstIcons = $dst + '\icons'
        [void][IO.Directory]::CreateDirectory($dstIcons)
        $want = @{}
        foreach ($e in $list) {
            if ($e.icon) {
                $want[$e.icon] = $true
                $s = Join-Path $iconDir $e.icon
                $d = $dstIcons + '\' + $e.icon
                if ((New-Object IO.FileInfo($s)).Length -le 100kb) {
                    if ((-not [IO.File]::Exists($d)) -or ((New-Object IO.FileInfo($d)).Length -ne (New-Object IO.FileInfo($s)).Length)) { [IO.File]::Copy($s, $d, $true) }
                }
            }
        }
        foreach ($f in [IO.Directory]::GetFiles($dstIcons)) {
            if (-not $want.ContainsKey([IO.Path]::GetFileName($f))) { try { [IO.File]::Delete($f) } catch {} }
        }
        Write-Json ($dst + '\inventory.json') $doc
        Write-Log "inventory exported: $($list.Count) games"
    }
}

# ---- waiting for the game to end ------------------------------------------------------------------
function Get-AliveNames([bool]$deep) {
    $names = New-Object 'System.Collections.Generic.List[string]'
    foreach ($n in (@($script:Req.exit_processes) + @($script:Seen))) {
        if ($n -and (-not $names.Contains($n))) {
            $ps = [Diagnostics.Process]::GetProcessesByName($n)
            if ($ps.Length -gt 0) { $names.Add($n) }
            foreach ($p in $ps) { $p.Dispose() }
        }
    }
    if ($deep -and $script:Dir) {
        try {
            $prefix = $script:Dir.TrimEnd('\') + '\'
            foreach ($p in Get-CimInstance -ClassName Win32_Process -Property Name, ExecutablePath -ErrorAction Stop) {
                if ($p.ExecutablePath -and $p.ExecutablePath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                    $n = [IO.Path]::GetFileNameWithoutExtension($p.Name)
                    if (-not $names.Contains($n)) { $names.Add($n) }
                }
            }
        } catch {}
    }
    return , $names
}

function Add-Seen($names) {
    foreach ($n in $names) { if ($script:Seen -notcontains $n) { $script:Seen += $n } }
}

function Set-Idle([string]$text) {
    $script:Phase = 'idle'
    $script:Timer.Stop()
    if ($text) { $script:Tray.ShowBalloonTip(8000, (T 'balloon_title'), $text, [System.Windows.Forms.ToolTipIcon]::Info) }
}

function Stop-Agent {
    try { $script:Timer.Stop() } catch {}
    try { $script:Tray.Visible = $false; $script:Tray.Dispose() } catch {}
    [System.Windows.Forms.Application]::Exit()
}

function Show-ReturnPrompt {
    $script:Left = [int]$script:Req.return_delay
    if ($script:Left -le 0) { Stop-Agent; Invoke-Return $false; return }
    $f = New-Object System.Windows.Forms.Form
    $f.Text = T 'return_title'
    $f.ClientSize = New-Object System.Drawing.Size(440, 130)
    $f.StartPosition = 'CenterScreen'
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.SetBounds(20, 20, 400, 50)
    $lbl.Text = (T 'return_text') -f $script:Left
    $stay = New-Object System.Windows.Forms.Button
    $stay.SetBounds(150, 82, 130, 30)
    $stay.Text = T 'return_stay'
    $now = New-Object System.Windows.Forms.Button
    $now.SetBounds(290, 82, 130, 30)
    $now.Text = T 'return_now'
    $f.Controls.AddRange(@($lbl, $stay, $now))
    $script:Prompt = $f
    $script:PromptLabel = $lbl
    $script:Decision = ''
    $ct = New-Object System.Windows.Forms.Timer
    $ct.Interval = 1000
    $script:PromptTimer = $ct
    $ct.add_Tick({
        $script:Left--
        if ((Get-AliveNames $false).Count -gt 0) { $script:Decision = 'resume'; $script:Prompt.Close(); return }
        if ($script:Left -le 0) { $script:Decision = 'return'; $script:Prompt.Close(); return }
        $script:PromptLabel.Text = (T 'return_text') -f $script:Left
    })
    $stay.add_Click({ $script:Decision = 'stay'; $script:Prompt.Close() })
    $now.add_Click({ $script:Decision = 'return'; $script:Prompt.Close() })
    $f.add_FormClosed({
        $script:PromptTimer.Stop()
        if ($script:Decision -eq 'return') { Stop-Agent; Invoke-Return $false }
        elseif ($script:Decision -eq 'resume') { $script:Phase = 'run'; $script:Gone = 0; $script:Timer.Start() }
        else { Set-Idle '' }
    })
    $ct.Start()
    $f.Show()
}

function Step {
    $script:Ticks++
    if ($script:Phase -eq 'wait') {
        $alive = Get-AliveNames (($script:Ticks % 3) -eq 0)
        if ($alive.Count -gt 0) {
            Add-Seen $alive
            $script:Phase = 'run'
            Write-Log ('game running: ' + ($alive -join ', '))
        } elseif (((Get-Date) - $script:Started).TotalSeconds -gt 1800) {
            Write-Log 'game did not start in time'
            Set-Idle (T 'balloon_timeout')
        }
    } elseif ($script:Phase -eq 'run') {
        $alive = Get-AliveNames $false
        if ($alive.Count -eq 0) { $alive = Get-AliveNames $true }
        if ($alive.Count -gt 0) { $script:Gone = 0; Add-Seen $alive }
        else {
            $script:Gone++
            if ($script:Gone -ge 2) {
                Write-Log 'game ended'
                $script:Phase = 'prompt'
                $script:Timer.Stop()
                Show-ReturnPrompt
            }
        }
    }
}

function Wait-ForGame($req) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $script:Req = $req
    $script:Seen = @()
    $script:Dir = [string]$req.install_dir
    $script:Phase = 'wait'
    $script:Ticks = 0
    $script:Gone = 0
    $script:Started = Get-Date
    $name = [string]$req.name

    $tray = New-Object System.Windows.Forms.NotifyIcon
    $tray.Icon = [System.Drawing.SystemIcons]::Application
    $tip = (T 'tray_tip') -f $name
    if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 63) }
    $tray.Text = $tip
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $miReturn = $menu.Items.Add((T 'tray_return'))
    $miStay = $menu.Items.Add((T 'tray_stay'))
    $miReturn.add_Click({ Stop-Agent; Invoke-Return $false })
    $miStay.add_Click({ Stop-Agent })
    $tray.ContextMenuStrip = $menu
    $tray.Visible = $true
    $script:Tray = $tray

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 5000
    $timer.add_Tick({ try { Step } catch { Write-Log "step: $_" } })
    $script:Timer = $timer

    $auto = (@($req.exit_processes | Where-Object { $_ }).Count -gt 0) -or [bool]$script:Dir
    if ($auto) {
        $timer.Start()
        $tray.ShowBalloonTip(5000, (T 'balloon_title'), ((T 'balloon_text') -f $name), [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        $script:Phase = 'idle'
        $tray.ShowBalloonTip(10000, (T 'balloon_title'), ((T 'balloon_manual') -f $name), [System.Windows.Forms.ToolTipIcon]::Info)
    }
    [System.Windows.Forms.Application]::Run()
}

# ---- main -------------------------------------------------------------------------------------------
switch ($Mode) {
    'Launch' {
        $req = Read-Json (Join-Path $Base 'pending.json')
        if ($req) {
            try { Start-Game $req }
            catch {
                Add-Type -AssemblyName System.Windows.Forms
                [void][System.Windows.Forms.MessageBox]::Show(((T 'launch_failed') -f $req.name, $_.Exception.Message), 'DelayOS')
            }
        }
    }
    'Return' { Invoke-Return $true }
    'Probe' {
        $g = Get-ReturnGuid $null
        if ($g) { Write-Output $g }
    }
    'Inventory' {
        Export-Inventory
        Close-Esp
    }
    'Cleanup' {
        $esp = Get-EspRoot
        if ($esp) {
            foreach ($f in 'inventory.json', 'request.json') { try { [IO.File]::Delete($esp + $EspRel + '\' + $f) } catch {} }
            try { if ([IO.Directory]::Exists($esp + $EspRel + '\icons')) { [IO.Directory]::Delete($esp + $EspRel + '\icons', $true) } } catch {}
        }
        Close-Esp
    }
    'Agent' {
        $req = Read-Request
        if ($req) {
            Write-Log "request: $($req.id) ($($req.launch.type))"
            $script:ReturnInfo = $req.return
            if ($req.return) { Set-ConfigValue 'last_return' $req.return }
            try { Start-GameAsUser $req } catch { Write-Log "launch failed: $_" }
        } else {
            try { [Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'BelowNormal' } catch {}
        }
        try { Export-Inventory } catch { Write-Log "inventory: $_" }
        Close-Esp
        if ($req) { Wait-ForGame $req }
    }
}
