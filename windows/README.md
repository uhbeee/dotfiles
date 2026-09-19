# Windows debloat

General Windows 11 treatment for any machine entering the fleet, exactly as
the darwin modules are general macOS treatment. One tracked script removes
OEM (Dell, HP) and Microsoft bloat, telemetry and vendor services, guarded
so it can never take out WSL, remote access, updates or Defender.

Nothing here names a person, a machine, a hostname or an IP. The removal
lists are preferences; identity stays in the consuming machines repo.

## What it does

`debloat.ps1` (run mode) executes, in order:

1. **Preflight** - verifies the supported context (below) before any file
   write at all; an unsupported context aborts before the transcript, state
   directory or anything else is created.
2. **Guardrail baseline** - snapshots presence, StartType and Status of the
   seven protected services (below) to a baseline file. An existing
   non-archived baseline is reused, never overwritten, so a rerun is always
   judged against the original state (a pending-verification baseline is
   demoted back to active for the new attempt; see the lifecycle below).
3. **Recovery precondition** - reuses a system restore point created within
   the last 24 hours, or creates and verifies one; aborts before any
   destructive phase when neither is possible.
4. **Engine** - downloads [Win11Debloat](https://github.com/Raphire/Win11Debloat)
   pinned to an exact release tag (verified by SHA-256, see *Engine pin*),
   and runs it with the exercised flag set:
   `-Silent -CreateRestorePoint -RemoveApps -RemoveHPApps -RemoveGamingApps
   -DisableTelemetry -DisableCopilot -DisableRecall -DisableBing
   -DisableWidgets -SkipExplorerRestart`, plus `-Apps` carrying the
   *effective removal set* (see below). Uninstall dispatch is gated on
   outstanding targets (see *Idempotency*); because that can suppress
   `-DisableCopilot`, the wrapper then verifies and enforces the three
   registry values that pinned feature writes on every run - app absence
   never implies policy compliance.
5. **Vendor pass** - Dell and HP cleanup dispatched on detected footprint
   (services, registry uninstall entries, scheduled tasks), never on the
   reported manufacturer. The inventory probe is the exercised combined
   prior-art pattern; hits attributable to neither vendor branch are
   reported as unattributed and never acted on. A branch acts only on
   targets not already in the desired state; a machine with no vendor
   footprint gets a reported no-op.
6. **Extras** - enforces the machine-wide
   `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions = 1`
   policy, and runs `OneDriveSetup.exe /uninstall` only if OneDrive
   survived the engine pass.
7. **Guardrail postcheck** - on every exit path, success or failure: any
   protected service that disappeared or had its StartType weakened versus
   baseline fails the run with a non-zero exit. Inspection is fail closed:
   if service state cannot be read, the run is non-green rather than
   assumed safe.

A run is **green** (exit 0) only when every phase completed, no inspected
target remains installed (the removal set plus the packages the engine
flags remove on their own), the engine reported no app-removal or
feature-change failures of its own (it exits 0 even then, so the wrapper
scans for them), and the postcheck passes. Any failed phase, failed
uninstaller exit code, unreadable inventory, outstanding target or
guardrail violation exits non-zero.

### Audit mode

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\debloat.ps1 -Audit
```

Read-only report with zero mutations - it writes nothing at all, not even
a transcript or the engine cache; it works entirely from the pin data
embedded in the script and live system state. Redirect the output
(`*> audit.txt`) to keep a record. It reports: which inspected targets are
installed (the effective removal set plus the flag-removed packages,
matched with the engine's own wildcard semantics so audit sees exactly
what a run would remove), vendor footprint and what a run would act on,
the policy and extras state (the search-box policy, the Copilot policy
values, OneDrive), and the guardrail services versus the baseline. This is the before/after evidence
instrument - run it before and after a debloat run to prove what changed
(and, on a clean machine, that nothing did). All presence detection is
read-only (package enumeration, registry, file paths - the script never
shells out to winget, which writes log files and accepts source
agreements). It exits 0 only when the whole report could be produced; if
evidence is unreadable (an enumeration failure, or a target with no
read-only detection), the audit reports itself incomplete and exits
non-zero instead of pretending targets are absent.

### Post-reboot verification

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\debloat.ps1 -PostReboot
```

The runbook's final step. After a green run and a reboot, it re-checks the
guardrail invariants against the pending baseline and, on success, archives
the baseline (timestamped rename). It first establishes that the machine
actually booted after the green run (last boot time vs the recorded green
timestamp) and refuses to archive otherwise - the step exists to catch
reboot-exposed damage, so it cannot run before the reboot. Until this passes, the baseline stays
the single comparison and retry baseline for every further run - including
damage a reboot exposes. It only accepts a pending-verification baseline:
starting a new run attempt demotes the baseline back to active, so this
step can never archive on the strength of a green run that a later failed
or interrupted attempt has superseded.

## What it never touches

The guardrail contract covers these services: `hns`, `WinNAT`, `vmcompute`,
`WslService`, `sshd`, `wuauserv`, `WinDefend` (WSL, its networking, OpenSSH
remote access, Windows Update, Defender). The invariants are presence and
StartType: a service present at baseline must remain present, and its
StartType must never weaken (Automatic to Manual/Disabled, Manual to
Disabled). Runtime Status is recorded for the report only - services
starting and stopping on normal triggers is never a violation. Any
violation makes the run fail non-zero, whatever else succeeded.

Also out of scope by design: winget package management, Windows Update
management, Defender configuration, settings suites, scheduled re-runs.

## Supported context

Aborted by preflight otherwise:

- Windows 11 (build 22000+)
- Windows PowerShell 5.1, Desktop edition (`powershell.exe`; the engine's
  app removal does not work under PowerShell 7)
- An elevated (Administrator) session
- `apps.txt` present next to the script

One thing preflight cannot check: the invoking account must be the
machine's **intended desktop user**. Per-user settings apply to the
invoker; over ssh this means logging in as that same account. Single-user
machines only - multi-user targeting is out of scope.

## Fresh-machine runbook

On the new machine, in an **admin** PowerShell running **as the intended
desktop user** (replace `<owner>` with the GitHub owner of this repo; the
machines repo's runbook carries the concrete URL):

```powershell
$repo = 'https://raw.githubusercontent.com/<owner>/dotfiles/main/windows'
New-Item -ItemType Directory -Path $env:TEMP\debloat -Force | Set-Location
Invoke-WebRequest -UseBasicParsing "$repo/debloat.ps1" -OutFile debloat.ps1
Invoke-WebRequest -UseBasicParsing "$repo/apps.txt"    -OutFile apps.txt

powershell -NoProfile -ExecutionPolicy Bypass -File .\debloat.ps1 -Audit *> audit-before.txt   # before-evidence (audit itself writes nothing)
powershell -NoProfile -ExecutionPolicy Bypass -File .\debloat.ps1                              # the run
```

Then:

1. Check the run ended `GREEN` (exit code 0). If not, read the transcript,
   fix, re-run - the script is idempotent and the baseline is retained.
2. Reboot the machine yourself (the script never reboots; it reports that a
   reboot is required).
3. After the reboot:
   `powershell -NoProfile -ExecutionPolicy Bypass -File .\debloat.ps1 -PostReboot`
   - green output archives the guardrail baseline and completes the
   lifecycle (it refuses to archive if the machine has not actually
   rebooted since the green run). Sanity-check your own stack too (e.g.
   that the WSL distro boots and ssh still answers).
4. Optionally
   `powershell -NoProfile -ExecutionPolicy Bypass -File .\debloat.ps1 -Audit *> audit-after.txt`
   for after-evidence.

### Idempotency

A re-run on an already-clean machine performs no removal, disable or
uninstall action and still exits green (it writes a transcript, reuses the
baseline and reuses the restore point - that is the expected no-op). A
pre-run target inspection makes this literal: targets already absent are
not handed to the engine's uninstall paths at all, because the engine's
winget path would otherwise still execute uninstall commands for them.
This is what makes the script a setup step rather than a one-off:
re-running is always safe, and re-running is also the retry path after a
failure.

## Files on the machine

Everything lands under `C:\ProgramData\dotfiles-debloat\`:

| Path | What |
|------|------|
| `transcripts\<mode>-<timestamp>.log` | Full transcript of every run and postreboot invocation (audit writes nothing; redirect its output to keep it) |
| `guardrail-baseline.json` | The active or pending-verification guardrail baseline (updated atomically: temp file swapped in via the Win32 ReplaceFile API) |
| `guardrail-baseline.json.bak` | The previous baseline version, kept by each atomic update as recovery evidence |
| `guardrail-baseline-<timestamp>.json` | Archived baselines (completed lifecycles) |
| `engine\Win11Debloat-<tag>\` | The verified pinned engine payload (cached by run mode; reruns work offline) |

The engine additionally writes its own log under its payload directory
(`Logs\Win11Debloat.log`); the wrapper transcript contains the same output.

Baseline lifecycle: `active` (snapshotted, judged against) →
`pending-verification` (a run went green; awaiting the post-reboot check) →
archived (timestamped rename; the next independent run snapshots fresh).
A failed or interrupted attempt leaves the baseline active and reused - a
rerun can never launder damage done by an earlier attempt - and starting a
new run attempt demotes a pending-verification baseline back to active
(same snapshot, new verdict pending) so a failed retry can never be
archived as verified. Evidence files are never deleted at any transition.
Baseline updates are atomic: the new version is written to a temp file and
swapped in with the Win32 ReplaceFile API, which also keeps the previous
version as `.bak` - an interrupted write can never lose a valid baseline.
An interrupted *first* write leaves an orphaned `.tmp` that the next run
or `-PostReboot` finalizes (a valid one) or refuses (an invalid one), and
an existing but empty or corrupt baseline file is refused with
instructions rather than silently replaced by a fresh snapshot. Validity
is strict: a baseline must carry exactly one record per protected service
(all seven) with recognized StartTypes, or it is rejected as evidence.

## If a remote run drops the connection

Idempotent re-run over ssh is the retry path, but if the machine is
unreachable, recover at the console (the fleet's Windows machines have
keyboard and monitor available):

1. Log in locally as the same desktop user, open an admin PowerShell.
2. Triage the newest transcript:
   `Get-ChildItem C:\ProgramData\dotfiles-debloat\transcripts | Sort-Object LastWriteTime | Select-Object -Last 1 | Get-Content | Select-Object -Last 80`
3. If the machine is healthy: re-run
   `powershell -NoProfile -ExecutionPolicy Bypass -File .\debloat.ps1`
   (it judges against the retained baseline) and continue the runbook.
4. If something is broken: run `rstrui` and restore the "dotfiles windows
   debloat" (or most recent) restore point - the run guaranteed one exists
   before mutating anything - then re-run once healthy.

## Engine pin

| What | Value |
|------|-------|
| Upstream | `Raphire/Win11Debloat` |
| Release tag | `2026.08.24` |
| `Win11Debloat.ps1` SHA-256 | `1ace81fc73c227f403d8f20a86d7eb0fa7f34985a017379bf141e04941d2caad` |
| `Config/Apps.json` SHA-256 | `acef5d6f67a6ab62f96205c84e7fe365d025732c7ba8ba6bc91490ece5b1121b` |

The pin is exact and never "latest". The release zip is downloaded at run
time and the two behavior-bearing files are verified against these hashes
(GitHub source zips are not hash-stable; tagged file contents are). A
mismatch aborts the run.

Bumping the pin is a deliberate change: update the tag, both hashes AND
the embedded pin data in `debloat.ps1` (the default/optional/WinGet-method
identifier lists, the flag-target lists, the Store-product-id
package-name map used for read-only detection, and the
`Disable_Copilot.reg` policy values), re-check the `-Apps`
semantics and `apps.txt` coverage against the new release's
`Config/Apps.json`, update the effective-set appendix below, and re-run
the E2E validation before trusting it. Run mode cross-checks the embedded
pin data against the hash-verified payload and aborts on any mismatch, so
an incomplete bump refuses to run.

## Effective removal set

Upstream documents `-Apps` as *selecting* the removal list, not extending
the default selection. The script therefore computes the union itself -
the pinned release's default selection (every `Config/Apps.json` entry
with `SelectedByDefault: true`) plus the `apps.txt` extras - and passes
the combined, deduplicated list via `-Apps`. The engine's default behavior
is never narrowed; `apps.txt` only ever adds.

Accounting for each `apps.txt` entry against the pinned release:

| Entry | Coverage at pin `2026.08.24` |
|-------|------------------------------|
| `Microsoft.OneDrive` | In `Apps.json` (WinGet removal method, not default-selected) - a genuine extra. Backstopped by the script-side `OneDriveSetup.exe /uninstall` handler if it survives the engine. |
| `XP9CXNGPPJ97XX` | In `Apps.json` and default-selected at this pin (also swept by `-DisableCopilot`). Kept in `apps.txt` so the contract survives a pin bump that drops it from the defaults. |
| `Microsoft.Windows.AIHub` | In `Apps.json` and default-selected at this pin. Kept for the same reason. |

The engine default selection at pin `2026.08.24` (84 identifiers,
`SelectedByDefault: true` in `Config/Apps.json`). This list is embedded in
`debloat.ps1` as pin data - audit mode works from it without writing
anything - and run mode cross-checks it against the hash-verified payload,
so this appendix mirrors the single pinned source:

```text
4DF9E0F8.Netflix
ACGMediaPlayer
ActiproSoftwareLLC
AdobeSystemsIncorporated.AdobePhotoshopExpress
Amazon.com.Amazon
AmazonVideo.PrimeVideo
Asphalt8Airborne
AutodeskSketchBook
BytedancePte.Ltd.TikTok
CaesarsSlotsFreeCasino
Clipchamp.Clipchamp
COOKINGFEVER
CyberLinkMediaSuiteEssentials
Disney.37853FC22B2CE
DisneyMagicKingdoms
DrawboardPDF
Duolingo-LearnLanguagesforFree
EclipseManager
FACEBOOK.FACEBOOK
Facebook.Instagram
FarmVille2CountryEscape
flaregamesGmbH.RoyalRevolt
Flipboard
HiddenCity
HULULLC.HULUPLUS
iHeartRadio
king.com.BubbleWitch3Saga
king.com.CandyCrushSaga
king.com.CandyCrushSodaSaga
LinkedInforWindows
MarchofEmpires
Microsoft.3DBuilder
Microsoft.549981C3F5F10
Microsoft.BingFinance
Microsoft.BingFoodAndDrink
Microsoft.BingHealthAndFitness
Microsoft.BingNews
Microsoft.BingSports
Microsoft.BingTranslator
Microsoft.BingTravel
Microsoft.BingWeather
Microsoft.Getstarted
Microsoft.Messaging
Microsoft.Microsoft3DViewer
Microsoft.MicrosoftJournal
Microsoft.MicrosoftOfficeHub
Microsoft.MicrosoftPowerBIForWindows
Microsoft.MicrosoftSolitaireCollection
Microsoft.MicrosoftStickyNotes
Microsoft.MixedReality.Portal
Microsoft.NetworkSpeedTest
Microsoft.News
Microsoft.Office.OneNote
Microsoft.Office.Sway
Microsoft.OneConnect
Microsoft.PCManager
Microsoft.PowerAutomateDesktop
Microsoft.Print3D
Microsoft.SkypeApp
Microsoft.Todos
Microsoft.Windows.AIHub
Microsoft.Windows.DevHome
Microsoft.WindowsAlarms
Microsoft.WindowsFeedbackHub
Microsoft.WindowsMaps
Microsoft.WindowsSoundRecorder
Microsoft.XboxApp
Microsoft.ZuneVideo
MicrosoftCorporationII.MicrosoftFamily
MicrosoftCorporationII.QuickAssist
MicrosoftTeams
MSTeams
NYTCrossword
OneCalendar
PandoraMediaInc
PhototasticCollage
PicsArt-PhotoStudio
PolarrPhotoEditorAcademicEdition
Sidia.LiveWallpaper
SlingTV
SpotifyAB.SpotifyMusic
TuneInRadio
WinZipUniversal
XP9CXNGPPJ97XX
```

Beyond `-Apps`, the exercised flag set also removes the Xbox gaming apps
(`-RemoveGamingApps`), the HP AppX suite (`-RemoveHPApps`), the Bing search
app (`-DisableBing`), the Copilot apps (`-DisableCopilot`) and the widgets
platform (`-DisableWidgets`). Those fixed per-flag package lists are also
embedded in `debloat.ps1` (from the pinned release's
`Scripts/Features/Invoke-Changes.ps1`) and are included in what audit
reports and what the post-run outcome check verifies, so a failed
flag-driven removal cannot hide behind a green exit. The vendor pass
targets (Dell SupportAssist and Remediation, Dell AppX/registry
uninstalls, the Dell and HP service disable lists, Dell scheduled tasks)
are recorded in `debloat.ps1` itself and trace to the exercised prior art
in the dotfiles plan archive.
