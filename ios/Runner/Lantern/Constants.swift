
//
//  Constants.swift
//  Runner
//

import Foundation

struct Constants {
  // MARK: Convenience Inits
  // MARK: Project Constants
  static let appBundleId = "org.getlantern.lantern"
  static let netExBundleId = "org.getlantern.lantern.Tunnel"
  static let appGroupName = "group.getlantern.lantern"
  static let bandwidthData = "bandwidthData"
  static let configupdate = "configUpdate"
  static let statsData = "statsData"
  // MARK: App Group
  static let appGroupDefaults = UserDefaults(suiteName: appGroupName)!
  static var appGroupContainerURL: URL {
    // implicitly unwrapped because the app cant work without this, might as well crash.
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)!
  }

  // Create lantern dir at start all other sub folder can create by other service
  // All folder creation should happnen at only once place
  static var lanternDirectory: URL {

    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
      .first!.appendingPathComponent(".lanternservice")
  }

  // MARK: App/NetEx Message Data
  static let configUpdatedMessageData = "Flashlight.ConfigUpdated".data(using: .utf8)!
  static let configUpdatedACKData = "Flashlight.TunnelUpdated".data(using: .utf8)!
  static let requestReadWriteCountMessageData = "Flashlight.ReadWriteCount".data(using: .utf8)!

  // Key used for passing reason from app->netEx when startTunnel is called
  static let netExStartReasonKey: String = "netEx.StartReason"

  // Key used in shared UserDefaults for caching user-selected locale
  static let localeSharedDefaultsKey = "Localization.SelectedLocale"

  static let defaultLogRotationFileCount = 5

  // MARK: Pro
  static let isPro = "is_pro"

  // MARK: User IDs
  static let userID = "user_id"
  static let proToken = "pro_token"

  // MARK: Privacy Policy
  static let acceptedPrivacyPolicyVersion = "accepted_privacy_policy_version"
  static let currentPrivacyPolicyVersion = 1

  // MARK: Tunnel Settings
  static let capturedDNSHost = "8.8.8.8"
  static let realDNSHost = "8.8.4.4"

  // MARK: Directory URLs

  let sharedContainerURL: URL
  let configDirectoryURL: URL
  let appDirectoryURL: URL
  let netExDirectoryURL: URL

  let targetDirectoryURL: URL  // convenience

  // MARK: Log Base URLs

  var goLogBaseURL: URL { return targetDirectoryURL.appendingPathComponent("lantern.log") }
  var heapProfileURL: URL { return targetDirectoryURL.appendingPathComponent("heap.profile") }
  var heapProfileTempURL: URL {
    return targetDirectoryURL.appendingPathComponent("heap.profile.tmp")
  }
  var goroutineProfileURL: URL {
    return targetDirectoryURL.appendingPathComponent("goroutine_profile.txt")
  }
  var goroutineProfileTempURL: URL {
    return targetDirectoryURL.appendingPathComponent("goroutine_profile.txt.tmp")
  }

  // MARK: Config URLs

  var configURL: URL { return configDirectoryURL.appendingPathComponent("global.yaml") }
  var configEtagURL: URL { return configDirectoryURL.appendingPathComponent("global.yaml.etag") }
  var proxiesURL: URL { return configDirectoryURL.appendingPathComponent("proxies.yaml") }
  var proxyStatsURL: URL { return configDirectoryURL.appendingPathComponent("proxystats.csv") }
  var proxyStatsTempURL: URL {
    return configDirectoryURL.appendingPathComponent("proxystats.csv.tmp")
  }
  var proxiesEtagURL: URL { return configDirectoryURL.appendingPathComponent("proxies.yaml.etag") }
  var tlsSessionStatesURL: URL {
    return configDirectoryURL.appendingPathComponent("tls_session_states")
  }
  var masqueradeCacheURL: URL {
    return configDirectoryURL.appendingPathComponent("masquerade_cache")
  }
  var userConfigURL: URL { return configDirectoryURL.appendingPathComponent("userconfig.yaml") }
  var quotaURL: URL { return configDirectoryURL.appendingPathComponent("quota.txt") }
  var dnsgrabCacheURL: URL { return configDirectoryURL.appendingPathComponent("dnsgrab.cache") }

  var allConfigURLs: [URL] {
    return [
      configURL, configEtagURL, proxiesURL, proxyStatsURL, proxyStatsTempURL, proxiesEtagURL,
      tlsSessionStatesURL, masqueradeCacheURL, userConfigURL, quotaURL, dnsgrabCacheURL,
    ]
  }

  // URL where app stores "excluded IPs" string from `IosConfigure`.
  // NetEx loads them to generate excluded routes on the TUN device.
  var excludedIPsURL: URL { return configDirectoryURL.appendingPathComponent("ips") }

}
