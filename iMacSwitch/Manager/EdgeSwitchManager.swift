import AppKit
import Foundation

/// Persisted edge-switch choices shared by the monitor and Settings UI.
enum EdgeSwitchPreferences {
  static let enabledKey = "edgeSwitchEnabled"
  static let displayIDKey = "edgeSwitchDisplayID"
  static let edgeKey = "edgeSwitchEdge"
  static let dwellSecondsKey = "edgeSwitchDwellSeconds"
  static let peripheralIDsKey = "edgeSwitchPeripheralIDs"

  static func displayID(for screen: NSScreen) -> String? {
    guard
      let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
        as? NSNumber
    else { return nil }
    let directDisplayID = CGDirectDisplayID(number.uint32Value)
    guard let uuid = CGDisplayCreateUUIDFromDisplayID(directDisplayID)?.takeRetainedValue()
    else { return number.stringValue }
    return CFUUIDCreateString(nil, uuid) as String
  }

  static func peripheralIDs(from data: Data) -> Set<String> {
    guard let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
    return Set(values)
  }

  static func encodedPeripheralIDs(_ values: Set<String>) -> Data {
    (try? JSONEncoder().encode(values.sorted())) ?? Data()
  }
}

enum EdgeSwitchEdge: String, CaseIterable, Identifiable {
  case left
  case right
  case top
  case bottom

  var id: String { rawValue }

  var label: String {
    switch self {
    case .left: return "Left"
    case .right: return "Right"
    case .top: return "Top"
    case .bottom: return "Bottom"
    }
  }

  var symbolName: String {
    switch self {
    case .left: return "arrow.left.to.line"
    case .right: return "arrow.right.to.line"
    case .top: return "arrow.up.to.line"
    case .bottom: return "arrow.down.to.line"
    }
  }
}

/// Watches the global pointer without an event tap (and therefore without an
/// Accessibility permission prompt). Holding the pointer at the configured
/// physical display edge triggers a selected-peripheral handoff once. The
/// pointer must leave the edge before another handoff can be triggered.
final class EdgeSwitchManager {
  static let shared = EdgeSwitchManager()

  private enum Constants {
    static let sampleInterval: TimeInterval = 0.1
    static let triggerZoneWidth: CGFloat = 3
    static let rearmZoneWidth: CGFloat = 16
  }

  private let defaults = UserDefaults.standard
  private var timer: DispatchSourceTimer?
  private var dwellStartedAt: Date?
  private var isArmed = true
  private var lastConfigurationSignature = ""

  private init() {}

  func start() {
    guard timer == nil else { return }
    let source = DispatchSource.makeTimerSource(queue: .main)
    source.schedule(
      deadline: .now(), repeating: Constants.sampleInterval,
      leeway: .milliseconds(20))
    source.setEventHandler { [weak self] in self?.samplePointer() }
    timer = source
    source.resume()
  }

  func stop() {
    timer?.cancel()
    timer = nil
    reset(rearm: true)
  }

  private func samplePointer() {
    let enabled = defaults.bool(forKey: EdgeSwitchPreferences.enabledKey)
    let displayID = defaults.string(forKey: EdgeSwitchPreferences.displayIDKey) ?? ""
    let edgeRaw = defaults.string(forKey: EdgeSwitchPreferences.edgeKey) ?? "right"
    let dwellValue = defaults.double(forKey: EdgeSwitchPreferences.dwellSecondsKey)
    let dwellSeconds = min(max(dwellValue == 0 ? 1.5 : dwellValue, 0.5), 10)
    let peripheralData = defaults.data(forKey: EdgeSwitchPreferences.peripheralIDsKey) ?? Data()
    let signature =
      "\(enabled)|\(displayID)|\(edgeRaw)|\(dwellSeconds)|\(peripheralData.base64EncodedString())"

    if signature != lastConfigurationSignature {
      lastConfigurationSignature = signature
      reset(rearm: true)
    }

    guard enabled, !displayID.isEmpty,
      let edge = EdgeSwitchEdge(rawValue: edgeRaw),
      let screen = NSScreen.screens.first(where: {
        EdgeSwitchPreferences.displayID(for: $0) == displayID
      })
    else {
      reset(rearm: true)
      return
    }

    let pointer = NSEvent.mouseLocation
    if !isArmed {
      if !isInEdgeZone(
        point: pointer, screen: screen, edge: edge,
        width: Constants.rearmZoneWidth)
      {
        reset(rearm: true)
      }
      return
    }

    guard
      isInEdgeZone(
        point: pointer, screen: screen, edge: edge,
        width: Constants.triggerZoneWidth)
    else {
      dwellStartedAt = nil
      return
    }

    if dwellStartedAt == nil {
      dwellStartedAt = Date()
      return
    }
    guard Date().timeIntervalSince(dwellStartedAt!) >= dwellSeconds else { return }

    // Disarm before beginning asynchronous work. Even if the peer is missing
    // or no selected peripheral is connected, the pointer must leave the edge
    // before another attempt, avoiding a notification/retry loop.
    isArmed = false
    dwellStartedAt = nil

    let selectedIDs = EdgeSwitchPreferences.peripheralIDs(from: peripheralData)
    let store = BluetoothPeripheralStore.shared
    let selected = store.peripherals.filter { selectedIDs.contains($0.id) }
    guard !selected.isEmpty else { return }

    print(
      "Edge switch triggered at \(screen.localizedName) \(edge.rawValue) edge for \(selected.count) peripheral(s)"
    )
    store.sendPeripheralsToPeer(selected)
  }

  private func reset(rearm: Bool) {
    dwellStartedAt = nil
    if rearm { isArmed = true }
  }

  private func isInEdgeZone(
    point: CGPoint,
    screen: NSScreen,
    edge: EdgeSwitchEdge,
    width: CGFloat
  ) -> Bool {
    let frame = screen.frame
    // Add a one-point margin for coordinates exactly on a screen boundary;
    // CGRect.contains excludes its maximum X/Y edge.
    guard frame.insetBy(dx: -1, dy: -1).contains(point) else { return false }

    switch edge {
    case .left: return point.x <= frame.minX + width
    case .right: return point.x >= frame.maxX - width
    case .top: return point.y >= frame.maxY - width
    case .bottom: return point.y <= frame.minY + width
    }
  }
}
