# Architecture

iMacSwitch is a native Swift/AppKit/SwiftUI menu-bar application with no
third-party runtime dependencies. It runs the same binary on both Macs.

## Runtime components

- `AppDelegate/`: application lifecycle, menu-bar presentation, global manual
  handoff, and startup of the edge monitor.
- `Manager/EdgeSwitchManager.swift`: samples `NSEvent.mouseLocation` at 10 Hz,
  evaluates the configured display edge and dwell duration, and enforces
  leave-to-rearm semantics.
- `Model/Store/BluetoothPeripheralStore.swift`: source of truth for managed
  Bluetooth peripherals, handoff sequencing, disconnect observation, pairing,
  rollback, sleep release, and reconnect recovery.
- `Manager/ServiceBrowser.swift` and `ServicePublisher.swift`: Bonjour service
  discovery and publication with peer-to-peer AWDL enabled.
- `Manager/SecureChannel.swift`, `IncomingConnection.swift`, and
  `OutgoingConnection.swift`: authenticated encrypted command transport.
- `Manager/PairingStore.swift`: pairing-code derivation and Keychain storage.
- `View/`: compact setup, status, fallback controls, and edge-switch settings.
- `Manager/UpdateChecker.swift`: anonymous daily check of the public GitHub
  Releases API for `iFurySt/iMacSwitch`.

## Handoff sequence

1. The pointer remains inside the configured 3-point edge zone for the dwell
   duration.
2. The monitor disarms until the pointer leaves a wider 16-point zone.
3. The store sends one authenticated `PING` to the active paired Mac.
4. Selected connected peripherals are handled serially: local release, live
   disconnect wait (up to 10 seconds), then peer `CONNECT_ONE`.
5. A failure stops the batch. Untouched peripherals remain local; a released
   device uses the existing reconnect watcher and peer ownership probe.

Serial handoff is intentional: overlapping `IOBluetoothDevicePair` operations
on the receiving Mac are less reliable than one-at-a-time pairing.

## Network boundary

Bonjour runs in `local.` using `_imacswitch._tcp.`. Both `NetService` and
Network.framework opt into peer-to-peer transport. The preferred resolved
address is scoped to `awdl` or `llw`; normal LAN addresses remain a fallback.
No cloud relay is required.

## Persistence

- Non-secret preferences and registered device metadata use `UserDefaults`
  inside the `com.ifuryst.imacswitch` application domain.
- The pairing key uses the Keychain service
  `com.ifuryst.imacswitch.psk-v1`.
- A display is persisted by CoreGraphics UUID rather than transient screen
  index, so reconnecting an external display preserves its configuration.
