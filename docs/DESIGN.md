# Design

iMacSwitch is a background utility, not a dashboard. Its UI should remain
compact, native, and understandable without onboarding screens.

- Keep the status-bar icon quiet during normal operation and use directional
  feedback only while a handoff is active.
- Settings follow the actual setup order: peripherals, peer Mac, pairing,
  edge trigger, then secondary behavior.
- The Edge Switch screen exposes only display, edge, dwell time, and selected
  peripherals. Invalid or temporarily unavailable choices receive inline help.
- Use standard SwiftUI/AppKit controls and system symbols. Do not add a custom
  design system or web runtime.
- Preserve keyboard navigation, VoiceOver labels, and macOS light/dark mode.
