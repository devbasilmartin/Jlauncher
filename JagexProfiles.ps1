<#
.SYNOPSIS
    Swap Jagex Launcher login sessions between saved profiles (one Jagex account per profile).

.DESCRIPTION
    The Jagex Launcher keeps a single signed-in session in the current Windows user's
    AppData folders and registry. This script saves that session state into a named
    profile and restores another one, so switching accounts is one click instead of a
    full sign-in with 2FA.

    It never touches gameplay, never types passwords, and never talks to Jagex servers.
    It only moves the launcher's own local files around while the launcher is closed.

.EXAMPLE
    .\JagexProfiles.ps1 discover          # show which Jagex data locations exist on this PC
    .\JagexProfiles.ps1 save Ironman      # store the session that is signed in right now as "Ironman"
    .\JagexProfiles.ps1 new Pure          # store current session, then open the launcher signed out
    .\JagexProfiles.ps1 switch Ironman    # swap to "Ironman" and open the launcher
    .\JagexProfiles.ps1 list
    .\JagexProfiles.ps1 shortcut Ironman  # put a one-click "Jagex - Ironman" shortcut on the desktop
    .\JagexProfiles.ps1 delete Pure
#>
[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('list', 'save', 'new', 'switch', 'delete', 'shortcut', 'discover')]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Name,

    # Don't start the launcher after switching.
    [switch]$NoLaunch,

    # Report errors in a pop-up window (used by desktop shortcuts, which have no console).
    [switch]$Popup,

    # switch/new: throw away an unsaved live session instead of refusing.
    [switch]$Discard
)

$ErrorActionPreference = 'Stop'

# --- Configuration -------------------------------------------------------------------
# Session locations to swap. Run "discover" and adjust these if your install differs.
# Do NOT add C:\ProgramData\Jagex: that holds the shared game installs, not logins.
$SessionDirs = @(
    (Join-Path $env:APPDATA 'JagexLauncher'),
    (Join-Path $env:LOCALAPPDATA 'JagexLauncher')
)
$SwapRegistry   = $true
$RegistryKey    = 'HKCU\Software\Jagex\Jagex Launcher'
$LauncherExe    = Join-Path ${env:ProgramFiles(x86)} 'Jagex Launcher\JagexLauncher.exe'
$LauncherProcs  = @('JagexLauncher')

# Saved sessions are live login tokens. Keep them in LocalAppData, which is private to
# this Windows user and not synced by OneDrive (unlike Desktop/Documents).
$StorageRoot    = Join-Path $env:LOCALAPPDATA 'JagexProfiles'
$ActiveFile     = Join-Path $StorageRoot 'active.txt'
# -------------------------------------------------------------------------------------

function Fail([string]$Message) { throw $Message }

function Assert-Name {
    if ([string]::IsNullOrWhiteSpace($Name)) { Fail "The '$Command' command needs a profile name." }
    if ($Name -notmatch '^[A-Za-z0-9 _-]{1,40}$') {
        Fail "Profile names may only use letters, digits, spaces, '_' and '-' (max 40 chars)."
    }
}

function Get-ProfileDir([string]$ProfileName) { Join-Path $StorageRoot "Profile_$ProfileName" }

function Get-ProfileNames {
    if (-not (Test-Path $StorageRoot)) { return @() }
    Get-ChildItem -Path $StorageRoot -Directory -Filter 'Profile_*' |
        Where-Object { $_.Name -notlike '*.tmp' } |
        ForEach-Object { $_.Name.Substring('Profile_'.Length) }
}

function Get-ActiveProfile {
    if (Test-Path $ActiveFile) { (Get-Content -Path $ActiveFile -Raw).Trim() } else { '' }
}

function Set-ActiveProfile([string]$ProfileName) {
    if ($ProfileName) { Set-Content -Path $ActiveFile -Value $ProfileName -Encoding UTF8 }
    elseif (Test-Path $ActiveFile) { Remove-Item -Path $ActiveFile -Force }
}

function Test-LiveSession {
    foreach ($dir in $SessionDirs) { if (Test-Path $dir) { return $true } }
    return ($SwapRegistry -and (Test-Path "Registry::$RegistryKey"))
}

# Mirror a directory with robocopy (copies hidden/system files, removes extras at the target).
function Copy-Mirror([string]$Source, [string]$Destination) {
    $null = robocopy $Source $Destination /MIR /COPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { Fail "Copying '$Source' to '$Destination' failed (robocopy exit $LASTEXITCODE)." }
}

function Stop-Launcher {
    $procs = Get-Process -Name $LauncherProcs -ErrorAction SilentlyContinue
    if (-not $procs) { return }
    Write-Host 'Closing the Jagex Launcher...' -ForegroundColor Yellow
    $procs | ForEach-Object { [void]$_.CloseMainWindow() }
    $procs | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
    $procs = Get-Process -Name $LauncherProcs -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force
        $procs | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
    }
}

# Copy the live session into a profile. Writes to a temp folder first so a failure
# never damages the profile's previous good copy.
function Save-LiveSession([string]$ProfileName) {
    $final = Get-ProfileDir $ProfileName
    $temp = "$final.tmp"
    if (Test-Path $temp) { Remove-Item -Path $temp -Recurse -Force }
    New-Item -Path $temp -ItemType Directory -Force | Out-Null

    for ($i = 0; $i -lt $SessionDirs.Count; $i++) {
        if (Test-Path $SessionDirs[$i]) { Copy-Mirror $SessionDirs[$i] (Join-Path $temp "dir$i") }
    }
    if ($SwapRegistry -and (Test-Path "Registry::$RegistryKey")) {
        $null = reg export $RegistryKey (Join-Path $temp 'registry.reg') /y
        if ($LASTEXITCODE -ne 0) { Fail "Exporting registry key '$RegistryKey' failed." }
    }

    if (Test-Path $final) { Remove-Item -Path $final -Recurse -Force }
    Rename-Item -Path $temp -NewName (Split-Path $final -Leaf)
}

# Remove every trace of the live session so the next profile starts clean.
function Clear-LiveSession {
    foreach ($dir in $SessionDirs) {
        if (Test-Path $dir) { Remove-Item -Path $dir -Recurse -Force }
    }
    if ($SwapRegistry -and (Test-Path "Registry::$RegistryKey")) {
        Remove-Item -Path "Registry::$RegistryKey" -Recurse -Force
    }
}

function Restore-Session([string]$ProfileName) {
    $src = Get-ProfileDir $ProfileName
    for ($i = 0; $i -lt $SessionDirs.Count; $i++) {
        $saved = Join-Path $src "dir$i"
        if (Test-Path $saved) { Copy-Mirror $saved $SessionDirs[$i] }
    }
    $reg = Join-Path $src 'registry.reg'
    if ($SwapRegistry -and (Test-Path $reg)) {
        $null = reg import $reg 2>&1
        if ($LASTEXITCODE -ne 0) { Fail "Importing registry for '$ProfileName' failed." }
    }
}

# Save whatever is live before replacing it. Refuses if the live session isn't known
# to belong to a profile, because overwriting it would sign that account out for good.
function Save-CurrentBeforeLeaving {
    $active = Get-ActiveProfile
    if ($active) {
        Write-Host "Saving current session to '$active'..." -ForegroundColor Cyan
        Save-LiveSession $active
    }
    elseif ((Test-LiveSession) -and -not $Discard) {
        Fail ("The launcher has a signed-in session that isn't saved to any profile. " +
              "Run 'save <name>' first, or add -Discard to throw it away.")
    }
}

function Start-Launcher {
    if ($NoLaunch) { return }
    if (-not (Test-Path $LauncherExe)) { Fail "Jagex Launcher not found at '$LauncherExe'. Edit `$LauncherExe in the script." }
    Start-Process -FilePath $LauncherExe
}

try {
    if (-not (Test-Path $StorageRoot)) { New-Item -Path $StorageRoot -ItemType Directory | Out-Null }

    switch ($Command) {
        'list' {
            $active = Get-ActiveProfile
            $names = @(Get-ProfileNames)
            if ($names.Count -eq 0) { Write-Host "No profiles yet. Sign in with the launcher, then run: save <name>" }
            foreach ($n in $names) {
                if ($n -eq $active) { Write-Host "* $n (active)" -ForegroundColor Green } else { Write-Host "  $n" }
            }
        }

        'save' {
            Assert-Name
            if (-not (Test-LiveSession)) { Fail 'There is no launcher session to save. Sign in with the launcher first.' }
            Stop-Launcher
            Save-LiveSession $Name
            Set-ActiveProfile $Name
            Write-Host "Saved the current session as '$Name'." -ForegroundColor Green
        }

        'new' {
            Assert-Name
            if (Test-Path (Get-ProfileDir $Name)) { Fail "Profile '$Name' already exists. Use 'switch $Name'." }
            Stop-Launcher
            Save-CurrentBeforeLeaving
            Set-ActiveProfile ''
            Clear-LiveSession
            Set-ActiveProfile $Name
            Write-Host "Started '$Name' signed out. Sign in, and it will be saved the next time you switch." -ForegroundColor Green
            Start-Launcher
        }

        'switch' {
            Assert-Name
            if (-not (Test-Path (Get-ProfileDir $Name))) { Fail "No profile named '$Name'. Use 'new $Name' to create it." }
            Stop-Launcher
            if ((Get-ActiveProfile) -ne $Name) {
                Save-CurrentBeforeLeaving
                # Mark nothing active while live state is half-swapped, so a failure here
                # can never be saved over a good profile on the next run.
                Set-ActiveProfile ''
                Clear-LiveSession
                Restore-Session $Name
                Set-ActiveProfile $Name
            }
            Write-Host "Switched to '$Name'." -ForegroundColor Green
            Start-Launcher
        }

        'delete' {
            Assert-Name
            if ((Get-ActiveProfile) -eq $Name) { Fail "'$Name' is active. Switch to another profile before deleting it." }
            $dir = Get-ProfileDir $Name
            if (-not (Test-Path $dir)) { Fail "No profile named '$Name'." }
            Remove-Item -Path $dir -Recurse -Force
            Write-Host "Deleted profile '$Name'." -ForegroundColor Green
        }

        'shortcut' {
            Assert-Name
            $desktop = [Environment]::GetFolderPath('Desktop')
            $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop "Jagex - $Name.lnk"))
            $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" switch `"$Name`" -Popup"
            if (Test-Path $LauncherExe) { $lnk.IconLocation = "$LauncherExe,0" }
            $lnk.Save()
            Write-Host "Created desktop shortcut 'Jagex - $Name'." -ForegroundColor Green
        }

        'discover' {
            Write-Host 'Folders and registry keys with "Jagex" in the name:' -ForegroundColor Cyan
            foreach ($root in @($env:APPDATA, $env:LOCALAPPDATA, $env:ProgramData)) {
                if (-not $root -or -not (Test-Path $root)) { continue }
                Get-ChildItem -Path $root -Directory -Filter '*Jagex*' -ErrorAction SilentlyContinue |
                    ForEach-Object { Write-Host "  $($_.FullName)" }
            }
            Get-ChildItem -Path 'HKCU:\Software' -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -like '*Jagex*' } |
                ForEach-Object { Write-Host "  $($_.Name)"; Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $($_.Name)" } }
            Write-Host ''
            Write-Host 'Currently configured to swap:' -ForegroundColor Cyan
            foreach ($dir in $SessionDirs) { Write-Host ("  [{0}] {1}" -f $(if (Test-Path $dir) { 'found' } else { 'missing' }), $dir) }
            if ($SwapRegistry) {
                Write-Host ("  [{0}] {1}" -f $(if (Test-Path "Registry::$RegistryKey") { 'found' } else { 'missing' }), $RegistryKey)
            }
            Write-Host ("  [{0}] launcher: {1}" -f $(if (Test-Path $LauncherExe) { 'found' } else { 'missing' }), $LauncherExe)
        }
    }
}
catch {
    if ($Popup) {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Jagex Profiles', 'OK', 'Error')
    }
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
