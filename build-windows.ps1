# DelayOS: build the ISO from Windows using Arch Linux in WSL2 (no windows pop up).
#   powershell -ExecutionPolicy Bypass -File .\build-windows.ps1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$distros = (wsl.exe --list --quiet) -replace "`0", '' | Where-Object { $_ -ne '' }
if ($distros -notcontains 'archlinux') {
    Write-Host '==> Installing Arch Linux for WSL (one time)...'
    wsl.exe --install archlinux --no-launch
    wsl.exe -d archlinux -u root -- true
}

Write-Host '==> Initialising pacman keys'
wsl.exe -d archlinux -u root -- bash -lc "pacman-key --init >/dev/null 2>&1; pacman-key --populate archlinux >/dev/null 2>&1; true"

# Build inside the Linux filesystem (much faster than /mnt/c and keeps permissions)
$src = (wsl.exe -d archlinux -u root -- wslpath -a "$here").Trim()
Write-Host "==> Copying profile from $src"
wsl.exe -d archlinux -u root -- bash -lc "rm -rf /root/delayos && cp -r '$src' /root/delayos && sed -i 's/\r$//' /root/delayos/build.sh /root/delayos/aur-packages.txt && chmod +x /root/delayos/build.sh"

Write-Host '==> Building (this downloads ~4 GB and can take 1-2 hours)'
wsl.exe -d archlinux -u root -- bash -lc "cd /root/delayos && ./build.sh"

$out = Join-Path $here 'out'
New-Item -ItemType Directory -Force $out | Out-Null
$dst = (wsl.exe -d archlinux -u root -- wslpath -a "$out").Trim()
wsl.exe -d archlinux -u root -- bash -lc "cp /root/delayos/out/*.iso* '$dst/'"
Write-Host "==> ISO copied to $out"
