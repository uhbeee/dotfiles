<#
.SYNOPSIS
    Debloats a Windows 11 machine: pinned Win11Debloat engine run, vendor
    (Dell/HP) cleanup pass, and two registry/OneDrive extras, wrapped in a
    guardrail baseline/postcheck that protects WSL, remote access, updates
    and Defender.

.DESCRIPTION
    Modes:
      (default)     Full run. Preflight, guardrail baseline, restore-point
                    guarantee, engine, vendor pass, extras, guardrail
                    postcheck. Exits 0 only when every phase is green and
                    no guardrail invariant weakened.
      -Audit        Read-only report of targets present (apps vs the
                    effective removal set, vendor footprint, extras state,
                    guardrail services). Writes nothing at all - not even
                    a transcript; redirect the output to keep a record.
      -PostReboot   The runbook's post-reboot verification: checks the
                    guardrail invariants against the pending baseline and
                    archives it on success.

    The effective app-removal set is the pinned engine release's default
    selection (Config/Apps.json entries with SelectedByDefault=true) PLUS
    the entries in apps.txt next to this script. The engine's -Apps flag
    replaces its default selection, so this script computes the union
    itself and passes the combined list. Audit and post-run outcome checks
    additionally cover the packages the exercised engine flags remove on
    their own (gaming, HP, Bing, Copilot, widgets).

    Guardrail contract: the script never removes or demotes hns, WinNAT,
    vmcompute, WslService, sshd, wuauserv, WinDefend. Presence and
    StartType are snapshotted to a baseline before mutation and re-checked
    on every exit path; any weakening fails the run. Inspection is fail
    closed: if service, package or task state cannot be read, that is a
    failure, never treated as absence.

    Every destructive action traces to the exercised prior art recorded in
    the dotfiles plan archive (Win11Debloat flags, vendor-audit.ps1,
    vendor-remove.ps1, D6 notes).

.NOTES
    Supported context (aborts otherwise, before any file write): Windows 11
    (build 22000+), Windows PowerShell 5.1 (Desktop edition; the engine's
    app removal does not work under PowerShell 7), elevated, invoked by the
    machine's intended desktop user (per-user settings apply to the
    invoker; the script cannot verify this - see README). Single-user
    machines only.

    The script never reboots the machine; it reports when a reboot is
    required.
#>
[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(ParameterSetName = 'Audit')]
    [switch]$Audit,

    [Parameter(ParameterSetName = 'PostReboot')]
    [switch]$PostReboot
)

$ErrorActionPreference = 'Stop'

# --- Engine pin -------------------------------------------------------------
# Exact upstream release of Raphire/Win11Debloat. Never "latest". Bumping the
# pin means: update the tag, both hashes AND the embedded pin data below,
# re-verify apps.txt coverage and the -Apps semantics against the new
# release, and re-run the E2E validation. Run mode cross-checks the embedded
# pin data against the hash-verified payload and aborts on any mismatch, so
# an incomplete bump cannot run.
$EngineTag            = '2026.08.24'
$EngineZipUrl         = "https://github.com/Raphire/Win11Debloat/archive/refs/tags/$EngineTag.zip"
$EngineScriptSha256   = '1ACE81FC73C227F403D8F20A86D7EB0FA7F34985A017379BF141E04941D2CAAD'
$EngineAppsJsonSha256 = 'ACEF5D6F67A6AB62F96205C84E7FE365D025732C7BA8BA6BC91490ECE5B1121B'

# Exercised engine flag set (the behavior contract; -Apps carries the computed
# union of the engine defaults and apps.txt, see Get-RemovalInventory).
$EngineFlags = @(
    '-Silent', '-CreateRestorePoint',
    '-RemoveApps', '-RemoveHPApps', '-RemoveGamingApps',
    '-DisableTelemetry', '-DisableCopilot', '-DisableRecall', '-DisableBing',
    '-DisableWidgets', '-SkipExplorerRestart'
)

# --- Embedded pin data ------------------------------------------------------
# Derived from the pinned release and part of the pin itself: audit mode is
# zero-write and works from these lists alone; run mode re-derives the same
# data from the hash-verified payload and aborts if the two disagree.

# Config/Apps.json entries with SelectedByDefault=true at the pinned tag
# (the engine's default selection, 84 identifiers).
$EnginePinnedDefaultApps = @(
    '4DF9E0F8.Netflix', 'ACGMediaPlayer', 'ActiproSoftwareLLC',
    'AdobeSystemsIncorporated.AdobePhotoshopExpress', 'Amazon.com.Amazon',
    'AmazonVideo.PrimeVideo', 'Asphalt8Airborne', 'AutodeskSketchBook',
    'BytedancePte.Ltd.TikTok', 'CaesarsSlotsFreeCasino', 'Clipchamp.Clipchamp',
    'COOKINGFEVER', 'CyberLinkMediaSuiteEssentials', 'Disney.37853FC22B2CE',
    'DisneyMagicKingdoms', 'DrawboardPDF', 'Duolingo-LearnLanguagesforFree',
    'EclipseManager', 'FACEBOOK.FACEBOOK', 'Facebook.Instagram',
    'FarmVille2CountryEscape', 'flaregamesGmbH.RoyalRevolt', 'Flipboard',
    'HiddenCity', 'HULULLC.HULUPLUS', 'iHeartRadio', 'king.com.BubbleWitch3Saga',
    'king.com.CandyCrushSaga', 'king.com.CandyCrushSodaSaga', 'LinkedInforWindows',
    'MarchofEmpires', 'Microsoft.3DBuilder', 'Microsoft.549981C3F5F10',
    'Microsoft.BingFinance', 'Microsoft.BingFoodAndDrink',
    'Microsoft.BingHealthAndFitness', 'Microsoft.BingNews', 'Microsoft.BingSports',
    'Microsoft.BingTranslator', 'Microsoft.BingTravel', 'Microsoft.BingWeather',
    'Microsoft.Getstarted', 'Microsoft.Messaging', 'Microsoft.Microsoft3DViewer',
    'Microsoft.MicrosoftJournal', 'Microsoft.MicrosoftOfficeHub',
    'Microsoft.MicrosoftPowerBIForWindows', 'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MicrosoftStickyNotes', 'Microsoft.MixedReality.Portal',
    'Microsoft.NetworkSpeedTest', 'Microsoft.News', 'Microsoft.Office.OneNote',
    'Microsoft.Office.Sway', 'Microsoft.OneConnect', 'Microsoft.PCManager',
    'Microsoft.PowerAutomateDesktop', 'Microsoft.Print3D', 'Microsoft.SkypeApp',
    'Microsoft.Todos', 'Microsoft.Windows.AIHub', 'Microsoft.Windows.DevHome',
    'Microsoft.WindowsAlarms', 'Microsoft.WindowsFeedbackHub',
    'Microsoft.WindowsMaps', 'Microsoft.WindowsSoundRecorder', 'Microsoft.XboxApp',
    'Microsoft.ZuneVideo', 'MicrosoftCorporationII.MicrosoftFamily',
    'MicrosoftCorporationII.QuickAssist', 'MicrosoftTeams', 'MSTeams',
    'NYTCrossword', 'OneCalendar', 'PandoraMediaInc', 'PhototasticCollage',
    'PicsArt-PhotoStudio', 'PolarrPhotoEditorAcademicEdition',
    'Sidia.LiveWallpaper', 'SlingTV', 'SpotifyAB.SpotifyMusic', 'TuneInRadio',
    'WinZipUniversal', 'XP9CXNGPPJ97XX'
)

# Config/Apps.json entries with SelectedByDefault=false at the pinned tag
# (58 identifiers; legal in apps.txt, not removed by default).
$EnginePinnedOptionalApps = @(
    'AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPConnectedMusic',
    'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPDesktopSupportUtilities',
    'AD2F1837.HPEasyClean', 'AD2F1837.HPFileViewer', 'AD2F1837.HPJumpStarts',
    'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager',
    'AD2F1837.HPPrinterControl', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPQuickDrop',
    'AD2F1837.HPQuickTouch', 'AD2F1837.HPRegistration', 'AD2F1837.HPSupportAssistant',
    'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPWelcome',
    'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'DellInc.DellDigitalDelivery',
    'DellInc.DellMobileConnect', 'DellInc.DellSupportAssistforPCs',
    'E046963F.LenovoCompanion', 'LenovoCompanyLimited.LenovoVantageService',
    'LGElectronics.LGMonitorApp', 'Microsoft.BingSearch', 'Microsoft.Edge',
    'Microsoft.GamingApp', 'Microsoft.GetHelp', 'Microsoft.M365Companions',
    'Microsoft.MSPaint', 'Microsoft.OneDrive', 'Microsoft.OutlookForWindows',
    'Microsoft.Paint', 'Microsoft.People', 'Microsoft.RemoteDesktop',
    'Microsoft.ScreenSketch', 'Microsoft.StartExperiencesApp', 'Microsoft.Whiteboard',
    'Microsoft.Windows.Photos', 'Microsoft.WindowsCalculator',
    'Microsoft.WindowsCamera', 'Microsoft.windowscommunicationsapps',
    'Microsoft.WindowsNotepad', 'Microsoft.WindowsStore', 'Microsoft.WindowsTerminal',
    'Microsoft.Xbox.TCUI', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay',
    'Microsoft.YourPhone', 'Microsoft.ZuneMusic', 'MicrosoftWindows.Client.WebExperience',
    'MicrosoftWindows.CrossDevice', 'Microsoft.WidgetsPlatformRuntime',
    'XPFFTQ037JWMHS'
)

# Config/Apps.json entries with RemovalMethod=WinGet at the pinned tag.
# Everything else removes (and is detected) as an AppX/provisioned package;
# these ids need the dedicated read-only detection below instead - the
# script never shells out to winget, because winget writes log files and
# `--accept-source-agreements` mutates source state, which would break
# audit's zero-mutation contract.
$EnginePinnedWinGetMethodApps = @(
    'Microsoft.Edge', 'Microsoft.OneDrive', 'XP9CXNGPPJ97XX', 'XPFFTQ037JWMHS'
)

# Read-only detection for WinGet-method identifiers that are Store product
# ids: the MSIX package name the product installs as. XP9CXNGPPJ97XX is the
# Copilot Store listing; the pinned engine's DisableCopilot removes the same
# app by both ids (Invoke-Changes.ps1), which is the evidence for the pair.
# XPFFTQ037JWMHS (Edge Store listing) is recorded for completeness but is
# never inspected today (optional-only). Microsoft.OneDrive has a dedicated
# registry/path check; the winget id Microsoft.Edge (win32 Edge) has no
# read-only mapping - putting it in apps.txt requires adding detection here
# first, or the inspection fails closed.
$StoreProductIdPackageNames = @{
    'XP9CXNGPPJ97XX' = 'Microsoft.Copilot'
    'XPFFTQ037JWMHS' = 'Microsoft.MicrosoftEdge.Stable'
}

# Packages the exercised flags remove outside the -Apps selection, hardcoded
# in the pinned release's Scripts/Features/Invoke-Changes.ps1. Included in
# audit and post-run outcome checks so a failed flag-driven removal cannot
# hide (Microsoft.Copilot is engine-hardcoded and not in Apps.json).
$EnginePinnedFlagTargets = @(
    # -RemoveGamingApps
    'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay',
    # -RemoveHPApps
    'AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts',
    'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager',
    'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant',
    'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop',
    'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities',
    'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic',
    'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome',
    'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl',
    # -DisableBing
    'Microsoft.BingSearch',
    # -DisableCopilot
    'Microsoft.Copilot', 'XP9CXNGPPJ97XX',
    # -DisableWidgets
    'Microsoft.StartExperiencesApp', 'MicrosoftWindows.Client.WebExperience',
    'Microsoft.WidgetsPlatformRuntime'
)

# The registry values the pinned -DisableCopilot feature writes
# (Regfiles/Disable_Copilot.reg at the pinned tag; in the supported context
# the engine imports it as-is, so HKCU is the invoking desktop user). The
# flag itself is dispatched only while a Copilot app target is outstanding
# - its removal path executes winget unconditionally - so the wrapper
# enforces the feature's policy side on every run as a verify-and-enforce
# backstop (the D6 pattern). App absence never implies policy compliance.
# Run mode cross-checks these values against the verified payload's reg
# file, so a pin bump cannot leave them stale.
$CopilotPolicyValues = @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowCopilotButton';     Value = 0 },
    @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot';          Name = 'TurnOffWindowsCopilot'; Value = 1 },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot';          Name = 'TurnOffWindowsCopilot'; Value = 1 }
)

# Aggregate failure lines the pinned engine prints (as warnings) while still
# exiting 0; any of these makes the wrapper run non-green.
$EngineFailurePatterns = @(
    'app removal\(s\) failed',
    'feature change\(s\) failed',
    'Unable to verify if all apps were uninstalled'
)

# --- On-machine state -------------------------------------------------------
$StateDir      = 'C:\ProgramData\dotfiles-debloat'
$TranscriptDir = Join-Path $StateDir 'transcripts'
$EngineDir     = Join-Path $StateDir 'engine'
$BaselinePath  = Join-Path $StateDir 'guardrail-baseline.json'

# --- Guardrail contract (D5) ------------------------------------------------
$GuardrailServices = @('hns', 'WinNAT', 'vmcompute', 'WslService', 'sshd', 'wuauserv', 'WinDefend')

# StartType strength for the "never weakened" invariant. Weakening = current
# strength below baseline strength (Automatic->Manual, Manual->Disabled, ...).
# Strengthening or runtime Status changes never violate.
$StartTypeStrength = @{
    'Boot' = 4; 'System' = 3; 'Auto' = 2; 'Automatic' = 2; 'Manual' = 1; 'Disabled' = 0
}

# --- Vendor pass definitions (distilled from prior-art) ---------------------
# Dispatch is by detected footprint, never by Win32_ComputerSystem.Manufacturer
# (logged only). A branch acts only on targets not already in the desired
# state; installed-but-disabled services are the desired end state.
#
# Three pattern layers, from wide to narrow:
#   1. $VendorInventoryPattern - the combined inventory probe. The first nine
#      alternatives are verbatim from prior-art/vendor-audit.ps1; the rest
#      add the prior-art disable-list service names (and an ^HP name prefix)
#      that only matched via DisplayName there. Everything it finds is
#      reported; hits no branch claims are reported as unattributed.
#   2. Per-branch attribution patterns (ProbePattern/ArpPattern/
#      ProbeTaskPattern) - which inventory hits a branch's report and
#      desired-state logic consider its own.
#   3. Removal predicates - what a branch destructively acts on, exactly as
#      exercised: task removal matches TaskName only (vendor-remove.ps1
#      step 6), HP tasks are probed and reported but never removed.
$VendorInventoryPattern = 'Dell|HP |Hewlett|SysInfo|TechHub|Analytics|Touchpoint|Omen|MyHP|SupportAssist|DDV|HotKeyServiceDSU|LanWlanWwanSwitchingServiceDSU|^HP'

$DellSupportAssistMsiCode  = '{A1FC489C-7909-4E08-9685-6C77BA2053DE}'
$DellRemediationBundle     = 'C:\ProgramData\Package Cache\{3563aa3a-c8ae-48d8-ab19-b1f359265295}\DellSupportAssistRemediationServiceInstaller.exe'
# Installed-state marker for the Remediation product (its ARP display name);
# the bundle uninstaller only runs while this is present - the cached
# installer existing on disk is not evidence the product is installed.
$DellRemediationArpPattern = 'Dell SupportAssist Remediation'

$VendorBranches = @(
    @{
        Vendor           = 'Dell'
        ProbePattern     = 'Dell|SupportAssist|DDV|TechHub'
        ArpPattern       = 'Dell'
        ProbeTaskPattern = 'Dell|SupportAssist|DDV|TechHub'
        RemoveTaskPattern = 'SupportAssist|Dell'
        DisableServices  = @('DDVCollectorSvcApi', 'DDVDataCollector', 'DDVRulesProcessor',
                             'Dell SupportAssist Remediation', 'DellClientManagementService',
                             'DellTechHub', 'SupportAssistAgent')
        AppxPattern      = '*Dell*'
    },
    @{
        Vendor           = 'HP'
        ProbePattern     = '^HP|HP |Hewlett|MyHP|Omen|Touchpoint|HotKeyServiceDSU|LanWlanWwanSwitchingServiceDSU'
        ArpPattern       = 'HP |Hewlett|MyHP|Omen'
        ProbeTaskPattern = '^HP|HP |Hewlett|MyHP|Omen|Touchpoint'
        RemoveTaskPattern = $null   # probe-only: no HP task removal was exercised
        DisableServices  = @('HPAppHelperCap', 'HPDiagsCap', 'HPNetworkCap', 'HPSysInfoCap',
                             'HotKeyServiceDSU', 'LanWlanWwanSwitchingServiceDSU')
        AppxPattern      = $null   # HP AppX removal is the engine's -RemoveHPApps
    }
)

$ArpRoots = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

# MSI-style uninstaller exit codes accepted as success: 0 (ok), 3010
# (ok, reboot required - the runbook reboots anyway), 1605 (product already
# absent, i.e. already in the desired state).
$AcceptableMsiExitCodes = @(0, 3010, 1605)

# --- D6 extras --------------------------------------------------------------
$SearchBoxPolicyKey   = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
$SearchBoxPolicyName  = 'DisableSearchBoxSuggestions'
$SearchBoxPolicyValue = 1


# Logging goes through Write-Host so function return values stay clean;
# PowerShell 5.1 transcription captures the information stream.
function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "== $Title =="
}

function Write-Action {
    # Every destructive action goes through here so transcripts stay greppable
    # for "did the run remove/disable/uninstall anything" (the rerun probe).
    param([string]$Message)
    $script:ActionCount++
    Write-Host "ACTION: $Message"
}


# ---------------------------------------------------------------------------
# Preflight (D11) - runs before any file write in every mode
# ---------------------------------------------------------------------------
function Test-Preflight {
    param([bool]$NeedsAppsTxt)

    $problems = @()

    $build = 0
    try {
        $build = [int](Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild)
    } catch {
        $problems += 'Unable to read the Windows build number; this does not look like a Windows machine.'
    }
    if ($build -gt 0 -and $build -lt 22000) {
        $problems += "Windows 11 (build 22000+) is required; this machine reports build $build."
    }

    if ($PSVersionTable.PSVersion -lt [Version]'5.1') {
        $problems += "Windows PowerShell 5.1+ is required; this session is $($PSVersionTable.PSVersion)."
    }
    if ($PSVersionTable.ContainsKey('PSEdition') -and $PSVersionTable.PSEdition -ne 'Desktop') {
        $problems += 'Windows PowerShell (Desktop edition, powershell.exe) is required; the engine''s app removal does not work under PowerShell 7 (pwsh).'
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $problems += 'An elevated (Administrator) session is required.'
    }

    if ($NeedsAppsTxt -and -not (Test-Path (Join-Path $PSScriptRoot 'apps.txt'))) {
        $problems += "apps.txt was not found next to this script ($PSScriptRoot). Fetch it from the same repo location as debloat.ps1."
    }

    return $problems
}

function Write-ContextReport {
    Write-Section 'CONTEXT'
    $build = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild
    Write-Host "Windows build:  $build"
    Write-Host "PowerShell:     $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    Write-Host "Invoking user:  $env:USERDOMAIN\$env:USERNAME (must be this machine's intended desktop user - per-user settings apply to the invoker)"
    $manufacturer = ''
    try { $manufacturer = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).Manufacturer } catch { }
    # Logged for the report only; vendor dispatch is by detected footprint.
    Write-Host "Manufacturer:   $manufacturer (report-only, never used for dispatch)"
    Write-Host "Engine pin:     Win11Debloat $EngineTag"
}


# ---------------------------------------------------------------------------
# Guardrail baseline and postcheck (D5)
# ---------------------------------------------------------------------------
function Get-GuardrailSnapshot {
    # Fail closed: an enumeration failure throws; it is never recorded as
    # "service absent". Absence is only concluded from a successful full
    # enumeration that does not contain the name.
    try {
        $services = @(Get-CimInstance Win32_Service -ErrorAction Stop)
        # WinNAT is a kernel driver, invisible to Win32_Service; the driver
        # class keeps its presence and StartType pinned too.
        $drivers = @(Get-CimInstance Win32_SystemDriver -ErrorAction Stop)
    } catch {
        throw "Unable to enumerate services/drivers for the guardrail snapshot (fail closed): $($_.Exception.Message)"
    }

    $snapshot = @()
    foreach ($name in $GuardrailServices) {
        $entry = $services | Where-Object { $_.Name -eq $name }
        if (-not $entry) {
            $entry = $drivers | Where-Object { $_.Name -eq $name }
        }
        if ($entry) {
            $snapshot += [PSCustomObject]@{
                Name      = $name
                Present   = $true
                StartType = [string]$entry.StartMode
                Status    = [string]$entry.State   # report-only, never an invariant
            }
        } else {
            $snapshot += [PSCustomObject]@{
                Name      = $name
                Present   = $false
                StartType = $null
                Status    = $null
            }
        }
    }
    return $snapshot
}

function ConvertTo-UtcDateTime {
    # Accepts the ISO string this script writes or an already-converted
    # DateTime (ConvertFrom-Json differs across PowerShell editions); throws
    # on anything unparseable.
    param($Value)
    if ($Value -is [DateTime]) { return $Value.ToUniversalTime() }
    return [DateTime]::Parse([string]$Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
}

function Test-BaselineContent {
    # Shared validity predicate for baseline JSON text; returns the parsed
    # object, or $null when it is empty, unparseable or structurally
    # invalid. Structural validity is strict, because an incomplete baseline
    # silently disables guardrail checks: there must be exactly one record
    # per guardrail service (all seven), Present must be a boolean, a
    # present service must carry a recognized StartType, and a
    # pending-verification baseline must carry a parseable GreenRunUtc (the
    # post-reboot gate compares it with boot time).
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
    $baseline = $null
    try { $baseline = $Raw | ConvertFrom-Json } catch { return $null }
    $valid = $baseline -and
        $baseline.PSObject.Properties['State'] -and
        ($baseline.State -in @('active', 'pending-verification')) -and
        $baseline.PSObject.Properties['Services']
    if (-not $valid) { return $null }

    $services = @($baseline.Services)
    if ($services.Count -ne $GuardrailServices.Count) { return $null }
    $names = @($services | ForEach-Object { [string]$_.Name })
    if ((($names | Sort-Object) -join ',') -ne (($GuardrailServices | Sort-Object) -join ',')) { return $null }

    foreach ($svc in $services) {
        if (-not ($svc.PSObject.Properties['Present'] -and $svc.Present -is [bool])) { return $null }
        if ($svc.Present) {
            if (-not ($svc.PSObject.Properties['StartType'] -and $StartTypeStrength.ContainsKey([string]$svc.StartType))) { return $null }
        }
    }

    if ($baseline.State -eq 'pending-verification') {
        if (-not $baseline.PSObject.Properties['GreenRunUtc']) { return $null }
        try { ConvertTo-UtcDateTime -Value $baseline.GreenRunUtc | Out-Null } catch { return $null }
    }

    return $baseline
}

function Read-Baseline {
    # Returns $null only when no baseline evidence exists at all. An
    # existing but empty/corrupt file is never treated as a first run: that
    # would let a rerun snapshot potentially damaged state as the new
    # baseline. A missing target with an orphaned .tmp next to it is an
    # interrupted first write: a valid .tmp is surfaced via
    # $script:BaselineFromOrphanTmp so the writing modes can finalize the
    # rename (audit only reports it); an invalid .tmp is refused.
    $script:BaselineFromOrphanTmp = $false
    $tmpPath = "$BaselinePath.tmp"

    if (-not (Test-Path $BaselinePath)) {
        if (-not (Test-Path $tmpPath)) { return $null }
        $baseline = Test-BaselineContent -Raw (Get-Content -Path $tmpPath -Raw)
        if (-not $baseline) {
            throw "No guardrail baseline exists, but an orphaned invalid baseline write does ($tmpPath). Refusing to treat this as a first run (D5: evidence is never erased). Inspect the file and the transcripts; remove it only after investigation."
        }
        $script:BaselineFromOrphanTmp = $true
        return $baseline
    }

    $baseline = Test-BaselineContent -Raw (Get-Content -Path $BaselinePath -Raw)
    if (-not $baseline) {
        throw "Guardrail baseline file $BaselinePath exists but is empty or invalid. Refusing to treat this as a first run (D5: evidence is never erased). Inspect the file and the transcripts, recover from $BaselinePath.bak (the previous version kept by the atomic update) or an archived copy, and only move it aside after investigation."
    }
    return $baseline
}

function Write-BaselineFile {
    # Atomic update: serialize to a temp file, then swap it in. When the
    # target exists, the swap is [IO.File]::Replace (the Win32 ReplaceFile
    # API - an atomic replacement that also keeps the previous version as
    # .bak); creation is a plain rename, which has no delete step to be
    # interrupted in. A crash mid-write can therefore never lose a valid
    # baseline: at worst it leaves an orphaned .tmp that Read-Baseline
    # recovers or refuses.
    param($Baseline)
    $tmpPath = "$BaselinePath.tmp"
    $Baseline | ConvertTo-Json -Depth 5 | Set-Content -Path $tmpPath -Encoding UTF8
    if (Test-Path $BaselinePath) {
        [System.IO.File]::Replace($tmpPath, $BaselinePath, "$BaselinePath.bak")
    } else {
        Move-Item -Path $tmpPath -Destination $BaselinePath
    }
}

function Complete-OrphanBaselineWrite {
    # Finalizes an interrupted first write (valid .tmp, no target) in the
    # modes that are allowed to write. Audit never calls this.
    if ($script:BaselineFromOrphanTmp) {
        Move-Item -Path "$BaselinePath.tmp" -Destination $BaselinePath
        $script:BaselineFromOrphanTmp = $false
        Write-Host "Guardrail baseline: recovered an orphaned interrupted write ($BaselinePath.tmp finalized to $BaselinePath)."
    }
}

function Get-OrCreateBaseline {
    # Lifecycle: active -> pending-verification -> archived (timestamped
    # rename by -PostReboot). A non-archived baseline is always reused, never
    # re-snapshotted, so a rerun cannot launder damage from a prior attempt.
    # A pending-verification baseline is demoted back to active when a new
    # run attempt starts: only this attempt ending green re-marks it pending,
    # so -PostReboot can never archive on the strength of an older green run
    # that a failed retry has since superseded.
    $existing = Read-Baseline
    if ($existing) {
        Complete-OrphanBaselineWrite
        if ($existing.State -eq 'pending-verification') {
            $existing.State = 'active'
            $existing.GreenRunUtc = $null
            Write-BaselineFile -Baseline $existing
            Write-Host "Guardrail baseline: reusing existing baseline (created $($existing.CreatedUtc)); demoted pending-verification -> active for this new attempt."
        } else {
            Write-Host "Guardrail baseline: reusing existing baseline (state: $($existing.State), created $($existing.CreatedUtc))."
        }
        return $existing
    }

    $baseline = [PSCustomObject]@{
        CreatedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        State       = 'active'
        GreenRunUtc = $null
        Services    = @(Get-GuardrailSnapshot)
    }
    Write-BaselineFile -Baseline $baseline
    Write-Host "Guardrail baseline: snapshotted fresh to $BaselinePath (state: active)."
    return $baseline
}

function Set-BaselinePending {
    # Green-run transition: only the lifecycle fields change; the snapshotted
    # service data is untouched and stays the single comparison baseline
    # until -PostReboot verifies and archives it.
    $baseline = Read-Baseline
    if (-not $baseline) { return }
    $baseline.State = 'pending-verification'
    $baseline.GreenRunUtc = (Get-Date).ToUniversalTime().ToString('o')
    Write-BaselineFile -Baseline $baseline
    Write-Host "Guardrail baseline: marked pending-verification (archive happens at the runbook's post-reboot verification)."
}

function Compare-Guardrail {
    # Returns violation strings. Invariants: a baseline-present service must
    # still be present, and StartType must not be weaker than baseline.
    param($BaselineServices)

    $violations = @()
    $current = Get-GuardrailSnapshot

    foreach ($base in $BaselineServices) {
        if (-not $base.Present) { continue }   # appearing later is never a violation
        $now = $current | Where-Object { $_.Name -eq $base.Name }
        if (-not $now.Present) {
            $violations += "Guardrail violation: service '$($base.Name)' was present at baseline and is now absent."
            continue
        }
        # Baseline StartTypes are guaranteed recognized by Test-BaselineContent;
        # an unrecognized live StartType means the invariant cannot be
        # verified, which fails closed as a violation.
        $baseStrength = $StartTypeStrength[[string]$base.StartType]
        $nowStrength  = $StartTypeStrength[[string]$now.StartType]
        if ($null -eq $baseStrength -or $null -eq $nowStrength) {
            $violations += "Guardrail violation: service '$($base.Name)' has an unrecognized StartType (baseline '$($base.StartType)', current '$($now.StartType)') - invariant cannot be verified (fail closed)."
            continue
        }
        if ($nowStrength -lt $baseStrength) {
            $violations += "Guardrail violation: service '$($base.Name)' StartType weakened from $($base.StartType) to $($now.StartType)."
        }
    }
    return $violations
}

function Write-GuardrailReport {
    param($BaselineServices)

    Write-Host ('{0,-12} {1,-8} {2,-10} {3,-10} {4}' -f 'Service', 'Present', 'StartType', 'Status', 'Baseline(StartType)')
    $current = Get-GuardrailSnapshot
    foreach ($now in $current) {
        $baseNote = 'n/a'
        if ($BaselineServices) {
            $base = $BaselineServices | Where-Object { $_.Name -eq $now.Name }
            if ($base) {
                if ($base.Present) { $baseNote = [string]$base.StartType } else { $baseNote = 'absent' }
            }
        }
        $present   = if ($now.Present) { 'yes' } else { 'no' }
        $startType = if ($null -ne $now.StartType) { $now.StartType } else { '-' }
        $status    = if ($null -ne $now.Status) { $now.Status } else { '-' }
        Write-Host ('{0,-12} {1,-8} {2,-10} {3,-10} {4}' -f $now.Name, $present, $startType, $status, $baseNote)
    }
}


# ---------------------------------------------------------------------------
# Recovery precondition: verified restore point (pre-mutation guarantee)
# ---------------------------------------------------------------------------
function Get-RecentRestorePoint {
    $points = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue)
    foreach ($p in $points) {
        $created = [System.Management.ManagementDateTimeConverter]::ToDateTime($p.CreationTime)
        if (((Get-Date) - $created) -le (New-TimeSpan -Hours 24)) {
            return [PSCustomObject]@{
                SequenceNumber = $p.SequenceNumber
                Description    = $p.Description
                Created        = $created
            }
        }
    }
    return $null
}

function Assert-RestorePoint {
    # This wrapper-level guarantee is authoritative: a verified point created
    # within the last 24 hours is reused (Windows throttles creation to one
    # per 24h anyway, so the engine's own -CreateRestorePoint no-oping inside
    # that window is expected); otherwise one is created and verified. No
    # usable point means abort before any destructive phase. A read failure
    # here is safe to treat as "none": the creation-then-verify path still
    # has to positively confirm a point or the run aborts pre-mutation.
    $existing = Get-RecentRestorePoint
    if ($existing) {
        Write-Host "Restore point: reusing #$($existing.SequenceNumber) '$($existing.Description)' created $($existing.Created) (within 24h)."
        return
    }

    try {
        Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction Stop
    } catch {
        Write-Host "Restore point: Enable-ComputerRestore reported: $($_.Exception.Message)"
    }

    Write-Host 'Restore point: none within 24h; creating one...'
    Checkpoint-Computer -Description 'dotfiles windows debloat' -RestorePointType 'MODIFY_SETTINGS'

    $created = Get-RecentRestorePoint
    if (-not $created) {
        throw 'Recovery precondition failed: no verified system restore point exists and one could not be created. Aborting before any destructive phase.'
    }
    Write-Host "Restore point: created and verified #$($created.SequenceNumber) '$($created.Description)' at $($created.Created)."
}


# ---------------------------------------------------------------------------
# Pinned engine payload (run mode only; audit works from embedded pin data)
# ---------------------------------------------------------------------------
function Test-EnginePayload {
    param([string]$Root)
    $ps1  = Join-Path $Root 'Win11Debloat.ps1'
    $json = Join-Path $Root 'Config\Apps.json'
    if (-not ((Test-Path $ps1) -and (Test-Path $json))) { return $false }
    $ps1Hash  = (Get-FileHash -Path $ps1 -Algorithm SHA256).Hash
    $jsonHash = (Get-FileHash -Path $json -Algorithm SHA256).Hash
    return ($ps1Hash -eq $EngineScriptSha256 -and $jsonHash -eq $EngineAppsJsonSha256)
}

function Get-EnginePayload {
    # Downloads the pinned release archive and verifies the two
    # behavior-bearing files by SHA-256 (GitHub source zips are not
    # hash-stable; the tagged file contents are). A verified cached payload
    # is reused, so reruns work offline.
    $root = Join-Path $EngineDir "Win11Debloat-$EngineTag"

    if (Test-EnginePayload -Root $root) {
        Write-Host "Engine: reusing verified payload at $root."
        return $root
    }

    if (Test-Path $root) {
        Write-Host 'Engine: cached payload failed verification; discarding and re-downloading.'
        Remove-Item -Path $root -Recurse -Force
    }

    $zipPath = Join-Path $EngineDir "Win11Debloat-$EngineTag.zip"
    New-Item -ItemType Directory -Path $EngineDir -Force | Out-Null
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Write-Host "Engine: downloading $EngineZipUrl ..."
    Invoke-WebRequest -UseBasicParsing -Uri $EngineZipUrl -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $EngineDir -Force

    if (-not (Test-EnginePayload -Root $root)) {
        throw "Engine payload at tag $EngineTag failed SHA-256 verification (expected Win11Debloat.ps1 $EngineScriptSha256, Config/Apps.json $EngineAppsJsonSha256). Upstream content changed under the tag or the download is corrupt; refusing to run it."
    }
    Write-Host "Engine: downloaded and verified payload at $root."
    return $root
}

function Get-RegFileDwordValues {
    # Minimal parser for the engine's .reg files: DWORD values grouped
    # under their [HKEY_...] sections. Only used to cross-check embedded
    # pin data against the payload, never to apply anything.
    param([string]$RegFilePath)
    $values = @()
    $section = $null
    foreach ($line in (Get-Content -Path $RegFilePath)) {
        $trim = $line.Trim()
        if ($trim -match '^\[(.+)\]$') { $section = $Matches[1]; continue }
        if ($section -and $trim -match '^"(.+)"=dword:([0-9A-Fa-f]{8})$') {
            $values += [PSCustomObject]@{ Key = $section; Name = $Matches[1]; Value = [Convert]::ToInt32($Matches[2], 16) }
        }
    }
    return $values
}

function Assert-PinDataConsistent {
    # Guards the pin bump discipline: the embedded pin data must equal what
    # the hash-verified payload says, or the bump was incomplete.
    param([string]$EngineRoot)

    $json = Get-Content -Path (Join-Path $EngineRoot 'Config\Apps.json') -Raw | ConvertFrom-Json
    $payloadDefaults = @()
    $payloadOptional = @()
    $payloadWinGet   = @()
    foreach ($app in $json.Apps) {
        $ids = @($app.AppId) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 }
        foreach ($id in $ids) {
            if ($app.SelectedByDefault) { $payloadDefaults += $id } else { $payloadOptional += $id }
            if ($app.RemovalMethod -eq 'WinGet') { $payloadWinGet += $id }
        }
    }

    $pairs = @(
        @{ Name = 'default selection';   Embedded = $EnginePinnedDefaultApps;      Payload = $payloadDefaults },
        @{ Name = 'optional selection';  Embedded = $EnginePinnedOptionalApps;     Payload = $payloadOptional },
        @{ Name = 'WinGet-method ids';   Embedded = $EnginePinnedWinGetMethodApps; Payload = $payloadWinGet }
    )
    foreach ($pair in $pairs) {
        $embedded = (@($pair.Embedded) | Sort-Object) -join ','
        $payload  = (@($pair.Payload)  | Sort-Object) -join ','
        if ($embedded -ne $payload) {
            throw "Embedded pin data ($($pair.Name)) does not match the verified payload at tag ${EngineTag}: the pin bump is incomplete. Update the embedded pin data in debloat.ps1 to match the release's Config/Apps.json."
        }
    }

    $regValues = @(Get-RegFileDwordValues -RegFilePath (Join-Path $EngineRoot 'Regfiles\Disable_Copilot.reg')) |
        ForEach-Object { '{0}|{1}|{2}' -f $_.Key, $_.Name, $_.Value }
    $embeddedPolicies = @($CopilotPolicyValues) | ForEach-Object {
        $hivePath = $_.Path -replace '^HKCU:\\', 'HKEY_CURRENT_USER\' -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\'
        '{0}|{1}|{2}' -f $hivePath, $_.Name, $_.Value
    }
    if (((@($embeddedPolicies) | Sort-Object) -join ';') -ne ((@($regValues) | Sort-Object) -join ';')) {
        throw "Embedded pin data (DisableCopilot policy values) does not match the verified payload's Regfiles/Disable_Copilot.reg at tag ${EngineTag}: the pin bump is incomplete. Update `$CopilotPolicyValues in debloat.ps1."
    }

    Write-Host 'Engine: embedded pin data matches the verified payload.'
}


# ---------------------------------------------------------------------------
# Effective removal set: engine defaults + apps.txt (D3 settlement)
# ---------------------------------------------------------------------------
function Get-AppsTxtEntries {
    $path = Join-Path $PSScriptRoot 'apps.txt'
    $entries = @()
    foreach ($line in (Get-Content -Path $path)) {
        $bare = ($line -split '#', 2)[0].Trim()
        if ($bare.Length -gt 0) { $entries += $bare }
    }
    return $entries
}

function Get-RemovalInventory {
    # The engine documents -Apps as SELECTING the removal list, not extending
    # its default selection, so the union is computed here from the embedded
    # pin data: EngineAppsArg (defaults + apps.txt) is what -Apps carries;
    # AuditIds additionally includes the flag-removed packages, and is what
    # audit and the post-run outcome check inspect. Every apps.txt identifier
    # must be covered by the pinned Apps.json (or a script-side handler);
    # anything else is a config error.
    $supported = @{}
    foreach ($id in ($EnginePinnedDefaultApps + $EnginePinnedOptionalApps)) { $supported[$id] = $true }

    $extras = @(Get-AppsTxtEntries)
    $unsupported = @($extras | Where-Object { -not $supported.ContainsKey($_) })
    if ($unsupported.Count -gt 0) {
        throw "apps.txt entries not supported by the pinned engine release ($EngineTag) and with no script-side handler: $($unsupported -join ', '). Remove them from apps.txt (with a comment saying why) or add a handler in this script."
    }

    $seen = @{}
    $engineAppsArg = @()
    foreach ($id in ($EnginePinnedDefaultApps + $extras)) {
        if (-not $seen.ContainsKey($id)) {
            $seen[$id] = $true
            $engineAppsArg += $id
        }
    }

    $auditIds = @($engineAppsArg)
    foreach ($id in $EnginePinnedFlagTargets) {
        if (-not $seen.ContainsKey($id)) {
            $seen[$id] = $true
            $auditIds += $id
        }
    }

    $winGet = @{}
    foreach ($id in $EnginePinnedWinGetMethodApps) { $winGet[$id] = $true }

    Write-Host "Effective removal set: $($EnginePinnedDefaultApps.Count) engine defaults + $($extras.Count) apps.txt entries = $($engineAppsArg.Count) unique -Apps identifiers ($($auditIds.Count) inspected including flag-removed packages)."
    return [PSCustomObject]@{
        EngineAppsArg = $engineAppsArg
        AuditIds      = $auditIds
        WinGetIds     = $winGet
    }
}

function Test-OneDrivePresent {
    # The classic (win32) OneDrive client is not an AppX package; detect it
    # via its uninstall registry entries and known install paths.
    $arpKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe'
    )
    foreach ($key in $arpKeys) {
        if (Test-Path $key) { return $true }
    }
    $paths = @(
        (Join-Path $env:ProgramFiles 'Microsoft OneDrive\OneDrive.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\OneDrive.exe')
    )
    if (${env:ProgramFiles(x86)}) {
        $paths += (Join-Path ${env:ProgramFiles(x86)} 'Microsoft OneDrive\OneDrive.exe')
    }
    foreach ($path in $paths) {
        if (Test-Path $path) { return $true }
    }
    return $false
}

function Get-OutstandingAppTargets {
    # Which inspected identifiers are still installed, from read-only
    # evidence only: AppX/provisioned enumeration, the dedicated OneDrive
    # registry/path check, and the embedded Store-product-id map. The
    # script never shells out to winget - winget writes log files and
    # accepts source agreements, which would break audit's zero-mutation
    # contract (and audit and the post-run check must use identical
    # detection so their reports are comparable). Fail closed: enumeration
    # failures throw, and a WinGet-method id with no read-only detection is
    # an inspection error, never assumed absent.
    param($Ids, $WinGetIds)

    try {
        $installedNames   = @(Get-AppxPackage -AllUsers -ErrorAction Stop | ForEach-Object { $_.Name })
        $provisionedNames = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | ForEach-Object { $_.PackageName })
    } catch {
        throw "Unable to enumerate installed/provisioned packages (fail closed): $($_.Exception.Message)"
    }
    $allPackageNames = $installedNames + $provisionedNames

    # Appx-method matching mirrors the pinned engine's Remove-AppxApp
    # exactly: '*<identifier>*' against installed package Names and
    # provisioned PackageNames - several defaults are name fragments
    # (HiddenCity, ACGMediaPlayer, ...) that only match this way. Applied
    # only to Appx-method ids, like the engine: WinGet-method ids live in
    # winget's namespace, where a substring match against package names
    # would claim targets the engine cannot remove.
    $testAppxPattern = {
        param($needle)
        $pattern = '*' + $needle + '*'
        foreach ($name in $allPackageNames) {
            if ($name -like $pattern) { return $true }
        }
        return $false
    }

    $outstanding = @()
    $errors = @()

    foreach ($id in @($Ids | Sort-Object)) {
        if ($id -eq 'Microsoft.OneDrive') {
            if (Test-OneDrivePresent) { $outstanding += $id }
            continue
        }
        if ($WinGetIds.ContainsKey($id)) {
            if ($StoreProductIdPackageNames.ContainsKey($id)) {
                if (& $testAppxPattern $StoreProductIdPackageNames[$id]) { $outstanding += $id }
            } else {
                $errors += "no read-only presence detection for WinGet-method target '$id' - add a package-name mapping in debloat.ps1 (fail closed)."
            }
            continue
        }
        if (& $testAppxPattern $id) {
            $outstanding += $id
        }
    }

    return [PSCustomObject]@{ Outstanding = $outstanding; Errors = $errors }
}


# ---------------------------------------------------------------------------
# Engine invocation
# ---------------------------------------------------------------------------
function Invoke-Engine {
    param([string]$EngineRoot, $Flags, $EffectiveSet)

    $enginePs1 = Join-Path $EngineRoot 'Win11Debloat.ps1'
    $engineArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $enginePs1) +
        $Flags + @('-Apps', ($EffectiveSet -join ','))

    Write-Host "Engine: invoking Win11Debloat $EngineTag with: $($Flags -join ' ') -Apps <$($EffectiveSet.Count) identifiers>"
    # Run in a child Windows PowerShell process: the engine Exits its host
    # session, restarts transcription and expects to own the console. Output
    # is echoed into this wrapper's transcript AND captured, because the
    # engine reports app/feature failures only as warnings while still
    # exiting 0 - those lines must make the run non-green.
    $captured = New-Object System.Collections.Generic.List[string]
    & powershell.exe @engineArgs 2>&1 | ForEach-Object {
        $text = [string]$_
        Write-Host $text
        $captured.Add($text)
    }
    $exitCode = $LASTEXITCODE

    $failureLines = @()
    foreach ($line in $captured) {
        foreach ($pattern in $EngineFailurePatterns) {
            if ($line -match $pattern) {
                $failureLines += $line.Trim()
                break
            }
        }
    }

    Write-Host "Engine: exited with code $exitCode."
    return [PSCustomObject]@{ ExitCode = $exitCode; FailureLines = $failureLines }
}


# ---------------------------------------------------------------------------
# Vendor pass (D4): footprint-dispatched, desired-state semantics
# ---------------------------------------------------------------------------
function Get-VendorInventory {
    # The combined prior-art inventory probe over services, registry
    # uninstall entries and scheduled tasks. Fail closed: enumeration errors
    # propagate instead of reading as a clean machine.
    $services = @(Get-Service -ErrorAction Stop |
        Where-Object { $_.DisplayName -match $VendorInventoryPattern -or $_.Name -match $VendorInventoryPattern })

    $arp = @(Get-ItemProperty $ArpRoots -ErrorAction Stop |
        Where-Object { $_.DisplayName -match $VendorInventoryPattern })

    $tasks = @(Get-ScheduledTask -ErrorAction Stop |
        Where-Object { $_.TaskPath -match $VendorInventoryPattern -or $_.TaskName -match $VendorInventoryPattern })

    return [PSCustomObject]@{ Services = $services; Arp = $arp; Tasks = $tasks }
}

function Get-VendorFootprint {
    # The slice of the combined inventory a branch's attribution patterns
    # claim as its own.
    param($Inventory, $Branch)

    $pattern = $Branch.ProbePattern
    $services = @($Inventory.Services |
        Where-Object { $_.DisplayName -match $pattern -or $_.Name -match $pattern })

    $arp = @($Inventory.Arp | Where-Object { $_.DisplayName -match $Branch.ArpPattern })

    $tasks = @($Inventory.Tasks |
        Where-Object { $_.TaskPath -match $Branch.ProbeTaskPattern -or $_.TaskName -match $Branch.ProbeTaskPattern })

    return [PSCustomObject]@{
        Services = $services
        Arp      = $arp
        Tasks    = $tasks
        Detected = (($services.Count + $arp.Count + $tasks.Count) -gt 0)
    }
}

function Get-UnattributedVendorFootprint {
    # Inventory hits no branch's attribution patterns claim. Reported so the
    # prior-art probe coverage is preserved even where vendor attribution is
    # ambiguous; nothing ever acts on these.
    param($Inventory)

    $services = @($Inventory.Services | Where-Object {
        $svc = $_
        -not (@($VendorBranches | Where-Object { $svc.DisplayName -match $_.ProbePattern -or $svc.Name -match $_.ProbePattern }).Count -gt 0)
    })
    $arp = @($Inventory.Arp | Where-Object {
        $entry = $_
        -not (@($VendorBranches | Where-Object { $entry.DisplayName -match $_.ArpPattern }).Count -gt 0)
    })
    $tasks = @($Inventory.Tasks | Where-Object {
        $task = $_
        -not (@($VendorBranches | Where-Object { $task.TaskPath -match $_.ProbeTaskPattern -or $task.TaskName -match $_.ProbeTaskPattern }).Count -gt 0)
    })

    return [PSCustomObject]@{
        Services = $services
        Arp      = $arp
        Tasks    = $tasks
        Detected = (($services.Count + $arp.Count + $tasks.Count) -gt 0)
    }
}

function Write-UnattributedVendorReport {
    param($Inventory)

    Write-Section 'VENDOR FOOTPRINT: unattributed (report-only)'
    $unattributed = Get-UnattributedVendorFootprint -Inventory $Inventory
    if (-not $unattributed.Detected) {
        Write-Host 'None: every combined-probe hit is attributed to a vendor branch.'
        return
    }
    Write-Host 'Combined prior-art probe hits no branch claims - no action is ever taken on these; attribute them in debloat.ps1 (with prior-art backing) if they are vendor bloat:'
    foreach ($svc in ($unattributed.Services | Sort-Object Name)) {
        Write-Host ('  service: {0} ({1}, {2}) - {3}' -f $svc.Name, $svc.Status, $svc.StartType, $svc.DisplayName)
    }
    foreach ($entry in ($unattributed.Arp | Sort-Object DisplayName)) {
        Write-Host "  installed: $($entry.DisplayName)"
    }
    foreach ($task in ($unattributed.Tasks | Sort-Object TaskName)) {
        Write-Host "  scheduled task: $($task.TaskPath)$($task.TaskName)"
    }
}

function Get-VendorOutstanding {
    # Actionable targets not in the desired state. Desired state: services in
    # the branch disable list are Disabled (installed-but-disabled is done,
    # not outstanding work); ARP entries with a usable quiet/MSI uninstall,
    # matching AppX packages, and removal-pattern scheduled tasks are gone.
    # ARP entries with no usable uninstall string, and HP tasks, were not
    # acted on by the exercised pass and are report-only, never outstanding.
    param($Branch)

    $outstanding = @()

    $allServices = @(Get-Service -ErrorAction Stop)
    foreach ($name in $Branch.DisableServices) {
        $svc = $allServices | Where-Object { $_.Name -eq $name }
        if ($svc -and $svc.StartType -ne 'Disabled') {
            $outstanding += "service not disabled: $name (StartType $($svc.StartType))"
        }
    }

    if ($Branch.Vendor -eq 'Dell') {
        $arp = @(Get-ItemProperty $ArpRoots -ErrorAction Stop |
            Where-Object { $_.DisplayName -match $Branch.ArpPattern })
        foreach ($entry in $arp) {
            $quiet = ($entry.PSObject.Properties['QuietUninstallString'] -and $entry.QuietUninstallString)
            $msi = ($entry.PSObject.Properties['UninstallString'] -and $entry.UninstallString -match '^MsiExec')
            # The Remediation product is also actionable through its cached
            # bundle uninstaller, even without a usable ARP uninstall string.
            $bundle = ($entry.DisplayName -match $DellRemediationArpPattern) -and (Test-Path $DellRemediationBundle)
            if ($quiet -or $msi -or $bundle) {
                $outstanding += "uninstallable package present: $($entry.DisplayName)"
            }
        }

        foreach ($pkg in @(Get-AppxPackage $Branch.AppxPattern -AllUsers -ErrorAction Stop)) {
            $outstanding += "appx package present: $($pkg.Name)"
        }
    }

    if ($Branch.RemoveTaskPattern) {
        # TaskName only, exactly the exercised removal predicate
        # (prior-art/vendor-remove.ps1 step 6); path-matched tasks are
        # probe/report territory, never removal.
        foreach ($task in @(Get-ScheduledTask -ErrorAction Stop |
            Where-Object { $_.TaskName -match $Branch.RemoveTaskPattern })) {
            $outstanding += "scheduled task present: $($task.TaskPath)$($task.TaskName)"
        }
    }

    return $outstanding
}

function Test-DellRemediationInstalled {
    # Installed-product state for Dell SupportAssist Remediation, shared by
    # audit, dispatch and outcome verification (via Get-VendorOutstanding's
    # ARP scan, which sees the same registration).
    return (@(Get-ItemProperty $ArpRoots -ErrorAction Stop |
        Where-Object { $_.DisplayName -match $DellRemediationArpPattern }).Count -gt 0)
}

function Invoke-DellBranch {
    # Distilled from prior-art/vendor-remove.ps1 steps 1-6, gated so each
    # action only fires on a target not already in the desired state. Every
    # uninstaller exit code is checked (0/3010/1605 acceptable for MSI-style
    # uninstalls); an operational failure makes the run non-green even if
    # the target's registration disappeared.
    param([System.Collections.Generic.List[string]]$Failures)

    # 1. Dell SupportAssist (MSI, quiet) - only while its product code is registered
    $msiKeys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$DellSupportAssistMsiCode",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$DellSupportAssistMsiCode"
    )
    if (@($msiKeys | Where-Object { Test-Path $_ }).Count -gt 0) {
        Write-Action "Dell: uninstalling SupportAssist (msiexec /X$DellSupportAssistMsiCode /qn /norestart)"
        $proc = Start-Process msiexec.exe -ArgumentList "/X$DellSupportAssistMsiCode /qn /norestart" -Wait -PassThru
        Write-Host "Dell: SupportAssist msiexec exit code $($proc.ExitCode)."
        if ($proc.ExitCode -notin $AcceptableMsiExitCodes) {
            $Failures.Add("Dell: SupportAssist MSI uninstall failed with exit code $($proc.ExitCode).")
        }
    }

    # 2. Dell SupportAssist Remediation (bundle, quiet) - only while the
    # product is actually installed; the cached installer on disk alone is
    # not a target (desired-state semantics).
    if ((Test-DellRemediationInstalled) -and (Test-Path $DellRemediationBundle)) {
        Write-Action 'Dell: uninstalling SupportAssist Remediation bundle (/uninstall /quiet)'
        $proc = Start-Process $DellRemediationBundle -ArgumentList '/uninstall /quiet' -Wait -PassThru
        Write-Host "Dell: Remediation bundle exit code $($proc.ExitCode)."
        if ($proc.ExitCode -notin @(0, 3010)) {
            $Failures.Add("Dell: SupportAssist Remediation bundle uninstall failed with exit code $($proc.ExitCode).")
        }
    }

    # 3. Dell AppX/MSIX packages
    foreach ($pkg in @(Get-AppxPackage '*Dell*' -AllUsers -ErrorAction Stop)) {
        Write-Action "Dell: removing appx package $($pkg.Name)"
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
        } catch {
            $Failures.Add("Dell: appx removal of $($pkg.Name) failed: $($_.Exception.Message)")
        }
    }

    # 4. Registry-driven quiet/MSI uninstalls for remaining Dell entries
    $arp = @(Get-ItemProperty $ArpRoots -ErrorAction Stop |
        Where-Object { $_.DisplayName -match 'Dell' })
    foreach ($entry in $arp) {
        if ($entry.PSObject.Properties['QuietUninstallString'] -and $entry.QuietUninstallString) {
            Write-Action "Dell: quiet-uninstalling $($entry.DisplayName)"
            cmd /c $entry.QuietUninstallString 2>&1 | Out-Host
            Write-Host "Dell: quiet uninstall of '$($entry.DisplayName)' exit code $LASTEXITCODE."
            if ($LASTEXITCODE -notin $AcceptableMsiExitCodes) {
                $Failures.Add("Dell: quiet uninstall of '$($entry.DisplayName)' failed with exit code $LASTEXITCODE.")
            }
        }
        elseif ($entry.PSObject.Properties['UninstallString'] -and $entry.UninstallString -match '^MsiExec') {
            $code = $entry.UninstallString -replace '.*(\{[0-9A-Fa-f-]+\}).*', '$1'
            Write-Action "Dell: msi-uninstalling $($entry.DisplayName) ($code)"
            $proc = Start-Process msiexec.exe -ArgumentList "/X$code /qn /norestart" -Wait -PassThru
            Write-Host "Dell: msi uninstall of '$($entry.DisplayName)' exit code $($proc.ExitCode)."
            if ($proc.ExitCode -notin $AcceptableMsiExitCodes) {
                $Failures.Add("Dell: MSI uninstall of '$($entry.DisplayName)' failed with exit code $($proc.ExitCode).")
            }
        }
    }

    # 6. Vendor scheduled tasks - TaskName only, the exercised removal
    # predicate (prior-art/vendor-remove.ps1 matches TaskName alone; a task
    # in a \Dell\ path with a non-matching name is probe/report territory).
    # (Step 5, service disables, runs for both vendors via
    # Invoke-VendorServiceDisables.)
    foreach ($task in @(Get-ScheduledTask -ErrorAction Stop |
        Where-Object { $_.TaskName -match 'SupportAssist|Dell' })) {
        Write-Action "Dell: removing scheduled task $($task.TaskPath)$($task.TaskName)"
        try {
            Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
        } catch {
            $Failures.Add("Dell: removal of scheduled task $($task.TaskPath)$($task.TaskName) failed: $($_.Exception.Message)")
        }
    }
}

function Invoke-VendorServiceDisables {
    # Prior-art step 5: stop and disable surviving vendor services - but only
    # those not already Disabled (installed-but-disabled is the desired state).
    # A Set-Service failure is recorded; a Stop-Service failure is only
    # logged, because the invariant is the persistent StartType and the
    # runbook reboot ends the process either way.
    param($Branch, [System.Collections.Generic.List[string]]$Failures)

    $allServices = @(Get-Service -ErrorAction Stop)
    foreach ($name in $Branch.DisableServices) {
        $svc = $allServices | Where-Object { $_.Name -eq $name }
        if ($svc -and $svc.StartType -ne 'Disabled') {
            Write-Action "$($Branch.Vendor): disabling service $name (was $($svc.StartType))"
            try {
                Stop-Service -Name $name -Force -ErrorAction Stop
            } catch {
                Write-Host "$($Branch.Vendor): Stop-Service $name reported: $($_.Exception.Message)"
            }
            try {
                Set-Service -Name $name -StartupType Disabled -ErrorAction Stop
            } catch {
                $Failures.Add("$($Branch.Vendor): disabling service $name failed: $($_.Exception.Message)")
            }
        }
    }
}

function Invoke-VendorPass {
    param([System.Collections.Generic.List[string]]$Failures)

    $inventory = Get-VendorInventory
    foreach ($branch in $VendorBranches) {
        Write-Section "VENDOR PASS: $($branch.Vendor)"
        $footprint = Get-VendorFootprint -Inventory $inventory -Branch $branch
        if (-not $footprint.Detected) {
            Write-Host "No $($branch.Vendor) footprint detected (services, uninstall entries, scheduled tasks all clean): no-op."
            continue
        }

        Write-Host "$($branch.Vendor) footprint detected: $($footprint.Services.Count) service(s), $($footprint.Arp.Count) uninstall entrie(s), $($footprint.Tasks.Count) scheduled task(s)."
        $before = @(Get-VendorOutstanding -Branch $branch)
        if ($before.Count -eq 0) {
            Write-Host 'All detected targets are already in the desired state: nothing to do.'
            continue
        }

        if ($branch.Vendor -eq 'Dell') {
            Invoke-DellBranch -Failures $Failures
        }
        Invoke-VendorServiceDisables -Branch $branch -Failures $Failures

        $after = @(Get-VendorOutstanding -Branch $branch)
        foreach ($item in $after) {
            $Failures.Add("$($branch.Vendor) vendor pass left an outstanding target - $item")
        }

        # Survivors report (prior-art step 7): running vendor services, report-only.
        $survivors = @(Get-Service -ErrorAction Stop |
            Where-Object { ($_.DisplayName -match $branch.ProbePattern -or $_.Name -match $branch.ProbePattern) -and $_.Status -eq 'Running' })
        if ($survivors.Count -gt 0) {
            Write-Host 'Surviving running services (report-only):'
            foreach ($svc in $survivors) {
                Write-Host ('  {0} ({1}, {2})' -f $svc.Name, $svc.Status, $svc.StartType)
            }
        }
    }

    Write-UnattributedVendorReport -Inventory $inventory
}

function Write-VendorAuditReport {
    $inventory = Get-VendorInventory
    foreach ($branch in $VendorBranches) {
        Write-Section "VENDOR FOOTPRINT: $($branch.Vendor)"
        $footprint = Get-VendorFootprint -Inventory $inventory -Branch $branch
        if (-not $footprint.Detected) {
            Write-Host 'No footprint detected.'
            continue
        }
        foreach ($svc in ($footprint.Services | Sort-Object Name)) {
            Write-Host ('  service: {0} ({1}, {2}) - {3}' -f $svc.Name, $svc.Status, $svc.StartType, $svc.DisplayName)
        }
        foreach ($entry in ($footprint.Arp | Sort-Object DisplayName)) {
            Write-Host "  installed: $($entry.DisplayName)"
        }
        foreach ($task in ($footprint.Tasks | Sort-Object TaskName)) {
            Write-Host "  scheduled task: $($task.TaskPath)$($task.TaskName)"
        }
        $outstanding = @(Get-VendorOutstanding -Branch $branch)
        if ($outstanding.Count -eq 0) {
            Write-Host 'Outstanding (a run would act on): none - detected footprint is in the desired state.'
        } else {
            Write-Host 'Outstanding (a run would act on):'
            foreach ($item in $outstanding) { Write-Host "  $item" }
        }
    }

    Write-UnattributedVendorReport -Inventory $inventory
}


# ---------------------------------------------------------------------------
# D6 extras
# ---------------------------------------------------------------------------
function Test-RegistryDwordCompliant {
    # The value must be a REG_DWORD with exactly this data; a string "1",
    # a QWORD or a missing value is a mismatch that run mode repairs.
    param([string]$Path, [string]$Name, [int]$Value)
    try {
        $key = Get-Item -Path $Path -ErrorAction Stop
        if ($key.GetValueKind($Name) -ne [Microsoft.Win32.RegistryValueKind]::DWord) {
            return $false
        }
        return ($key.GetValue($Name) -eq $Value)
    } catch {
        return $false
    }
}

function Test-SearchBoxPolicyCompliant {
    return (Test-RegistryDwordCompliant -Path $SearchBoxPolicyKey -Name $SearchBoxPolicyName -Value $SearchBoxPolicyValue)
}

function Invoke-CopilotPolicyBackstop {
    # The policy half of the pinned -DisableCopilot feature, enforced on
    # every run regardless of whether the flag was dispatched (the flag is
    # suppressed when no Copilot app is outstanding, and app absence never
    # implies policy compliance). Verify-and-enforce like the D6 backstop:
    # compliant values cost no action, so a clean rerun stays a no-op.
    param([System.Collections.Generic.List[string]]$Failures)

    Write-Section 'ENGINE POLICY BACKSTOP'
    foreach ($policy in $CopilotPolicyValues) {
        if (Test-RegistryDwordCompliant -Path $policy.Path -Name $policy.Name -Value $policy.Value) {
            Write-Host "$($policy.Name) already set to DWORD $($policy.Value) under $($policy.Path)."
            continue
        }
        Write-Action "setting DisableCopilot value $($policy.Name)=DWORD:$($policy.Value) under $($policy.Path)"
        New-Item -Path $policy.Path -Force | Out-Null
        New-ItemProperty -Path $policy.Path -Name $policy.Name -PropertyType DWord -Value $policy.Value -Force | Out-Null
        if (-not (Test-RegistryDwordCompliant -Path $policy.Path -Name $policy.Name -Value $policy.Value)) {
            $Failures.Add("Copilot policy backstop: failed to set $($policy.Name)=DWORD:$($policy.Value) under $($policy.Path).")
        }
    }
}

function Get-OneDriveSetupPath {
    $candidates = @(
        (Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe'),
        (Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe')
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

function Invoke-D6Extras {
    param([System.Collections.Generic.List[string]]$Failures)

    Write-Section 'D6 EXTRAS'

    # Machine-wide search-box web suggestions policy: verify (value AND
    # REG_DWORD type), set when absent or mismatched, and report. (The
    # engine's -DisableBing writes the per-user policy; this HKLM value is
    # the verify-and-enforce backstop.)
    if (Test-SearchBoxPolicyCompliant) {
        Write-Host "$SearchBoxPolicyName already set to DWORD $SearchBoxPolicyValue under $SearchBoxPolicyKey."
    } else {
        Write-Action "setting $SearchBoxPolicyName=DWORD:$SearchBoxPolicyValue under $SearchBoxPolicyKey"
        New-Item -Path $SearchBoxPolicyKey -Force | Out-Null
        New-ItemProperty -Path $SearchBoxPolicyKey -Name $SearchBoxPolicyName -PropertyType DWord -Value $SearchBoxPolicyValue -Force | Out-Null
        if (-not (Test-SearchBoxPolicyCompliant)) {
            $Failures.Add("D6: failed to set $SearchBoxPolicyName=DWORD:$SearchBoxPolicyValue under $SearchBoxPolicyKey.")
        }
    }

    # OneDrive fallback: only when OneDrive survived the engine pass.
    if (Test-OneDrivePresent) {
        $setup = Get-OneDriveSetupPath
        if ($setup) {
            Write-Action "OneDrive survived the engine pass: running $setup /uninstall"
            $proc = Start-Process $setup -ArgumentList '/uninstall' -Wait -PassThru
            Write-Host "OneDriveSetup exit code $($proc.ExitCode)."
            if ($proc.ExitCode -ne 0) {
                $Failures.Add("D6: OneDriveSetup /uninstall failed with exit code $($proc.ExitCode).")
            }
            if (Test-OneDrivePresent) {
                $Failures.Add('D6: OneDrive is still present after the OneDriveSetup /uninstall fallback.')
            }
        } else {
            $Failures.Add('D6: OneDrive is present but OneDriveSetup.exe was found in neither SysWOW64 nor System32.')
        }
    } else {
        Write-Host 'OneDrive not present; /uninstall fallback not needed.'
    }
}


# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------
function Invoke-AuditMode {
    # Read-only (D12): zero mutations - no transcript, no cache, no baseline
    # write; the report is built from the embedded pin data and live system
    # state alone. Exit 0 only when the whole report could be produced;
    # unreadable evidence (e.g. winget unavailable) makes the audit
    # incomplete and exits 1 rather than pretending targets are absent.
    Write-Host 'dotfiles windows debloat - mode: audit (read-only; nothing is written - redirect the output to keep a record)'
    Write-ContextReport
    $incomplete = @()

    Write-Section 'EFFECTIVE REMOVAL SET'
    $inventory = Get-RemovalInventory

    Write-Section 'APP TARGETS PRESENT'
    $appResult = Get-OutstandingAppTargets -Ids $inventory.AuditIds -WinGetIds $inventory.WinGetIds
    if ($appResult.Outstanding.Count -eq 0) {
        Write-Host 'None: no inspected target is installed.'
    } else {
        foreach ($id in $appResult.Outstanding) { Write-Host "  $id" }
    }
    foreach ($err in $appResult.Errors) {
        Write-Host "  ERROR: $err"
        $incomplete += $err
    }

    Write-VendorAuditReport

    Write-Section 'POLICY AND EXTRAS STATE'
    if (Test-SearchBoxPolicyCompliant) {
        Write-Host "$SearchBoxPolicyName policy: compliant (DWORD $SearchBoxPolicyValue)."
    } else {
        Write-Host "$SearchBoxPolicyName policy: NOT set to DWORD $SearchBoxPolicyValue - a run would set it."
    }
    foreach ($policy in $CopilotPolicyValues) {
        if (Test-RegistryDwordCompliant -Path $policy.Path -Name $policy.Name -Value $policy.Value) {
            Write-Host "DisableCopilot value $($policy.Name) under $($policy.Path): compliant (DWORD $($policy.Value))."
        } else {
            Write-Host "DisableCopilot value $($policy.Name) under $($policy.Path): NOT set to DWORD $($policy.Value) - a run would set it."
        }
    }
    if (Test-OneDrivePresent) {
        Write-Host 'OneDrive: present - a run would remove it (engine, then OneDriveSetup /uninstall fallback).'
    } else {
        Write-Host 'OneDrive: not present.'
    }

    Write-Section 'GUARDRAIL SERVICES'
    $baseline = Read-Baseline
    if ($baseline) {
        if ($script:BaselineFromOrphanTmp) {
            Write-Host "Baseline: exists only as an orphaned interrupted write ($BaselinePath.tmp); the next run or -PostReboot finalizes it (audit writes nothing)."
        }
        Write-Host "Baseline file: $BaselinePath (state: $($baseline.State), created $($baseline.CreatedUtc))."
        Write-GuardrailReport -BaselineServices $baseline.Services
        $violations = @(Compare-Guardrail -BaselineServices $baseline.Services)
        foreach ($violation in $violations) { Write-Host "  $violation" }
        if ($violations.Count -eq 0) { Write-Host 'Invariants vs baseline: OK.' }
    } else {
        Write-Host 'No baseline file exists yet (the first run snapshots one).'
        Write-GuardrailReport -BaselineServices $null
    }

    if ($incomplete.Count -gt 0) {
        Write-Section 'AUDIT INCOMPLETE'
        Write-Host 'The report above is missing evidence and cannot stand as a clean audit:'
        foreach ($err in $incomplete) { Write-Host "  - $err" }
        return 1
    }

    Write-Section 'AUDIT COMPLETE'
    Write-Host 'Read-only audit finished; nothing was changed.'
    return 0
}

function Invoke-RunMode {
    Write-ContextReport
    $failures = New-Object System.Collections.Generic.List[string]

    # D5 baseline before anything can mutate (a pending baseline is demoted
    # to active here; see Get-OrCreateBaseline).
    Write-Section 'GUARDRAIL BASELINE'
    $baseline = Get-OrCreateBaseline

    try {
        # Fail-fast config/payload work (non-destructive) before the
        # restore-point gate and every destructive phase.
        Write-Section 'ENGINE PAYLOAD'
        $engineRoot = Get-EnginePayload
        Assert-PinDataConsistent -EngineRoot $engineRoot
        $inventory = Get-RemovalInventory

        # Pre-run target inspection gates the destructive dispatch so a
        # clean rerun performs zero removal actions (D7). The engine's
        # Appx removal path enumerates before removing (absent targets cost
        # no action), but its WinGet path executes `winget uninstall`
        # unconditionally at the pin - so WinGet-method ids are dispatched
        # only when outstanding, and -DisableCopilot (the one flag carrying
        # a WinGet id) only when a Copilot target is outstanding. The
        # effective-set contract is untouched: the outcome check still
        # inspects the full inventory.
        Write-Section 'PRE-RUN TARGET CHECK'
        $preRun = Get-OutstandingAppTargets -Ids $inventory.AuditIds -WinGetIds $inventory.WinGetIds
        if (@($preRun.Errors).Count -gt 0) {
            throw "Pre-run target inspection failed (fail closed): $($preRun.Errors -join ' | ')"
        }
        $outstandingSet = @{}
        foreach ($id in $preRun.Outstanding) { $outstandingSet[$id] = $true }
        Write-Host "Outstanding targets before the run: $(@($preRun.Outstanding).Count)."

        $appsArg = @($inventory.EngineAppsArg | Where-Object {
            (-not $inventory.WinGetIds.ContainsKey($_)) -or $outstandingSet.ContainsKey($_)
        })
        $skippedWinGet = @($inventory.EngineAppsArg | Where-Object {
            $inventory.WinGetIds.ContainsKey($_) -and -not $outstandingSet.ContainsKey($_)
        })
        if ($skippedWinGet.Count -gt 0) {
            Write-Host "Not dispatching absent WinGet-method targets (their uninstall would execute regardless): $($skippedWinGet -join ', ')."
        }
        $copilotOutstanding = $outstandingSet.ContainsKey('XP9CXNGPPJ97XX') -or $outstandingSet.ContainsKey('Microsoft.Copilot')
        $flagsThisRun = @($EngineFlags | Where-Object { $_ -ne '-DisableCopilot' -or $copilotOutstanding })
        if (-not $copilotOutstanding) {
            Write-Host 'Not dispatching -DisableCopilot (no Copilot target outstanding; its removal list includes a WinGet id).'
        }

        Write-Section 'RECOVERY PRECONDITION'
        Assert-RestorePoint

        Write-Section 'ENGINE RUN'
        $engineResult = Invoke-Engine -EngineRoot $engineRoot -Flags $flagsThisRun -EffectiveSet $appsArg
        if ($engineResult.ExitCode -ne 0) {
            $failures.Add("Engine exited non-zero ($($engineResult.ExitCode)).")
        }
        foreach ($line in $engineResult.FailureLines) {
            $failures.Add("Engine reported a failure: $line")
        }

        Invoke-CopilotPolicyBackstop -Failures $failures

        Invoke-VendorPass -Failures $failures

        Invoke-D6Extras -Failures $failures

        # The engine reports success even when removals fail, so the wrapper
        # verifies outcomes itself: any inspected target still installed
        # (or uninspectable) makes the run non-green.
        Write-Section 'POST-RUN TARGET CHECK'
        $appResult = Get-OutstandingAppTargets -Ids $inventory.AuditIds -WinGetIds $inventory.WinGetIds
        foreach ($id in $appResult.Outstanding) {
            $failures.Add("Outstanding app target still installed: $id")
        }
        foreach ($err in $appResult.Errors) {
            $failures.Add("Post-run target check incomplete: $err")
        }
        if ($appResult.Outstanding.Count -eq 0 -and $appResult.Errors.Count -eq 0) {
            Write-Host 'No inspected target remains installed.'
        }
    }
    catch {
        $failures.Add("Run aborted: $($_.Exception.Message)")
    }
    finally {
        # D5 postcheck on every exit path, success or failure. Fail closed:
        # if service state cannot be read, the run is non-green.
        Write-Section 'GUARDRAIL POSTCHECK'
        try {
            Write-GuardrailReport -BaselineServices $baseline.Services
            $violations = @(Compare-Guardrail -BaselineServices $baseline.Services)
            foreach ($violation in $violations) { $failures.Add($violation) }
            if ($violations.Count -eq 0) {
                Write-Host 'Guardrail invariants hold vs baseline.'
            }
        } catch {
            $failures.Add("Guardrail postcheck could not read service state (fail closed): $($_.Exception.Message)")
        }
    }

    Write-Section 'RESULT'
    Write-Host "Destructive wrapper actions this run (ACTION lines): $script:ActionCount"
    if ($failures.Count -eq 0) {
        Set-BaselinePending
        Write-Host 'GREEN: all phases completed, no outstanding targets, guardrail invariants hold.'
        Write-Host 'REBOOT REQUIRED: engine tweaks and removals take full effect after a restart. This script never reboots the machine.'
        Write-Host 'After the reboot, run: powershell -NoProfile -ExecutionPolicy Bypass -File .\debloat.ps1 -PostReboot   (verifies the guardrail baseline and archives it)'
        return 0
    }

    Write-Host 'NON-GREEN: the following must be resolved (re-run after fixing; the baseline is retained for comparison):'
    foreach ($failure in $failures) { Write-Host "  - $failure" }
    return 1
}

function Invoke-PostRebootMode {
    # Completes the D5 baseline lifecycle: verify the pending baseline after
    # the runbook's reboot, then archive it (timestamped rename). Evidence is
    # never erased; a failed verification keeps the baseline in place. Only a
    # pending-verification baseline is accepted: a failed or retried run
    # demotes it to active, so this step can never archive stale success.
    Write-Section 'POST-REBOOT VERIFICATION'
    $baseline = Read-Baseline
    if (-not $baseline) {
        Write-Host "No baseline file at $BaselinePath - nothing to verify. Run the script first."
        return 1
    }
    Complete-OrphanBaselineWrite
    if ($baseline.State -ne 'pending-verification') {
        Write-Host "Baseline state is '$($baseline.State)', not 'pending-verification' - the most recent run attempt did not end green. Re-run the script until green, then reboot and verify."
        return 1
    }

    # The whole point of this step is checking state a reboot exposes, so a
    # boot after the green run must be established before anything can be
    # archived. Fail closed when the times cannot be read.
    try {
        $lastBootUtc = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime.ToUniversalTime()
        $greenRunUtc = ConvertTo-UtcDateTime -Value $baseline.GreenRunUtc
    } catch {
        Write-Host "Post-reboot verification could not establish the boot and green-run times (fail closed): $($_.Exception.Message)"
        Write-Host 'The baseline stays pending-verification; retry once the cause is fixed.'
        return 1
    }
    Write-Host "Green run at $($greenRunUtc.ToString('u')); last boot at $($lastBootUtc.ToString('u'))."
    if ($lastBootUtc -le $greenRunUtc) {
        Write-Host 'REFUSED: the machine has not rebooted since the green run, so reboot-exposed damage cannot have surfaced yet. Reboot first, then run -PostReboot again; the baseline stays pending-verification.'
        return 1
    }

    try {
        Write-GuardrailReport -BaselineServices $baseline.Services
        $violations = @(Compare-Guardrail -BaselineServices $baseline.Services)
    } catch {
        Write-Host "Post-reboot verification could not read service state (fail closed): $($_.Exception.Message)"
        Write-Host 'The baseline stays pending-verification; retry once the cause is fixed.'
        return 1
    }
    if ($violations.Count -gt 0) {
        Write-Host 'Post-reboot verification FAILED; the baseline stays pending-verification as the comparison and retry baseline:'
        foreach ($violation in $violations) { Write-Host "  - $violation" }
        return 1
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $archiveName = "guardrail-baseline-$stamp.json"
    Rename-Item -Path $BaselinePath -NewName $archiveName
    Write-Host 'Post-reboot verification passed: guardrail invariants hold after reboot.'
    Write-Host "Baseline archived to $(Join-Path $StateDir $archiveName). A future independent run snapshots fresh state."
    return 0
}


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
$mode = 'run'
if ($Audit) { $mode = 'audit' }
if ($PostReboot) { $mode = 'postreboot' }

$script:ActionCount = 0
$exitCode = 1

# Preflight before ANY file write, in every mode (D11: unsupported context
# aborts before mutation; D12: audit writes nothing at all).
$problems = @(Test-Preflight -NeedsAppsTxt ($mode -ne 'postreboot'))
if ($problems.Count -gt 0) {
    Write-Host "dotfiles windows debloat - mode: $mode"
    Write-Host 'Preflight failed; aborting before any file write or mutation:'
    foreach ($problem in $problems) { Write-Host "  - $problem" }
    exit 1
}

if ($mode -eq 'audit') {
    try {
        $exitCode = Invoke-AuditMode
    } catch {
        Write-Host "FATAL: $($_.Exception.Message)"
        $exitCode = 1
    }
    exit $exitCode
}

New-Item -ItemType Directory -Path $StateDir, $TranscriptDir -Force | Out-Null
$transcriptPath = Join-Path $TranscriptDir ("{0}-{1}.log" -f $mode, (Get-Date -Format 'yyyyMMdd-HHmmss'))
Start-Transcript -Path $transcriptPath -IncludeInvocationHeader | Out-Null

try {
    Write-Host "dotfiles windows debloat - mode: $mode - transcript: $transcriptPath"
    Write-Host 'Preflight passed (checked before the transcript or any other file was written).'

    switch ($mode) {
        'postreboot' { $exitCode = Invoke-PostRebootMode }
        default      { $exitCode = Invoke-RunMode }
    }
}
catch {
    Write-Host "FATAL: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    try { Stop-Transcript | Out-Null } catch { }
}

exit $exitCode
