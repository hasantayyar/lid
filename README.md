# Lid

Privacy-first macOS menu bar utility that reads a compatible MacBook lid-angle sensor and runs local automations at configured thresholds.

This repository ships a menu bar app (`Lid.app`) plus a `lid-sensor` diagnostic. Hardware support is still limited to models in the matrix below.

## Inspiration

Lid is inspired by [LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor), Sam Henri Gold's fun Mac utility that reads the same undocumented lid-angle HID sensor and (optionally) creaks like a wooden door when you move the display slowly.

That project showed the sensor was reachable. This one is a separate, original implementation aimed at local privacy automations. Phase 0 does not copy its source.

## Compatibility

Lid does not claim support for untested hardware.

Verified in this repository:

| Model | Chip | macOS | Sensor |
| --- | --- | --- | --- |
| Mac16,8 (MacBook Pro 14-inch, 2024) | M4 Pro | 26.6.2 | Detected. Degrees from closed via undocumented IOKit HID. |

Community reports mention a sensor on some 2019 16-inch MacBook Pro and later models, and failures on some M1 and M2 machines. Those reports are not a support list. See `docs/hardware-compatibility.md`.

## Privacy

- Local only. No account, cloud, analytics, telemetry, or network client.
- No camera, microphone, or screen capture.
- Accessibility is requested only if you enable or test lock.
- Music/Spotify may ask for Automation access after you enable media pause.
- Diagnostics never include raw HID payloads, window titles, usernames, or file paths.

## Requirements

- macOS 14 or later
- Xcode / Swift 6 toolchain
- Compatible lid-angle hardware, or `--simulate`

## Build the menu bar app

```bash
./scripts/run-app.sh
```

That builds `artifacts/Lid.app` and opens it. Lid has no Dock icon. Look in the menu bar for the angle or the word `Lid`.

Package a drag-and-drop `Lid.app`:

```bash
./scripts/package-app.sh release
```

That writes `artifacts/Lid.app`. Drag it into Applications, or open it from that folder.

For a disk image with an Applications shortcut:

```bash
./scripts/package-dmg.sh
open artifacts/Lid.dmg
```

Launch at login works only from that `.app` bundle, not from `swift run`. The package is ad-hoc signed for local use. Sharing it to other Macs still needs Developer ID signing and notarization.

## Other commands

```bash
swift test -Xswiftc -warnings-as-errors
swift run lid-sensor --help
swift run lid-sensor --once
swift run lid-sensor --list
swift run lid-sensor --simulate --duration 2
./scripts/run-sensor-diagnostic.sh --duration 10
```

A 10-minute soak, used for leak and crash checks:

```bash
./scripts/run-sensor-diagnostic.sh --duration 600
```

Hardware XCTest is opt-in:

```bash
LID_HARDWARE_TEST=1 swift test --filter HardwareProbeTests
```

## Architecture

Reusable logic lives in the `LidCore` Swift package target. `LidApp` is the menu bar UI. `lid-sensor` is the diagnostic CLI.

Undocumented HID constants stay inside `IOKitLidAngleProvider`.

## License

This project is licensed under the [MIT License](LICENSE).

Product source in this repository is original. Phase 0 does not copy third-party sensor implementations. Public HID research is cited in `docs/hardware-compatibility.md`.
