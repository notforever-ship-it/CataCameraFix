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
#   Remove:   powershell -ExecutionPolicy Bypass -File CataCameraFix.ps1 -Undo
#   Other folder: add  -Path "D:\Games\TwinStar\Wow.exe"

param(
    [string]$Path = (Join-Path $PSScriptRoot 'Wow.exe'),
    [switch]$Undo
)
$ErrorActionPreference = 'Stop'

$StockSha256   = '262A1B507D4E66F2FD9FC6DCDE8A35F593213B5C5DCE83C8636D2BB2CA30BF44'
$PatchedSha256 = '2C6753DAD22C6D5D789D7956EB91D39C4715BD3F9F3E43F2F23CABEE8BCF0FBE'

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

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "Can't find Wow.exe at: $Path" -ForegroundColor Red
    Write-Host "Put this file in your WoW folder (next to Wow.exe), or use -Path."
    exit 1
}
$Path = (Resolve-Path -LiteralPath $Path).Path
$data = [System.IO.File]::ReadAllBytes($Path)

$isStock = $true
$isPatched = $true
foreach ($p in $patches) {
    if (-not (Test-Bytes $data $p.Offset (ConvertTo-Bytes $p.Old))) { $isStock = $false }
    if (-not (Test-Bytes $data $p.Offset (ConvertTo-Bytes $p.New))) { $isPatched = $false }
}

if (-not $isStock -and -not $isPatched) {
    Write-Host "This Wow.exe isn't the standard 4.3.4 (15595) client, so it was NOT changed." -ForegroundColor Red
    exit 1
}

if ($Undo) {
    if ($isStock) { Write-Host "Camera fix is not installed - nothing to remove." -ForegroundColor Yellow; exit 0 }
    foreach ($p in $patches) {
        $b = ConvertTo-Bytes $p.Old
        [Array]::Copy($b, 0, $data, $p.Offset, $b.Length)
    }
    $label = 'removed'
} else {
    if ($isPatched) { Write-Host "Camera fix is already installed." -ForegroundColor Green; exit 0 }
    $backup = "$Path.before-camfix"
    if (-not (Test-Path -LiteralPath $backup)) {
        [System.IO.File]::WriteAllBytes($backup, $data)
        Write-Host "Backup saved: $backup"
    }
    foreach ($p in $patches) {
        $b = ConvertTo-Bytes $p.New
        [Array]::Copy($b, 0, $data, $p.Offset, $b.Length)
    }
    $label = 'installed'
}

try {
    [System.IO.File]::WriteAllBytes($Path, $data)
} catch {
    Write-Host "Couldn't write Wow.exe - close the game/launcher and try again." -ForegroundColor Red
    exit 1
}

$sha = Get-Sha256 $data
if ($sha -eq $StockSha256 -or $sha -eq $PatchedSha256) {
    Write-Host "Camera fix $label." -ForegroundColor Green
} else {
    Write-Host "Camera fix $label (file differs from the reference build elsewhere - that's usually fine)." -ForegroundColor Green
}
