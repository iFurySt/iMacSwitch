# Product principles

iMacSwitch has one job: make a physical keyboard and pointing device feel as
if they naturally cross between two nearby Macs.

- Automatic edge switching is the primary path; manual controls are a recovery
  path, not the product center.
- Never release a peripheral until the destination Mac has passed an
  authenticated reachability check.
- Prefer a slightly slower reliable handoff over parallel operations that can
  strand input devices.
- The two Macs must not depend on the same LAN or a public relay.
- Configuration should answer four questions only: which display, which edge,
  how long to dwell, and which peripherals to move.
- Avoid permissions that are not required. Pointer polling must remain usable
  without Accessibility access.
