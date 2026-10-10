# Security

## Peer authentication

The two Macs derive a 256-bit pre-shared key from a 12-character pairing code
using PBKDF2-HMAC-SHA256. Every connection establishes a fresh authenticated
encrypted session with replay protection. Unpaired or mismatched peers cannot
issue Bluetooth commands.

## Local permissions

- Bluetooth permission is required to inspect, release, and pair peripherals.
- Local Network permission is required for Bonjour/AWDL peer discovery.
- Edge detection only reads `NSEvent.mouseLocation`; it does not install an
  event tap and does not require Accessibility permission.
- User Selected File read/write is used only for the explicit diagnostic
  export destination chosen in the macOS save panel.
- The application is sandboxed and uses the hardened runtime in Release.

## Secrets

- The peer key is stored in the macOS Keychain, not `UserDefaults`.
- Apple signing and notarization credentials are GitHub Actions secrets.
- Never commit `.p8`, `.p12`, passwords, provisioning profiles, temporary
  keychains, or decoded secret material.
- CI actions must remain pinned to immutable commit SHAs.

## Network exposure

The listener accepts nearby Bonjour/AWDL or LAN connections, but command
processing starts only after secure-channel authentication. Authentication
failures are rate-limited per endpoint; outbound repeated failures are also
bounded to prevent retry storms.

## Diagnostic data

- Diagnostics stay local until the user explicitly chooses an export path.
- Rolling files are bounded (one current file plus four rotations) and contain
  structured state transitions rather than protocol payloads.
- Raw Bluetooth MAC addresses, peer names, IP/AWDL addresses, pairing codes,
  PSKs, Keychain data, and signing credentials are not written. Identifiers
  needed to align two Macs are represented by stable truncated SHA-256 hashes.
- Export includes app/build version, OS version, architecture, random
  installation/session IDs, timestamps, settings, and operational outcomes.
