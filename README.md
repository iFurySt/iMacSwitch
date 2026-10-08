# iMacSwitch

iMacSwitch is a focused macOS menu-bar app that moves a Bluetooth keyboard,
mouse, or trackpad between two nearby Macs when the pointer rests at a chosen
display edge.

It is designed for the awkward but common setup where the two Macs cannot join
the same LAN. Discovery and commands use Apple's peer-to-peer AWDL interface;
Wi-Fi must be enabled, but the Macs may be connected to unrelated networks.

## What it does

- Watches one chosen edge of one chosen display, with a configurable
  `0.5–10 second` dwell time.
- Releases only the peripherals selected for that edge switch.
- Performs one secure peer preflight, then hands peripherals over sequentially.
- Waits for the real Bluetooth disconnect before asking the other Mac to pair.
- Requires the pointer to leave the edge before another switch can fire.
- Keeps manual per-device and all-device switching as a recovery path.
- Checks [this repository's Releases](https://github.com/iFurySt/iMacSwitch/releases)
  once a day and only notifies; it never installs an update automatically.

## Install

Download the latest signed and notarized `.dmg` or `.app.zip` from
[Releases](https://github.com/iFurySt/iMacSwitch/releases).

On both Macs:

1. Pair each Bluetooth peripheral in macOS System Settings. Each peripheral
   must be paired with both Macs once.
2. Launch iMacSwitch and grant Bluetooth and Local Network access.
3. Open **Settings → Peripheral** and add the devices to manage.
4. Open **Settings → Device** and register the other Mac.
5. Open **Settings → Pairing** and enter the same generated code on both Macs.
6. Open **Settings → Edge Switch**, choose a display, edge, hold duration, and
   the peripherals that should move.

For two-way switching, configure the corresponding physical outer edge on each
Mac. An edge shared by two displays on the same Mac normally cannot be used for
dwell switching because the pointer immediately crosses onto the other display.

## Build locally

Requirements: macOS 11.5+, Xcode 16 or newer.

```sh
make ci
```

The app has no third-party runtime dependencies. Local CI builds without a
signing identity. Release tags are built, Developer ID signed, notarized, and
published by GitHub Actions; see [`docs/CICD.md`](docs/CICD.md).

## Architecture

```text
pointer dwell
    │
    ▼
EdgeSwitchManager
    │ selected connected peripherals
    ▼
BluetoothPeripheralStore ── release / observe / rollback
    │
    ▼
SecureChannel over Bonjour + AWDL ── CONNECT_ONE ──► peer Mac
```

Peer commands are authenticated and encrypted with a key derived from the
12-character pairing code. See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
and [`docs/SECURITY.md`](docs/SECURITY.md).

## Acknowledgements

iMacSwitch carries forward Bluetooth handoff ideas from
[HoshimuraYuto/blue-switch](https://github.com/HoshimuraYuto/blue-switch) and
subsequent reliability work, while keeping an independent product identity,
protocol namespace, keychain namespace, and release history.

## License

[MIT](LICENSE)
