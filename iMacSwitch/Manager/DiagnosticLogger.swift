import AppKit
import CoreBluetooth
import CryptoKit
import Foundation

/// Privacy-conscious persistent diagnostics for handoff failures.
///
/// Events are JSON Lines so two exports can be sorted by `timestamp_ms` and
/// compared directly. Files are bounded and rotated locally; nothing is ever
/// uploaded. Callers must hash device, peer, and network identifiers with
/// `token(_:)` before placing them in fields.
final class DiagnosticLogger {
  static let shared = DiagnosticLogger()

  enum Level: String, Codable {
    case debug
    case info
    case warning
    case error
  }

  private struct Event: Codable {
    let timestamp: String
    let timestampMS: Int64
    let level: String
    let category: String
    let event: String
    let operationID: String?
    let installationID: String
    let sessionID: String
    let appVersion: String
    let appBuild: String
    let fields: [String: String]

    enum CodingKeys: String, CodingKey {
      case timestamp
      case timestampMS = "timestamp_ms"
      case level
      case category
      case event
      case operationID = "operation_id"
      case installationID = "installation_id"
      case sessionID = "session_id"
      case appVersion = "app_version"
      case appBuild = "app_build"
      case fields
    }
  }

  private enum Constants {
    static let installationIDKey = "com.ifuryst.imacswitch.diagnostics.installationID"
    static let directoryName = "Diagnostics"
    static let currentFileName = "events.jsonl"
    static let maxFileBytes: UInt64 = 1_500_000
    static let rotatedFileCount = 4
  }

  private let queue = DispatchQueue(label: "com.ifuryst.imacswitch.diagnostics")
  private let encoder: JSONEncoder
  private let timestampFormatter: ISO8601DateFormatter
  private let installationID: String
  private let sessionID = UUID().uuidString.lowercased()
  private let directoryURL: URL?

  private init() {
    let defaults = UserDefaults.standard
    if let existing = defaults.string(forKey: Constants.installationIDKey) {
      installationID = existing
    } else {
      let created = UUID().uuidString.lowercased()
      defaults.set(created, forKey: Constants.installationIDKey)
      installationID = created
    }

    encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    timestampFormatter = ISO8601DateFormatter()
    timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first
    directoryURL = base?
      .appendingPathComponent("iMacSwitch", isDirectory: true)
      .appendingPathComponent(Constants.directoryName, isDirectory: true)
    if let directoryURL {
      do {
        try FileManager.default.createDirectory(
          at: directoryURL, withIntermediateDirectories: true)
      } catch {
        NSLog(
          "iMacSwitch diagnostics: couldn't create log directory: %@",
          error.localizedDescription)
      }
    }
  }

  /// Stable across both Macs for the same input, while keeping raw identifiers
  /// out of exported files. Twelve SHA-256 bytes are enough for correlation.
  static func token(_ value: String) -> String {
    let digest = SHA256.hash(data: Data(value.lowercased().utf8))
    return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
  }

  static func newOperationID() -> String {
    UUID().uuidString.lowercased()
  }

  func log(
    _ level: Level = .info,
    category: String,
    event: String,
    operationID: String? = nil,
    fields: [String: String] = [:],
    flush: Bool = false
  ) {
    let now = Date()
    queue.async { [weak self] in
      self?.write(
        level: level,
        category: category,
        eventName: event,
        operationID: operationID,
        fields: fields,
        at: now,
        flush: flush)
    }
  }

  /// Power-transition callbacks use this so the evidence is on disk before
  /// the radio and process can be suspended.
  func logSynchronously(
    _ level: Level = .info,
    category: String,
    event: String,
    operationID: String? = nil,
    fields: [String: String] = [:]
  ) {
    let now = Date()
    queue.sync {
      write(
        level: level,
        category: category,
        eventName: event,
        operationID: operationID,
        fields: fields,
        at: now,
        flush: true)
    }
  }

  /// Concatenates oldest-to-newest rotated events into one portable JSONL file.
  /// The save-panel URL is user-authorized, so this works in the app sandbox.
  func export(to destination: URL) throws {
    try queue.sync {
      let header = [
        "format": "iMacSwitch diagnostics v1",
        "exported_at": timestampFormatter.string(from: Date()),
        "installation_id": installationID,
        "session_id": sessionID,
        "app_version": appVersion,
        "app_build": appBuild,
        "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
        "architecture": Self.architecture,
      ]
      var output = try encoder.encode(header)
      output.append(0x0A)
      for url in logFileURLsOldestFirst() {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { continue }
        output.append(data)
        if output.last != 0x0A { output.append(0x0A) }
      }
      try output.write(to: destination, options: .atomic)
    }
  }

  private func write(
    level: Level,
    category: String,
    eventName: String,
    operationID: String?,
    fields: [String: String],
    at date: Date,
    flush: Bool
  ) {
    guard let directoryURL else { return }
    do {
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      let currentURL = directoryURL.appendingPathComponent(Constants.currentFileName)
      if currentFileSize(at: currentURL) >= Constants.maxFileBytes {
        try rotateLogs(in: directoryURL)
      }
      let record = Event(
        timestamp: timestampFormatter.string(from: date),
        timestampMS: Int64((date.timeIntervalSince1970 * 1000).rounded()),
        level: level.rawValue,
        category: category,
        event: eventName,
        operationID: operationID,
        installationID: installationID,
        sessionID: sessionID,
        appVersion: appVersion,
        appBuild: appBuild,
        fields: fields)
      var data = try encoder.encode(record)
      data.append(0x0A)
      if !FileManager.default.fileExists(atPath: currentURL.path) {
        try Data().write(to: currentURL, options: .atomic)
      }
      let handle = try FileHandle(forWritingTo: currentURL)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: data)
      if flush { handle.synchronizeFile() }
    } catch {
      NSLog("iMacSwitch diagnostics write failed: %@", error.localizedDescription)
    }
  }

  private func rotateLogs(in directory: URL) throws {
    let fileManager = FileManager.default
    let oldest = directory.appendingPathComponent("events.\(Constants.rotatedFileCount).jsonl")
    if fileManager.fileExists(atPath: oldest.path) { try fileManager.removeItem(at: oldest) }
    if Constants.rotatedFileCount > 1 {
      for index in stride(from: Constants.rotatedFileCount - 1, through: 1, by: -1) {
        let source = directory.appendingPathComponent("events.\(index).jsonl")
        let destination = directory.appendingPathComponent("events.\(index + 1).jsonl")
        if fileManager.fileExists(atPath: source.path) {
          try fileManager.moveItem(at: source, to: destination)
        }
      }
    }
    let current = directory.appendingPathComponent(Constants.currentFileName)
    let first = directory.appendingPathComponent("events.1.jsonl")
    if fileManager.fileExists(atPath: current.path) {
      try fileManager.moveItem(at: current, to: first)
    }
  }

  private func logFileURLsOldestFirst() -> [URL] {
    guard let directoryURL else { return [] }
    var urls: [URL] = stride(from: Constants.rotatedFileCount, through: 1, by: -1)
      .map { directoryURL.appendingPathComponent("events.\($0).jsonl") }
    urls.append(directoryURL.appendingPathComponent(Constants.currentFileName))
    return urls
  }

  private func currentFileSize(at url: URL) -> UInt64 {
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
  }

  private var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
  }

  private var appBuild: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
  }

  private static var architecture: String {
    #if arch(arm64)
      return "arm64"
    #elseif arch(x86_64)
      return "x86_64"
    #else
      return "unknown"
    #endif
  }
}

/// Presents the user-owned export location and records a current state snapshot
/// immediately before the rolling files are copied.
final class DiagnosticsExporter {
  static let shared = DiagnosticsExporter()

  private init() {}

  /// `nil` means the user cancelled the save panel.
  func export(completion: @escaping (Result<URL, Error>?) -> Void) {
    precondition(Thread.isMainThread)
    recordCurrentSnapshot()

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let panel = NSSavePanel()
    panel.title = "Export iMacSwitch Diagnostics"
    panel.prompt = "Export"
    panel.nameFieldStringValue = "iMacSwitch-Diagnostics-\(formatter.string(from: Date())).jsonl"
    panel.allowedFileTypes = ["jsonl"]
    panel.canCreateDirectories = true
    panel.begin { response in
      guard response == .OK, let url = panel.url else {
        completion(nil)
        return
      }
      do {
        try DiagnosticLogger.shared.export(to: url)
        DiagnosticLogger.shared.log(
          category: "diagnostics", event: "export_succeeded",
          fields: ["destination": "user_selected"])
        completion(.success(url))
      } catch {
        DiagnosticLogger.shared.log(
          .error, category: "diagnostics", event: "export_failed",
          fields: ["error": String(describing: type(of: error))])
        completion(.failure(error))
      }
    }
  }

  private func recordCurrentSnapshot() {
    let bluetoothStore = BluetoothPeripheralStore.shared
    let networkStore = NetworkDeviceStore.shared
    let peripheralSummary = bluetoothStore.peripherals.map { peripheral in
      let state: String
      switch bluetoothStore.connectionState(for: peripheral.id) {
      case .disconnected: state = "disconnected"
      case .connecting: state = "connecting"
      case .releasing: state = "releasing"
      case .connected: state = "connected"
      }
      return "\(DiagnosticLogger.token(peripheral.id)):\(state)"
    }.joined(separator: ",")
    let peerSummary = networkStore.networkDevices.map { peer in
      "\(DiagnosticLogger.token(peer.id)):\(peer.isActive ? "active" : "inactive")"
    }.joined(separator: ",")
    let defaults = UserDefaults.standard
    let releaseOnSleep =
      defaults.object(forKey: BluetoothPeripheralStore.releaseOnSleepDefaultsKey) as? Bool ?? true
    let autoReconnect =
      defaults.object(forKey: BluetoothPeripheralStore.autoReconnectDefaultsKey) as? Bool ?? true

    DiagnosticLogger.shared.logSynchronously(
      category: "diagnostics",
      event: "export_snapshot",
      fields: [
        "bluetooth_state": Self.bluetoothStateName(BluetoothManager.shared.state),
        "paired": String(PairingStore.shared.isPaired),
        "release_on_sleep": String(releaseOnSleep),
        "auto_reconnect": String(autoReconnect),
        "peripherals": peripheralSummary,
        "peers": peerSummary,
        "system_uptime_seconds": String(Int(ProcessInfo.processInfo.systemUptime)),
      ])
  }

  private static func bluetoothStateName(_ state: CBManagerState) -> String {
    switch state {
    case .unknown: return "unknown"
    case .resetting: return "resetting"
    case .unsupported: return "unsupported"
    case .unauthorized: return "unauthorized"
    case .poweredOff: return "powered_off"
    case .poweredOn: return "powered_on"
    @unknown default: return "future"
    }
  }
}
