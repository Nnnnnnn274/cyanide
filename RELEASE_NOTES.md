# Release Notes

Keep concrete, user-facing release bullets here as changes land. The release
script reads `## Pending` before building, uses those bullets for GitHub release
notes and the generated in-app changelog, then moves them under `## Released`
after a successful build.

Good bullets describe the behavior users will notice:

- Reduced flicker when Dynamic Stage windows resize.
- Fixed installer queue badges after changing package selection.
- Added an iOS 17 fallback for Disable App Library.

Use one bullet per user-facing tweak or fix. Do not combine unrelated tweak
changes into the same bullet.

Avoid vague bullets like "Update settings", "Change project files", or
"Misc fixes".

Never mention private submodule activity, private tweak availability,
internal/private source movement, private repository names, or private-only
implementation details in release notes. If a private/internal change is not
safe to describe as a public user-facing behavior change, omit it.

## Pending


## Released

### v1.2.17 - 2026-06-09

- [x] Added Hide Home Bar as a beta package using DirtyZero-style MaterialKit page zeroing.
- [x] Made Hide Home Bar run as a standalone queue item with prominent install-queue guidance.
- [x] Added public Hide Home Bar credits in the package details.
- [x] Added a respring prompt after Hide Home Bar finishes so users know when the home indicator will disappear.
- [x] Fixed a queue review crash when pending changes finish while the queue screen is refreshing.
- [x] Reduced Dynamic Stage Lite picker startup work to avoid SpringBoard resprings on large app libraries.

### v1.2.16 - 2026-06-09

- [x] Prevented overlapping tweak actions from interfering with Apply Tweaks and direct controls.
- [x] Fixed Dynamic Stage Lite sidebar interference with the main tweak UI.

### v1.2.15 - 2026-06-09

- [x] Fixed Double Tap to Lock triggering while entering a Lock Screen passcode.
- [x] Added App Switcher Grid as a Beta tweak.
- [x] Replaced the installer contact button with Signal group and GitHub Issues links.
- [x] Removed the standalone Cyanide Themer listing in favor of SnowBoard Lite.
- [x] Let active Location Simulator target changes use parked kernel recovery before refreshing.
- [x] Kept OTA Block behind kernel recovery before editing launchd job state.
- [x] Kept Call Recording Sound behind kernel recovery before writing CallServices files.
- [x] Kept Watch Pairing override behind kernel recovery before writing NanoRegistry files.

### v1.2.14 - 2026-06-09

- [x] Fixed Dynamic Stage Lite visibility for paid users.
- [x] Fixed LiveWP video selection from Files and added Photos video selection.
- [x] Let active LiveWP users change videos from the installer without deactivating the wallpaper first.
- [x] Prevented LiveWP activation until a valid video has been selected.

### v1.2.13 - 2026-06-08

- [x] Moved Location Simulator to Beta and into the public app tree so it is available without enabling Experimental Tweaks.
- [x] Moved Call Recording Sound to Beta and into the public app tree so it is available without enabling Experimental Tweaks.

### v1.2.12 - 2026-06-08

- [x] Fixed Location Simulator exact coordinate entry so pasted decimal pairs and compass-suffix coordinates are normalized correctly.

### v1.2.11 - 2026-06-07

- [x] Added an optional simulator build path that uses a simulator XPF dylib without changing the normal device IPA build.
- [x] Added a StatBar option to show only live network upload and download speed.
- [x] Fixed the installer queue popup crash on iPadOS when the tab bar is attached after launch.
- [x] Fixed StatBar landscape placement on iPad by sizing the overlay from SpringBoard's active window bounds.
- [x] Fixed custom theme bundle-ID PNGs not preloading for apps that are only visible inside folders.
- [x] Prevented Dynamic Stage Lite and Cyanide Themer live icon repair from running together to avoid SpringBoard resprings.

### v1.2.10 - 2026-06-05

- [x] Updated the Cyanide Signal group invite link.

### v1.2.9 - 2026-06-05

- [x] Fixed NiceBar Lite weather slots by restoring the location-based weather picker, cache, and live refresh flow.

### v1.2.8 - 2026-06-05

- [x] Fixed LiveWP disappearing after leaving Cyanide and aligned NSBar/NiceBar Lite refresh loops with screen wake and sleep state.

### v1.2.7 - 2026-06-05

- [x] Fixed the Installer queue popup overlapping the bottom tab bar on iOS 18.

### v1.2.6 - 2026-06-05

- [x] Fixed LiveWP video changes stopping after one run and SnowBoard Lite icon themes drawing over rounded icon corners.

### v1.2.5 - 2026-06-05

- [x] Replaced the first-launch log collection notice with a Cyanide Signal group invite for feedback, feature requests, and support.
- [x] Added NSBar, NiceBar Lite, SnowBoard Lite, and LiveWP ports from d1y/cyanide-ios, with Settings controls and Installer package credits.
- [x] Allowed public Cyanide checkouts to build without the private experimental tweak submodule.

### v1.2.4 - 2026-06-03

- [x] Added a StatBar refresh-rate setting and reduced battery use from repeated temperature polling.
- [x] Fixed Installer queue edge cases so no-op applies finish cleanly and pending activations are remembered after reopening Cyanide.

### v1.2.3 - 2026-06-03

- [x] Improved Gravity Lite startup on iOS 17 by using the faster live-icon capture path.
- [x] Fixed a recent tweak startup regression that could hang while opening the SpringBoard injection channel on A16+ iPhones.
- [x] Fixed Installer package state so successfully applied SpringBoard tweaks no longer appear stuck as activation pending.

### v1.2.2 - 2026-06-03

- [x] Fixed kernel panic on A16+/M-series iPads by guarding the t1sz_boot override so the PAC mask uses the correct value.

### v1.2.1 - 2026-06-03

- [x] Added Drag Coefficient tweak — custom SpringBoard animation speed multiplier ported from kolbicz/DarkSword-Tweaks, with a 5–200% slider (50% = 2× faster, 100% = stock).

### v1.2.0 - 2026-06-03

- [x] Added Gravity Lite with home screen and dock icon physics, tilt control, widget support, and iOS 18/26 compatibility.
- [x] Polished installer, settings, and log presentation with clearer status text, cleaner startup branding, and a maintained release-notes workflow.
- [x] Improved tweak activation and cleanup so unchanged tweaks are not reapplied unnecessarily and SpringBoard-backed tweaks deactivate more reliably.

### v1.1.22 - 2026-06-02

- [x] Reduced flicker when Dynamic Stage windows resize by staging new scene hosts and retiring old hosts after the remote layer has populated.
- [x] Added stronger transition shielding around Dynamic Stage app open, close, and apply paths.
- [x] Tracked DarkSword toggle apply results independently in Settings.
- [x] Improved Disable App Library handling with an iOS 17 fallback path.
- [x] Refined installer queue, badges, and activity status UI.
- [x] Tightened Log tab typography for dense verbose traces.
- [x] Updated the release script to capture dirty submodule changes before committing and tagging the parent release.
