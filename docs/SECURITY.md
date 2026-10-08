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
