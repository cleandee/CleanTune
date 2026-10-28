<#
    CleanTune full uninstaller
    Removes everything CleanTune installed: VB-CABLE, Equalizer APO, HeSuVi,
    ReaPlugs, the CleanTune folder and the desktop shortcut.

    One-line uninstall from an elevated Windows PowerShell 5.1 window:
        irm https://raw.githubusercontent.com/cleandee/CleanTune/main/Uninstall-CleanTune.ps1 | iex
#>

& {

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ProjectName = 'CleanTune'
$EapoDir     = Join-Path $env:ProgramFiles 'EqualizerAPO'
$ProjectDir  = Join-Path $EapoDir "config\$ProjectName"
$HeSuViDir   = Join-Path $EapoDir 'config\HeSuVi'
$ReaPlugsDir = Join-Path $env:ProgramFiles 'VSTPlugins\ReaPlugs'
$TempDir     = Join-Path $env:TEMP "$ProjectName-uninstall"
$VBCableUrl  = 'https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack45.zip'

function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text)   { Write-Host "    OK  $Text" -ForegroundColor Green }
function Write-Warn2([string]$Text){ Write-Host "    !!  $Text" -ForegroundColor Yellow }
function Write-Info([string]$Text) { Write-Host "        $Text" }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-UninstallEntries([string]$Pattern) {
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty $roots -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $Pattern -and $_.UninstallString }
}

function Split-Command([string]$Command) {
    # Splits an uninstall string into the exe path and any arguments
    $Command = $Command.Trim()
    if ($Command.StartsWith('"')) {
        $end = $Command.IndexOf('"', 1)
        return @($Command.Substring(1, $end - 1), $Command.Substring($end + 1).Trim())
    }
    $i = $Command.ToLower().IndexOf('.exe')
    if ($i -lt 0) { return @($Command, '') }
    return @($Command.Substring(0, $i + 4), $Command.Substring($i + 4).Trim())
}

function Remove-Program([string]$Name, [string]$Pattern, [string]$Folder) {
    Write-Step "Removing $Name"
    $entries = @(Get-UninstallEntries $Pattern)
    if (-not $entries) { Write-Info 'No uninstaller registered' }

    foreach ($e in $entries) {
        $cmd = if ($e.QuietUninstallString) { $e.QuietUninstallString } else { $e.UninstallString }
        $exe, $args0 = Split-Command $cmd
        if (-not (Test-Path $exe)) { Write-Warn2 "Uninstaller missing: $exe"; continue }

        $argList = @()
        if ($args0) { $argList += $args0 }
        if (-not $e.QuietUninstallString -and $argList -notcontains '/S') { $argList += '/S' }
        # Makes NSIS uninstallers wait until they finish instead of returning straight away
        if ((Split-Path $exe -Leaf) -like 'uninst*') { $argList += "_?=$(Split-Path $exe -Parent)" }

        Write-Info "Running uninstaller for $($e.DisplayName)..."
        Start-Process $exe -ArgumentList $argList -Wait
        Remove-Item $e.PSPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($Folder -and (Test-Path $Folder)) {
        Remove-Item $Folder -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($Folder -and (Test-Path $Folder)) { Write-Warn2 "Some files in $Folder are in use and will go after a restart" }
    else { Write-Ok "$Name removed" }
}

function Remove-VBCable {
    Write-Step 'Removing VB-CABLE'
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    $zip  = Join-Path $TempDir 'vbcable.zip'
    $dest = Join-Path $TempDir 'vbcable'
    try {
        Invoke-WebRequest -Uri $VBCableUrl -OutFile $zip -UseBasicParsing
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Expand-Archive $zip -DestinationPath $dest -Force
        $setup = Get-ChildItem $dest -Recurse -Filter 'VBCABLE_Setup_x64.exe' | Select-Object -First 1
        if (-not $setup) { throw 'VBCABLE_Setup_x64.exe not found in the download' }
        Write-Info 'Removing the driver...'
        Start-Process $setup.FullName -ArgumentList '-u', '-h' -Wait
        Write-Ok 'VB-CABLE removed. It disappears fully after a restart'
    } catch {
        Write-Warn2 "Could not remove VB-CABLE automatically: $($_.Exception.Message)"
        Write-Info  'Download it from vb-audio.com/Cable, run VBCABLE_Setup_x64.exe as admin and click Remove Driver.'
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    Write-Host 'Run this in Windows PowerShell 5.1, not PowerShell 7.' -ForegroundColor Red
    return
}
if (-not (Test-Admin)) {
    Write-Host 'Right-click Windows PowerShell and choose Run as administrator, then try again.' -ForegroundColor Red
    return
}

Clear-Host
Write-Host ''
Write-Host "   $ProjectName uninstaller" -ForegroundColor Cyan
Write-Host ''
Write-Host '   This removes:'
Write-Host '     - CleanTune folder and desktop shortcut'
Write-Host '     - HeSuVi'
Write-Host '     - Equalizer APO'
Write-Host '     - ReaPlugs'
Write-Host '     - VB-CABLE'
Write-Host ''
$confirm = Read-Host '   Type Y to remove everything'
if ($confirm -ne 'Y' -and $confirm -ne 'y') { Write-Host '   Cancelled. Nothing was changed.'; return }

Write-Step 'Removing CleanTune folder and shortcut'
if (Test-Path $ProjectDir) { Remove-Item $ProjectDir -Recurse -Force -ErrorAction SilentlyContinue }
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) "$ProjectName.lnk"
if (Test-Path $lnk) { Remove-Item $lnk -Force }
Write-Ok 'CleanTune files removed'

Remove-Program 'HeSuVi'        'HeSuVi*'          $HeSuViDir
Remove-Program 'Equalizer APO' 'Equalizer APO*'   $EapoDir
Remove-Program 'ReaPlugs'      'ReaPlugs*'        $ReaPlugsDir
Remove-VBCable

if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue }
Remove-Item (Join-Path $env:TEMP "$ProjectName-setup") -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n   Everything has been removed." -ForegroundColor Green
Write-Host '   A restart is needed to finish removing the audio drivers.'
$restart = Read-Host '   Type Y to restart now, or press Enter to restart later'
if ($restart -eq 'Y' -or $restart -eq 'y') { Restart-Computer -Force }

}
