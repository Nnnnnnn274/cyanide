# kfun-zeroxjf

This fork focuses on exploit stability across supported devices. Shared chain cleanup,
process-marker matching, socket validation, and nonfatal missed-race handling run before
or during every exploit attempt. The A18/M4 `pe_v2` path also has extra path-specific
guardrails for its wired-page/zone-trimming flow: marker-initialized target file
contents, stable local remap addresses, bounded page freeing, socket-spray preflight
checks, and controlled zone-trimming retries.

Credit to rooootdev's [Lara](https://github.com/rooootdev/lara) for the working
kexploit behavior used to stabilize this fork.

Fork of `wh1te4ever/darksword-kexploit-fun` for iOS security research.

Building some cool stuff utilizing kernel r/w exploit

## Tweaks

> All tweaks have only been tested on iOS 18.x. They may behave incorrectly
> or crash SpringBoard on other versions.

- **SBCustomizer** — configurable dock icon count, home-screen columns/rows,
  hide icon labels (ports the lightsaber sbcustomizer payload to native
  remote-call).
- **SpringBoard Tweaks** — Disable App Library, disable icon fly-in
  animation, zero wake animation, zero backlight fade, double-tap to lock.
  Ported from [kolbicz/DarkSword-Tweaks](https://github.com/kolbicz/DarkSword-Tweaks)
  by [@_kolbicz](https://x.com/_kolbicz).
- **Powercuff** — CPU/GPU underclock via `thermalmonitord` simulated
  thermal pressure (off / nominal / light / moderate / heavy). Lasts
  until reboot. Port of [rpetrich/Powercuff](https://github.com/rpetrich/Powercuff).
- **StatBar** — battery temperature + free RAM live overlay anchored to
  the SpringBoard status bar. Optional °C/°F and network-speed display.
- **OTA Disabler** — toggle the launchd OTA `disabled.plist` to block
  or unblock OTA update prompts. Ported from
  [kolbicz/DarkSword-Tweaks](https://github.com/kolbicz/DarkSword-Tweaks)
  by [@_kolbicz](https://x.com/_kolbicz).
- **Respring** — in-app WKWebView trigger for SpringBoard restart.

## Features
- Escape app sandbox
- Remotely control or force-crash userspace processes
- Manipulate UID, GID, and sticky bits for target files
- Disable ASLR by setting `P_DISABLE_ASLR` to `launchd's proc->p_flag`

## Supported Devices
All iOS/iPadOS 17.0-26.0.1 devices, except A19/M5 devices
