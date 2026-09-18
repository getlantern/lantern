//
//  VPNWidgetState.swift
//  Shared
//
//  Snapshot of the VPN connection that the WidgetKit extension renders.
//
//  The widget runs in its own process and cannot observe NEVPNStatusDidChange,
//  so the app and the tunnel extension both publish here (app group defaults)
//  and poke WidgetKit whenever the snapshot changes. Writes are idempotent:
//  both processes may record the same transition and only the first reloads.
//

import Foundation
import NetworkExtension
import WidgetKit

public enum VPNWidgetStatus: String, Codable {
  case disconnected
  case connecting
  case connected
  case disconnecting

  public var isOn: Bool { self == .connected }
  public var isTransitioning: Bool { self == .connecting || self == .disconnecting }
}

public struct VPNWidgetState: Codable, Equatable {
  public var status: VPNWidgetStatus
  /// Server tag the user last connected with ("auto" for the automatic pick).
  public var serverName: String
  /// Human-readable location resolved by the app ("Frankfurt, Germany"),
  /// empty until the app has fetched it.
  public var locationName: String
  /// City and country as separate parts so each family can pick its own
  /// detail level; empty when unknown.
  public var city: String
  public var country: String
  /// ISO 3166-1 alpha-2 code for the flag; empty when unknown.
  public var countryCode: String
  /// True when the widget found no VPN profile: the app has never been
  /// granted VPN permission, so a tap must open the app instead.
  public var needsSetup: Bool
  public var updatedAt: Date

  public static let initial = VPNWidgetState(
    status: .disconnected, serverName: VPNWidgetState.autoServerName, updatedAt: .distantPast)

  public static let autoServerName = "auto"

  public init(
    status: VPNWidgetStatus,
    serverName: String,
    locationName: String = "",
    city: String = "",
    country: String = "",
    countryCode: String = "",
    needsSetup: Bool = false,
    updatedAt: Date
  ) {
    self.status = status
    self.serverName = serverName
    self.locationName = locationName
    self.city = city
    self.country = country
    self.countryCode = countryCode
    self.needsSetup = needsSetup
    self.updatedAt = updatedAt
  }

  // Tolerate snapshots written before the location fields existed.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    status = try c.decode(VPNWidgetStatus.self, forKey: .status)
    serverName = try c.decode(String.self, forKey: .serverName)
    locationName = try c.decodeIfPresent(String.self, forKey: .locationName) ?? ""
    city = try c.decodeIfPresent(String.self, forKey: .city) ?? ""
    country = try c.decodeIfPresent(String.self, forKey: .country) ?? ""
    countryCode = try c.decodeIfPresent(String.self, forKey: .countryCode) ?? ""
    needsSetup = try c.decodeIfPresent(Bool.self, forKey: .needsSetup) ?? false
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
  }

  public var isAutoServer: Bool { serverName.isEmpty || serverName == Self.autoServerName }

  /// Regional-indicator flag for `countryCode`, or nil when unknown.
  public var flagEmoji: String? {
    let code = countryCode.uppercased()
    guard code.count == 2, code.allSatisfy({ $0.isLetter }) else { return nil }
    var flag = ""
    for scalar in code.unicodeScalars {
      guard let indicator = UnicodeScalar(127397 + scalar.value) else { return nil }
      flag.unicodeScalars.append(indicator)
    }
    return flag
  }
}

public enum VPNWidgetStore {
  /// `kind` of the home / lock screen widget; must match `LanternVPNWidget`.
  public static let widgetKind = "LanternVPNWidget"
  /// `kind` of the iOS 18 Control Center toggle; must match `LanternVPNControlWidget`.
  public static let controlKind = "LanternVPNControl"

  private static let stateKey = "vpn_widget_state"

  private static let defaults = UserDefaults(suiteName: FilePath.groupName)

  private static let encoder = JSONEncoder()
  private static let decoder = JSONDecoder()

  public static func load() -> VPNWidgetState {
    guard let data = defaults?.data(forKey: stateKey),
      let state = try? decoder.decode(VPNWidgetState.self, from: data)
    else { return .initial }
    return state
  }

  /// Applies `mutate` to the stored snapshot and, if anything changed, saves it
  /// and (unless `reload` is false) asks WidgetKit to re-render. Pass
  /// `reload: false` from inside a timeline request to avoid a reload loop.
  @discardableResult
  public static func update(reload: Bool = true, _ mutate: (inout VPNWidgetState) -> Void)
    -> VPNWidgetState
  {
    let previous = load()
    var next = previous
    mutate(&next)
    guard next != previous.withUpdatedAt(next.updatedAt) else { return previous }
    next.updatedAt = Date()
    guard let data = try? encoder.encode(next) else { return previous }
    defaults?.set(data, forKey: stateKey)
    if reload { reloadWidgets() }
    return next
  }

  public static func setStatus(_ status: VPNWidgetStatus) {
    update { $0.status = status }
  }

  public static func setNeedsSetup(_ needsSetup: Bool) {
    update { $0.needsSetup = needsSetup }
  }

  public static func setServerName(_ serverName: String) {
    update { $0.serverName = serverName.isEmpty ? VPNWidgetState.autoServerName : serverName }
  }

  /// Called by the app once radiance has told it where the tunnel exits.
  public static func setLocation(name: String, city: String, country: String, countryCode: String)
  {
    update {
      $0.locationName = name
      $0.city = city
      $0.country = country
      $0.countryCode = countryCode
    }
  }

  public static func reloadWidgets() {
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    if #available(iOS 18.0, *) {
      ControlCenter.shared.reloadControls(ofKind: controlKind)
    }
  }
}

public enum VPNWidgetAction: String {
  case toggle
  case connect
  case disconnect
}

extension VPNWidgetState {
  fileprivate func withUpdatedAt(_ date: Date) -> VPNWidgetState {
    var copy = self
    copy.updatedAt = date
    return copy
  }
}

extension NEVPNStatus {
  /// Status to publish, or nil to leave the snapshot alone. `.reasserting`
  /// is nil: the tunnel is still up, and it flips on every network change,
  /// so publishing it would burn two reloads each time.
  public var widgetStatus: VPNWidgetStatus? {
    switch self {
    case .connected: return .connected
    case .connecting: return .connecting
    case .reasserting: return nil
    case .disconnecting: return .disconnecting
    case .disconnected, .invalid: return .disconnected
    @unknown default: return .disconnected
    }
  }
}
