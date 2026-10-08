import AppKit
import Combine
import SwiftUI

/// Configuration for hands-free peripheral handoff when the pointer dwells at
/// a chosen physical edge of one display.
struct EdgeSwitchSettingsView: View {
  @ObservedObject private var bluetoothStore = BluetoothPeripheralStore.shared
  @ObservedObject private var networkStore = NetworkDeviceStore.shared
  @ObservedObject private var pairingStore = PairingStore.shared

  @AppStorage(EdgeSwitchPreferences.enabledKey) private var isEnabled = false
  @AppStorage(EdgeSwitchPreferences.displayIDKey) private var displayID = ""
  @AppStorage(EdgeSwitchPreferences.edgeKey) private var edgeRaw = EdgeSwitchEdge.right.rawValue
  @AppStorage(EdgeSwitchPreferences.dwellSecondsKey) private var dwellSeconds = 1.5
  @AppStorage(EdgeSwitchPreferences.peripheralIDsKey) private var peripheralIDsData = Data()

  @State private var displays: [DisplayChoice] = []

  private struct DisplayChoice: Identifiable, Equatable {
    let id: String
    let label: String
  }

  private var selectedPeripheralIDs: Set<String> {
    EdgeSwitchPreferences.peripheralIDs(from: peripheralIDsData)
  }

  private var hasReachablePeer: Bool {
    pairingStore.isPaired && networkStore.networkDevices.contains(where: { $0.isActive })
  }

  private var configuredDisplayIsAvailable: Bool {
    displays.contains(where: { $0.id == displayID })
  }

  private var content: some View {
    Form {
      Section {
        Toggle("Enable edge switch", isOn: $isEnabled)

        Text(
          "Hold the pointer at the configured display edge. After the delay, iMacSwitch releases only the selected peripherals to the paired Mac."
        )
        .font(.callout)
        .foregroundColor(.secondary)
      }

      Section(header: Text("Trigger")) {
        Picker("Display", selection: $displayID) {
          if displays.isEmpty {
            Text("No display available").tag("")
          } else {
            ForEach(displays) { display in
              Text(display.label).tag(display.id)
            }
            if !displayID.isEmpty && !configuredDisplayIsAvailable {
              Text("Previously selected display (unavailable)").tag(displayID)
            }
          }
        }
        .disabled(!isEnabled || displays.isEmpty)

        if isEnabled && !configuredDisplayIsAvailable {
          Label(
            "The selected display is disconnected. Reconnect it or choose another display.",
            systemImage: "display.trianglebadge.exclamationmark"
          )
          .font(.caption)
          .foregroundColor(.orange)
        }

        Picker("Edge", selection: $edgeRaw) {
          ForEach(EdgeSwitchEdge.allCases) { edge in
            Label(edge.label, systemImage: edge.symbolName).tag(edge.rawValue)
          }
        }
        .pickerStyle(.segmented)
        .disabled(!isEnabled)

        Stepper(value: $dwellSeconds, in: 0.5...10, step: 0.5) {
          HStack {
            Text("Hold duration")
            Spacer()
            Text(formattedDwellSeconds)
              .foregroundColor(.secondary)
          }
        }
        .disabled(!isEnabled)

        Text(
          "Choose a physical outer edge. At an edge shared by two local displays, the pointer normally crosses to the other display instead of remaining there."
        )
        .font(.caption)
        .foregroundColor(.secondary)
      }

      Section(header: Text("Peripherals to Release")) {
        if bluetoothStore.peripherals.isEmpty {
          Text("Add peripherals in the Peripheral tab first.")
            .foregroundColor(.secondary)
        } else {
          ForEach(bluetoothStore.peripherals) { peripheral in
            Toggle(isOn: peripheralSelectionBinding(for: peripheral.id)) {
              Label(
                peripheral.name,
                systemImage: bluetoothStore.peripheralType(for: peripheral).symbolName)
            }
            .disabled(!isEnabled)
          }

          HStack {
            Button("Select All") {
              setSelectedPeripheralIDs(Set(bluetoothStore.peripherals.map(\.id)))
            }
            Button("Clear") { setSelectedPeripheralIDs([]) }
            Spacer()
          }
          .buttonStyle(.link)
          .disabled(!isEnabled)
        }

        if isEnabled && selectedPeripheralIDs.isEmpty {
          Label("Select at least one peripheral.", systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundColor(.orange)
        }

        if isEnabled && !hasReachablePeer {
          Label(
            "The paired Mac is not reachable right now. Nothing will be released until it appears.",
            systemImage: "wifi.exclamationmark"
          )
          .font(.caption)
          .foregroundColor(.secondary)
        }
      }
    }
    .onAppear {
      refreshDisplays()
      bluetoothStore.fetchConnectedPeripherals()
      seedPeripheralSelectionIfNeeded()
    }
    .onReceive(
      NotificationCenter.default.publisher(
        for: NSApplication.didChangeScreenParametersNotification)
    ) { _ in
      refreshDisplays()
    }
  }

  var body: some View {
    if #available(macOS 13.0, *) {
      content.formStyle(.grouped)
    } else {
      content
    }
  }

  private var formattedDwellSeconds: String {
    dwellSeconds.rounded() == dwellSeconds
      ? String(format: "%.0f seconds", dwellSeconds)
      : String(format: "%.1f seconds", dwellSeconds)
  }

  private func peripheralSelectionBinding(for id: String) -> Binding<Bool> {
    Binding(
      get: { selectedPeripheralIDs.contains(id) },
      set: { selected in
        var values = selectedPeripheralIDs
        if selected {
          values.insert(id)
        } else {
          values.remove(id)
        }
        setSelectedPeripheralIDs(values)
      })
  }

  private func setSelectedPeripheralIDs(_ ids: Set<String>) {
    peripheralIDsData = EdgeSwitchPreferences.encodedPeripheralIDs(ids)
  }

  /// First-time users start with the currently managed set selected, while a
  /// deliberately-cleared persisted selection remains empty on later visits.
  private func seedPeripheralSelectionIfNeeded() {
    guard UserDefaults.standard.object(forKey: EdgeSwitchPreferences.peripheralIDsKey) == nil,
      !bluetoothStore.peripherals.isEmpty
    else { return }
    setSelectedPeripheralIDs(Set(bluetoothStore.peripherals.map(\.id)))
  }

  private func refreshDisplays() {
    displays = NSScreen.screens.compactMap { screen in
      guard let id = EdgeSwitchPreferences.displayID(for: screen) else { return nil }
      let width = Int(screen.frame.width)
      let height = Int(screen.frame.height)
      return DisplayChoice(id: id, label: "\(screen.localizedName) (\(width) × \(height))")
    }

    if displayID.isEmpty {
      let mainID = NSScreen.main.flatMap(EdgeSwitchPreferences.displayID(for:))
      displayID = mainID ?? displays.first?.id ?? ""
    }
  }
}

#Preview {
  EdgeSwitchSettingsView()
}
