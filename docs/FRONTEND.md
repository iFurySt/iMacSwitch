# macOS UI

The interface is native SwiftUI hosted from AppKit because the application is
an `LSUIElement` menu-bar process.

- `DropdownContentView` is the status-menu surface and fallback manual control.
- `SettingsView` owns a fixed-size tabbed settings window created by
  `AppDelegate`; do not route it back through SwiftUI's otherwise invisible
  Settings scene without revalidating LSUIElement behavior.
- Long operations expose explicit connecting/releasing states and disable
  duplicate actions.
- Settings must not install global event taps. Edge detection uses global
  pointer position only and therefore avoids Accessibility permission.

Manual UI verification should cover normal and dark appearance, all Settings
tabs, missing-peer warnings, and long peripheral names.
