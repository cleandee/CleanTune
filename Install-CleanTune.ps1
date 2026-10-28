#Requires -Version 5.1
<#
    CleanTune guided installer
    Game audio tuning stack for Call of Duty Warzone / Black Ops 7.

    Chain:  Game -> CABLE Input (Equalizer APO + HeSuVi) -> CABLE Output -> "Listen" -> headphones

    Run from an elevated Windows PowerShell 5.1 window:
        powershell -ExecutionPolicy Bypass -File .\Install-CleanTune.ps1
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # makes Invoke-WebRequest far faster on PS 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---------------------------------------------------------------------------
# Settings - change these in one place
# ---------------------------------------------------------------------------
$ProjectName = 'CleanTune'
$Version     = '2026.10-V1.1'

$Downloads = @{
    VBCable = @{
        Name = 'VB-CABLE'
        Url  = 'https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack45.zip'
        Page = 'https://vb-audio.com/Cable/'
        File = 'VBCABLE_Driver_Pack.zip'
    }
    EAPO = @{
        Name = 'Equalizer APO'
        Url  = 'https://sourceforge.net/projects/equalizerapo/files/1.4.2/EqualizerAPO-x64-1.4.2.exe/download'
        Page = 'https://sourceforge.net/projects/equalizerapo/files/'
        File = 'EqualizerAPO-x64.exe'
    }
    HeSuVi = @{
        Name = 'HeSuVi'
        Url  = 'https://sourceforge.net/projects/hesuvi/files/HeSuVi_2.0.0.1.exe/download'
        Page = 'https://sourceforge.net/projects/hesuvi/files/'
        File = 'HeSuVi_Setup.exe'
    }
    ReaPlugs = @{
        Name = 'ReaPlugs'
        Url  = 'https://www.reaper.fm/reaplugs/reaplugs236_x64-install.exe'
        Page = 'https://www.reaper.fm/reaplugs/'
        File = 'ReaPlugs_Setup.exe'
    }
}

$EapoDir     = Join-Path $env:ProgramFiles 'EqualizerAPO'
$EapoConfig  = Join-Path $EapoDir 'config'
$ConfigFile  = Join-Path $EapoConfig 'config.txt'
$ProjectDir  = Join-Path $EapoConfig $ProjectName
$LibraryDest = Join-Path $ProjectDir 'library'
$BoostFile   = Join-Path $ProjectDir 'boost.txt'
$TempDir     = Join-Path $env:TEMP "$ProjectName-setup"
$LibrarySrc  = Join-Path $PSScriptRoot 'library'

$DefaultGame    = 'WZ-BO7'
$DefaultTuneVer = 'V1'
$DefaultPreFile = 'WZ-BO7_V1_pre_nogun.txt'
$DefaultEqFile  = '7Hz_G1.txt'      # falls back to Flat_EQ.txt if missing
$ReaPlugsDir    = Join-Path $env:ProgramFiles 'VSTPlugins\ReaPlugs'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text)   { Write-Host "    OK  $Text" -ForegroundColor Green }
function Write-Warn2([string]$Text){ Write-Host "    !!  $Text" -ForegroundColor Yellow }
function Write-Info([string]$Text) { Write-Host "        $Text" }
function Pause-Key([string]$Text = 'Press Enter to continue') { [void](Read-Host "    $Text") }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsExe([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    $bytes = [IO.File]::ReadAllBytes($Path)
    return ($bytes.Length -gt 2 -and $bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A)  # "MZ"
}

function Test-IsZip([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    $bytes = [IO.File]::ReadAllBytes($Path)
    return ($bytes.Length -gt 2 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B)  # "PK"
}

function Get-Tool([hashtable]$Tool) {
    # Downloads a tool from its official source. Falls back to a manual download if that fails.
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    $out = Join-Path $TempDir $Tool.File
    $isZip = $Tool.File.EndsWith('.zip')

    try {
        Write-Info "Downloading $($Tool.Name)..."
        # SourceForge serves the real file to non-browser user agents
        Invoke-WebRequest -Uri $Tool.Url -OutFile $out -UseBasicParsing -UserAgent 'Wget/1.21' -MaximumRedirection 10
    } catch {
        Write-Warn2 "Download failed: $($_.Exception.Message)"
    }

    $valid = if ($isZip) { Test-IsZip $out } else { Test-IsExe $out }
    if ($valid) { Write-Ok "$($Tool.Name) downloaded"; return $out }

    Write-Warn2 "Could not fetch $($Tool.Name) automatically."
    Write-Info  "Opening the official page. Download it, then drag the file into this window."
    Start-Process $Tool.Page
    while ($true) {
        $manual = (Read-Host '    Path to the downloaded file').Trim('"', ' ')
        $ok = if ($isZip) { Test-IsZip $manual } else { Test-IsExe $manual }
        if ($ok) { return $manual }
        Write-Warn2 'That does not look like the right file. Try again.'
    }
}

function Get-CableRenderDevice {
    # Finds the VB-CABLE playback endpoint ("CABLE Input") in the registry and returns its GUID.
    $root = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render'
    if (-not (Test-Path $root)) { return $null }
    $connNameKey = '{a45c254e-df1c-4efd-8020-67d146a850e0},2'
    $devNameKey  = '{b3f8fa53-0004-438e-9003-51a46e139bfc},6'

    foreach ($dev in Get-ChildItem $root) {
        $props = Join-Path $dev.PSPath 'Properties'
        if (-not (Test-Path $props)) { continue }
        $p = Get-ItemProperty $props -ErrorAction SilentlyContinue
        $conn = $p.$connNameKey
        $name = $p.$devNameKey
        $state = (Get-ItemProperty $dev.PSPath -ErrorAction SilentlyContinue).DeviceState
        if ($conn -eq 'CABLE Input' -and $name -like '*VB-Audio Virtual Cable*' -and $state -eq 1) {
            return [pscustomobject]@{ Guid = $dev.PSChildName; Connection = $conn; Device = $name }
        }
    }
    return $null
}

function Get-CurrentEqFile {
    # Keeps whatever EQ the user already pointed config.txt at
    if (-not (Test-Path $ConfigFile)) { return $null }
    foreach ($line in Get-Content $ConfigFile) {
        if ($line -match '^Include:\s+.*\\eq\\(.+\.txt)\s*$') { return $Matches[1] }
    }
    return $null
}

function Write-ProjectConfig([string]$Game = $DefaultGame, [string]$TuneVer = $DefaultTuneVer, [string]$PreFile = $DefaultPreFile, [string]$EqFile = $null) {
    $base = "$ProjectName\library\$Game\$TuneVer"
    $eqDir = Join-Path $LibraryDest "$Game\$TuneVer\eq"
    if (-not $EqFile) { $EqFile = Get-CurrentEqFile }
    if (-not $EqFile -or -not (Test-Path (Join-Path $eqDir $EqFile))) { $EqFile = $DefaultEqFile }
    if (-not (Test-Path (Join-Path $eqDir $EqFile))) { $EqFile = 'Flat_EQ.txt' }

    $cable = Get-CableRenderDevice
    if ($cable) {
        $deviceLine = "Device: $($cable.Connection) $($cable.Device) $($cable.Guid)"
    } else {
        Write-Warn2 'CABLE Input was not found, so the chain is not scoped to a device.'
        Write-Info  'It will apply to every device Equalizer APO is installed on. Re-run [1] after a restart to fix this.'
        $deviceLine = '# Device line missing - CABLE Input not found during setup'
    }

    if (Test-Path $ConfigFile) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item $ConfigFile (Join-Path $EapoConfig "config.backup-$stamp.txt")
    }

    $lines = @(
        "# ---- $ProjectName $Version ----"
        "# Order matters: pre, HeSuVi, EQ, post, boost"
        $deviceLine
        "# PRE HESUVI"
        "Include: $base\$PreFile"
        "# DO NOT REMOVE HESUVI #"
        "Include: HeSuVi\hesuvi.txt"
        "# EQ - your headphone file from the eq folder"
        "Include: $base\eq\$EqFile"
        "# POST HESUVI"
        "Include: $base\${Game}_${TuneVer}_post.txt"
        "# OUTPUT BOOST"
        "Include: $ProjectName\boost.txt"
    )
    Set-Content -Path $ConfigFile -Value $lines -Encoding ASCII
    Write-Ok "config.txt written using $PreFile and $EqFile - previous one backed up"
}

function Copy-Library {
    if (-not (Test-Path $LibrarySrc)) {
        throw "library folder not found next to the script. Keep Install-CleanTune.ps1 and library\ together."
    }
    New-Item -ItemType Directory -Force -Path $ProjectDir | Out-Null
    if (Test-Path $LibraryDest) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = Join-Path $ProjectDir "library.backup-$stamp"
        Move-Item $LibraryDest $backup
        Write-Info "Old library backed up to $backup"
    }
    Copy-Item $LibrarySrc $LibraryDest -Recurse
    if (-not (Test-Path $BoostFile)) {
        Set-Content -Path $BoostFile -Encoding ASCII -Value @(
            '# Output boost - applied last on the chain. 0 dB means off.'
            '# Raise slowly. Too much will clip.'
            'Preamp: 0 dB'
        )
    }
    Write-Ok "Library copied to $LibraryDest"
}

function New-Shortcut([string]$Path, [string]$Target, [string]$Arguments = '') {
    $ws = New-Object -ComObject WScript.Shell
    $s = $ws.CreateShortcut($Path)
    $s.TargetPath = $Target
    if ($Arguments) { $s.Arguments = $Arguments }
    $s.Save()
}

# ---------------------------------------------------------------------------
# Install steps
# ---------------------------------------------------------------------------
function Install-VBCable {
    Write-Step '1/7  VB-CABLE virtual audio cable'
    if (Get-CableRenderDevice) { Write-Ok 'Already installed - skipping'; return }

    $zip = Get-Tool $Downloads.VBCable
    $dest = Join-Path $TempDir 'vbcable'
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Expand-Archive $zip -DestinationPath $dest -Force
    $setup = Get-ChildItem $dest -Recurse -Filter 'VBCABLE_Setup_x64.exe' | Select-Object -First 1
    if (-not $setup) { throw 'VBCABLE_Setup_x64.exe not found in the zip.' }

    Write-Info 'Installing driver. Windows may ask you to trust VB-Audio - click Install.'
    Start-Process $setup.FullName -ArgumentList '-i', '-h' -Wait
    Start-Sleep -Seconds 3
    if (Get-CableRenderDevice) { Write-Ok 'VB-CABLE installed' }
    else { Write-Warn2 'VB-CABLE installed but not visible yet. A restart usually fixes this.' }
}

function Install-EAPO {
    Write-Step '2/7  Equalizer APO'
    if (Test-Path (Join-Path $EapoDir 'Configurator.exe')) {
        Write-Ok 'Already installed - skipping download'
    } else {
        $exe = Get-Tool $Downloads.EAPO
        Write-Info 'Installing silently...'
        Start-Process $exe -ArgumentList '/S' -Wait
        if (-not (Test-Path (Join-Path $EapoDir 'Configurator.exe'))) { throw 'Equalizer APO did not install.' }
        Write-Ok 'Equalizer APO installed'
    }

    Write-Host ''
    Write-Host '    ACTION NEEDED' -ForegroundColor Yellow
    Write-Info 'The Configurator will open now.'
    Write-Info '  1. On the Playback devices tab, tick  CABLE Input  only'
    Write-Info '  2. Leave your headphones UNTICKED'
    Write-Info '  3. Click OK and let it restart the audio service'
    Pause-Key 'Press Enter to open the Configurator'
    Start-Process (Join-Path $EapoDir 'Configurator.exe') -Wait
}

function Install-HeSuVi {
    Write-Step '3/7  HeSuVi virtual surround'
    if (Test-Path (Join-Path $EapoConfig 'HeSuVi\hesuvi.txt')) { Write-Ok 'Already installed - skipping'; return }

    $exe = Get-Tool $Downloads.HeSuVi
    Write-Info 'Installing. If an installer window appears, accept the defaults.'
    Start-Process $exe -ArgumentList '/S' -Wait
    if (Test-Path (Join-Path $EapoConfig 'HeSuVi\hesuvi.txt')) { Write-Ok 'HeSuVi installed' }
    else { Write-Warn2 'HeSuVi files not found. Run the HeSuVi installer by hand, then re-run [1].' }
}

function Install-ReaPlugs {
    Write-Step '4/7  ReaPlugs compressor for the No Gun tune'
    if (Test-Path (Join-Path $ReaPlugsDir 'reaxcomp-standalone.dll')) { Write-Ok 'Already installed - skipping'; return }
    $exe = Get-Tool $Downloads.ReaPlugs
    Write-Info 'Installing silently...'
    Start-Process $exe -ArgumentList '/S', "/D=$ReaPlugsDir" -Wait
    if (Test-Path (Join-Path $ReaPlugsDir 'reaxcomp-standalone.dll')) { Write-Ok 'ReaPlugs installed' }
    else { Write-Warn2 "ReaPlugs not found in $ReaPlugsDir. The No Gun tune needs it there." }
}

function Install-Library {
    Write-Step '5/7  Tune library'
    Copy-Library
}

function Install-Config {
    Write-Step '6/7  Equalizer APO config.txt'
    Write-ProjectConfig
}

function Install-Shortcuts {
    Write-Step '7/7  Shortcuts'
    $editor = Join-Path $EapoDir 'Editor.exe'
    if (Test-Path $editor) { New-Shortcut (Join-Path $ProjectDir 'E-APO Configuration Editor.lnk') $editor }
    $hesuvi = Join-Path $EapoConfig 'HeSuVi\HeSuVi.exe'
    if (Test-Path $hesuvi) {
        New-Shortcut (Join-Path $ProjectDir 'HeSuVi.lnk') $hesuvi
        # One-click preset that loads the atmos HRIR that ships with HeSuVi
        New-Shortcut (Join-Path $ProjectDir 'HeSuVi - CleanTune Atmos.lnk') $hesuvi '-v atmos'
    }
    Set-Content (Join-Path $ProjectDir 'squig.link.url') -Encoding ASCII -Value "[InternetShortcut]`r`nURL=https://squig.link/"
    $desktop = [Environment]::GetFolderPath('Desktop')
    New-Shortcut (Join-Path $desktop "$ProjectName.lnk") $ProjectDir
    Write-Ok "Desktop shortcut to the $ProjectName folder created"
}

function Show-ManualSteps {
    Write-Host ''
    Write-Host '  ===================== MANUAL STEPS =====================' -ForegroundColor Yellow
    Write-Info ''
    Write-Info 'A. Set CABLE Input to 7.1'
    Write-Info '   Playback tab > CABLE Input > Configure > 7.1 Surround > Next until Finish'
    Write-Info '   Then Properties > Advanced > 24 bit, 48000 Hz'
    Write-Info ''
    Write-Info 'B. Send the cable to your headphones'
    Write-Info '   Recording tab > CABLE Output > Properties > Listen'
    Write-Info '   Tick "Listen to this device" and pick your headphones'
    Write-Info '   Advanced tab > 24 bit, 48000 Hz'
    Write-Info ''
    Write-Info 'C. Open "HeSuVi - CleanTune Atmos" in the CleanTune folder to load the surround preset'
    Write-Info ''
    Write-Info 'D. In game, read library\WZ-BO7_SETTINGS.md'
    Write-Info ''
    Pause-Key 'Press Enter to open the Sound panel'
    Start-Process 'control.exe' -ArgumentList 'mmsys.cpl,,0'
}

function Invoke-Install {
    Install-VBCable
    Install-EAPO
    Install-HeSuVi
    Install-ReaPlugs
    Install-Library
    Install-Config
    Install-Shortcuts
    Show-ManualSteps
    Write-Host "`n  Install finished." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Other menu actions
# ---------------------------------------------------------------------------
function Invoke-SwitchVariation {
    $dir = Join-Path $LibraryDest "$DefaultGame\$DefaultTuneVer"
    $pres = Get-ChildItem $dir -Filter '*_pre*.txt' -ErrorAction SilentlyContinue
    if (-not $pres) { Write-Warn2 'No tunes found. Run [1] first.'; return }
    Write-Host ''
    for ($i = 0; $i -lt $pres.Count; $i++) { Write-Host "    [$($i+1)] $($pres[$i].Name)" }
    $pick = Read-Host '    Pick a variation'
    $n = 0
    if ([int]::TryParse($pick, [ref]$n) -and $n -ge 1 -and $n -le $pres.Count) {
        Write-ProjectConfig -PreFile $pres[$n-1].Name
        Write-Ok "Now using $($pres[$n-1].Name). Equalizer APO reloads it live."
    } else { Write-Warn2 'Cancelled' }
}

function Invoke-Remove {
    Write-Step "Removing $ProjectName"
    $backups = Get-ChildItem $EapoConfig -Filter 'config.backup-*.txt' -ErrorAction SilentlyContinue | Sort-Object Name
    if ($backups) {
        Copy-Item $backups[0].FullName $ConfigFile -Force
        Write-Ok "Restored your original config.txt from $($backups[0].Name)"
    }
    if (Test-Path $ProjectDir) { Remove-Item $ProjectDir -Recurse -Force; Write-Ok "$ProjectName folder removed" }
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) "$ProjectName.lnk"
    if (Test-Path $lnk) { Remove-Item $lnk -Force }
    Write-Info 'VB-CABLE, Equalizer APO, HeSuVi and ReaPlugs are left installed.'
    Write-Info 'Remove them from Settings > Apps if you want them gone too.'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    Write-Host 'Run this in Windows PowerShell 5.1, not PowerShell 7.' -ForegroundColor Red
    exit 1
}
if (-not [Environment]::Is64BitOperatingSystem) {
    Write-Host 'Only 64-bit Windows is supported.' -ForegroundColor Red
    exit 1
}
if (-not (Test-Admin)) {
    Write-Host 'Right-click Windows PowerShell and choose Run as administrator, then try again.' -ForegroundColor Red
    exit 1
}

while ($true) {
    Clear-Host
    Write-Host ''
    Write-Host "   $ProjectName  $Version" -ForegroundColor Cyan
    Write-Host '   Warzone / Black Ops 7 audio tuning'
    Write-Host ''
    Write-Host '   [1] Install'
    Write-Host '   [2] Refresh tune library'
    Write-Host '   [3] Switch tune variation'
    Write-Host '   [4] Remove CleanTune and restore original config'
    Write-Host '   [Q] Quit'
    Write-Host ''
    $choice = Read-Host '   Choose'
    try {
        switch ($choice.ToUpper()) {
            '1' { Invoke-Install }
            '2' { Copy-Library }
            '3' { Invoke-SwitchVariation }
            '4' { Invoke-Remove }
            'Q' { exit 0 }
            default { }
        }
    } catch {
        Write-Host "`n    ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    Pause-Key
}
