# Cata Camera Fix for World of Warcraft 4.3.4 (build 15595)
#
# Fixes the mouselook camera suddenly snapping to a random direction (worst with
# high polling rate mice). Instead of warping the hidden cursor to the middle of
# the window, the game now keeps it pinned where you clicked, so a late cursor
# update no longer turns into a huge camera turn.
#
# Port of the Turtle WoW / vanilla-tweaks "camera skip glitch fix" (credit: Bon,
# Turtle WoW Discord) to the Cataclysm client.
#
#   Install:  powershell -ExecutionPolicy Bypass -File CataCameraFix.ps1
#             Also turns on auto-fix: a hidden watcher (starts with Windows) that
#             re-applies the fix if a launcher puts the original Wow.exe back.
#             Add -NoAuto to skip that.
#   Remove:   powershell -ExecutionPolicy Bypass -File CataCameraFix.ps1 -Undo
#             Turns auto-fix off and restores the original Wow.exe.
#   Other folder: add  -Path "D:\Games\TwinStar\Wow.exe"

param(
    [string]$Path = (Join-Path $PSScriptRoot 'Wow.exe'),
    [switch]$Undo,
    [switch]$NoAuto,
    [switch]$Watch,
    [string]$StartupFolder = [Environment]::GetFolderPath('Startup')
)
$ErrorActionPreference = 'Stop'

$StockSha256   = '262A1B507D4E66F2FD9FC6DCDE8A35F593213B5C5DCE83C8636D2BB2CA30BF44'
$PatchedSha256 = '2C6753DAD22C6D5D789D7956EB91D39C4715BD3F9F3E43F2F23CABEE8BCF0FBE'
$ExeSize       = 10474064

$patches = @(
    @{ Offset = 0x473b50; Old = '558bec83ec1056578d45f0506a00e8dd1d000083c40450ff15e055b8008b75f08b45f82bc6992bc28bc88b45fcd1f903ce8b75f42bc6992bc2d1f803c6a3486bec008bf0a1ec6cec00890d446bec008bf985c0752e68f470bd00ff150053b80085c07423680071bd0050ff150453b800a3ec6cec0085c0750aa1fc55b800a3ec6cec005657ffd05f5e8be55dc3'; New = '5589e583ec185657bf446bec008d45f050ff7708ff158c56b80085c08b470c8b4f10742883f8327d014083f9327d01418b55f883ea3239d07e01488b55fc83ea3239d17e014989470c894f108945e8894dec8d75e856ff7708ff150856b800e8ece9ffff85c0750956e832e9ffff83c4048b068b4e048907894f045f5e89ec5dc3cccccccccccccccccccccccc' },
    @{ Offset = 0x9a8f10; Old = '6937'; New = '5937' },
    @{ Offset = 0x9a8f12; Old = '8e37'; New = '6637' },
    @{ Offset = 0x9a8f14; Old = '9537'; New = 'ab37' },
    @{ Offset = 0x9a8f16; Old = '9b37'; New = '9b07' },
    @{ Offset = 0x9a8f18; Old = 'a637'; New = 'a607' },
    @{ Offset = 0x9a8f1a; Old = 'ac37'; New = 'ac07' },
    @{ Offset = 0x9a8f1c; Old = 'b537'; New = 'b507' },
    @{ Offset = 0x9a8f1e; Old = 'bc37'; New = 'bc07' },
    @{ Offset = 0x9a8f20; Old = 'c137'; New = 'c107' },
    @{ Offset = 0x9a8f22; Old = 'ca37'; New = 'ca07' },
    @{ Offset = 0x9a8f24; Old = 'cf37'; New = 'cf07' }
)

$ShortcutName = 'Cata Camera Fix.lnk'
$LogPath = Join-Path $PSScriptRoot 'CataCameraFix.log'

function ConvertTo-Bytes([string]$hex) {
    $bytes = New-Object byte[] ($hex.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16)
    }
    return ,$bytes
}

function Test-Bytes([byte[]]$data, [int]$offset, [byte[]]$expected) {
    if ($offset + $expected.Length -gt $data.Length) { return $false }
    for ($i = 0; $i -lt $expected.Length; $i++) {
        if ($data[$offset + $i] -ne $expected[$i]) { return $false }
    }
    return $true
}

function Get-Sha256([byte[]]$data) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return ([BitConverter]::ToString($sha.ComputeHash($data))).Replace('-', '')
}

# 'stock', 'patched' or 'unknown'
function Get-PatchState([byte[]]$data) {
    $stock = $true
    $patched = $true
    foreach ($p in $patches) {
        if (-not (Test-Bytes $data $p.Offset (ConvertTo-Bytes $p.Old))) { $stock = $false }
        if (-not (Test-Bytes $data $p.Offset (ConvertTo-Bytes $p.New))) { $patched = $false }
    }
    if ($patched) { return 'patched' }
    if ($stock) { return 'stock' }
    return 'unknown'
}

function Set-PatchBytes([byte[]]$data, [string]$which) {
    foreach ($p in $patches) {
        $b = ConvertTo-Bytes $p[$which]
        [Array]::Copy($b, 0, $data, $p.Offset, $b.Length)
    }
}

function Write-Log([string]$msg) {
    try {
        if ((Test-Path -LiteralPath $LogPath) -and (Get-Item -LiteralPath $LogPath).Length -gt 65536) {
            $keep = Get-Content -LiteralPath $LogPath -Tail 100
            Set-Content -LiteralPath $LogPath -Value $keep -Encoding UTF8
        }
        Add-Content -LiteralPath $LogPath -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $msg) -Encoding UTF8
    } catch { }
}

function Stop-Watcher {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*CataCameraFix.ps1*-Watch*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Enable-Auto {
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $watchArgs = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Watch -Path "{1}"' -f $PSCommandPath, $Path
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut((Join-Path $StartupFolder $ShortcutName))
    $lnk.TargetPath = $ps
    $lnk.Arguments = $watchArgs
    $lnk.WorkingDirectory = $PSScriptRoot
    $lnk.WindowStyle = 7
    $lnk.Description = 'Keeps the Cata Camera Fix applied to Wow.exe'
    $lnk.Save()
    Stop-Watcher
    Start-Process -FilePath $ps -ArgumentList $watchArgs -WindowStyle Hidden
}

function Disable-Auto {
    $lnk = Join-Path $StartupFolder $ShortcutName
    if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force }
    Stop-Watcher
}

# Background watcher: re-applies the fix whenever Wow.exe is put back to the original.
function Start-Watch {
    $mutex = New-Object System.Threading.Mutex($false, 'Local\CataCameraFixWatch')
    if (-not $mutex.WaitOne(0)) { return }
    Write-Log "Auto-fix started, watching $Path"
    $lastSig = ''
    $changedAt = Get-Date
    $cachedSig = ''
    $state = ''
    $data = $null
    $applied = New-Object System.Collections.Generic.List[datetime]
    $waitingForGame = $false
    $pausedLogged = $false
    $readAt = Get-Date
    while ($true) {
        Start-Sleep -Seconds 2
        if (-not (Test-Path -LiteralPath $Path)) { continue }
        $fi = Get-Item -LiteralPath $Path
        $sig = '{0}|{1}' -f $fi.Length, $fi.LastWriteTimeUtc.Ticks
        if ($sig -ne $lastSig) { $lastSig = $sig; $changedAt = Get-Date; continue }
        # wait until the file has settled (a launcher may still be writing it)
        if (((Get-Date) - $changedAt).TotalSeconds -lt 5) { continue }

        # re-read when the file changed, and once a minute in case a restore kept the same timestamp
        if ($cachedSig -ne $sig -or ((Get-Date) - $readAt).TotalSeconds -ge 60) {
            $cachedSig = $sig
            $readAt = Get-Date
            $wasUnknown = ($state -eq 'unknown')
            $state = 'unknown'
            if ($fi.Length -eq $ExeSize) {
                try { $data = [System.IO.File]::ReadAllBytes($Path); $state = Get-PatchState $data } catch { $cachedSig = '' }
            }
            if ($state -eq 'unknown' -and -not $wasUnknown -and $cachedSig -ne '') { Write-Log 'Wow.exe changed and is not the standard 4.3.4 (15595) client - left alone.' }
        }
        if ($state -ne 'stock') { continue }

        $running = Get-Process -Name Wow -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Path }
        if ($running) {
            if (-not $waitingForGame) { Write-Log 'Wow.exe was put back to the original while the game is running - the fix goes back on when you close the game.'; $waitingForGame = $true }
            continue
        }

        # don't fight a launcher that keeps restoring the file
        $now = Get-Date
        $recent = @($applied | Where-Object { ($now - $_).TotalMinutes -lt 15 })
        if ($recent.Count -ge 3) {
            if (-not $pausedLogged) { Write-Log 'Wow.exe keeps getting put back to the original - pausing auto-fix for 15 minutes.'; $pausedLogged = $true }
            continue
        }

        try {
            Set-PatchBytes $data 'New'
            [System.IO.File]::WriteAllBytes($Path, $data)
            # remember our own write, so a restore straight after it is noticed
            $fi = Get-Item -LiteralPath $Path
            $lastSig = '{0}|{1}' -f $fi.Length, $fi.LastWriteTimeUtc.Ticks
            $cachedSig = $lastSig
            $applied.Add($now)
            $state = 'patched'
            $waitingForGame = $false
            $pausedLogged = $false
            Write-Log 'Found the original Wow.exe - camera fix applied.'
        } catch {
            # file in use (launcher or game) - try again next round
        }
    }
}

if ($Watch) { Start-Watch; exit 0 }

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "Can't find Wow.exe at: $Path" -ForegroundColor Red
    Write-Host "Put this file in your WoW folder (next to Wow.exe), or use -Path."
    exit 1
}
$Path = (Resolve-Path -LiteralPath $Path).Path
$data = [System.IO.File]::ReadAllBytes($Path)
$state = Get-PatchState $data

if ($state -eq 'unknown') {
    Write-Host "This Wow.exe isn't the standard 4.3.4 (15595) client, so it was NOT changed." -ForegroundColor Red
    exit 1
}

if ($Undo) {
    Disable-Auto
    if ($state -eq 'stock') { Write-Host "Camera fix is not installed - nothing to remove." -ForegroundColor Yellow; exit 0 }
    Set-PatchBytes $data 'Old'
    try {
        [System.IO.File]::WriteAllBytes($Path, $data)
    } catch {
        Write-Host "Auto-fix is off, but Wow.exe is in use - close the game and run this again." -ForegroundColor Red
        exit 1
    }
    Write-Host "Camera fix removed." -ForegroundColor Green
    exit 0
}

if ($state -eq 'patched') {
    Write-Host "Camera fix is already installed." -ForegroundColor Green
} else {
    $backup = "$Path.before-camfix"
    if (-not (Test-Path -LiteralPath $backup)) {
        [System.IO.File]::WriteAllBytes($backup, $data)
        Write-Host "Backup saved: $backup"
    }
    Set-PatchBytes $data 'New'
    try {
        [System.IO.File]::WriteAllBytes($Path, $data)
        Write-Host "Camera fix installed." -ForegroundColor Green
    } catch {
        if ($NoAuto) {
            Write-Host "Couldn't write Wow.exe - close the game/launcher and try again." -ForegroundColor Red
            exit 1
        }
        Write-Host "Wow.exe is in use right now - the fix will go on as soon as you close the game." -ForegroundColor Yellow
    }
}

if (-not $NoAuto) {
    Enable-Auto
    Write-Host "Auto-fix is on: if your launcher puts the original Wow.exe back, the fix is re-applied by itself." -ForegroundColor Green
}
