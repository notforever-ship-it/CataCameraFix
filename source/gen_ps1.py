"""gen_ps1.py <patchlist.txt> <original exe> <patched exe> <out.ps1> - write the PowerShell patcher."""
import sys, hashlib

plist, orig, patched, out = sys.argv[1:5]
rows = [l.split() for l in open(plist) if l.strip()]
sha_orig = hashlib.sha256(open(orig, "rb").read()).hexdigest().upper()
sha_new = hashlib.sha256(open(patched, "rb").read()).hexdigest().upper()

entries = ",\n".join("    @{ Offset = 0x%s; Old = '%s'; New = '%s' }" % (o, a, b) for o, a, b in rows)

ps1 = r"""# Cata Camera Fix for World of Warcraft 4.3.4 (build 15595)
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

$StockSha256   = '__SHA_ORIG__'
$PatchedSha256 = '__SHA_NEW__'

$patches = @(
__ENTRIES__
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
"""
ps1 = ps1.replace("__SHA_ORIG__", sha_orig).replace("__SHA_NEW__", sha_new).replace("__ENTRIES__", entries)
open(out, "w", newline="\r\n").write(ps1)
print("wrote", out, "orig", sha_orig, "patched", sha_new)
