//
//  LanternFFI.swift
//  Lantern
//
//  Swift wrapper for liblantern.dylib FFI calls.
//  This replaces the gomobile Liblantern.xcframework.
//

import Foundation
import OSLog

/// Singleton class that provides Swift-friendly wrappers for liblantern.dylib FFI functions.
/// Used by both Runner (main app) and can be adapted for PacketTunnel extension.
final class LanternFFI {
  static let shared = LanternFFI()

  private let logger = Logger(subsystem: "org.getlantern.lantern", category: "FFI")
  private var dylibHandle: UnsafeMutableRawPointer?
  private var isLoaded = false

  private init() {}

  // MARK: - Library Loading

  /// Loads the liblantern.dylib if not already loaded.
  /// The dylib should be in the Frameworks folder of the app bundle.
  func loadLibrary() -> Bool {
    guard !isLoaded else { return true }

    // Try to find the dylib in the Frameworks folder
    let frameworksPath = Bundle.main.privateFrameworksPath ?? ""
    let dylibPath = (frameworksPath as NSString).appendingPathComponent("liblantern.dylib")

    logger.info("Loading liblantern.dylib from: \(dylibPath)")

    dylibHandle = dlopen(dylibPath, RTLD_NOW | RTLD_GLOBAL)
    if dylibHandle == nil {
      let error = String(cString: dlerror())
      logger.error("Failed to load liblantern.dylib: \(error)")
      return false
    }

    isLoaded = true
    logger.info("Successfully loaded liblantern.dylib")
    return true
  }

  // MARK: - String Helpers

  /// Converts a Swift String to a C string (char*) for FFI calls.
  /// The caller is responsible for freeing the returned pointer.
  private func toCString(_ string: String) -> UnsafeMutablePointer<CChar> {
    return strdup(string)
  }

  /// Converts a C string result to Swift String and frees the C memory.
  private func fromCString(_ cstr: UnsafeMutablePointer<CChar>?) -> String {
    guard let cstr = cstr else { return "" }
    let result = String(cString: cstr)
    freeCString(cstr)
    return result
  }

  /// Checks if a result string indicates an error (contains "error" key in JSON).
  private func isErrorResult(_ result: String) -> Bool {
    return result.contains("\"error\"")
  }

  // MARK: - Setup

  /// Initializes the Lantern service with the given parameters.
  /// This should be called once at app startup.
  func setupRadiance(
    logDir: String,
    dataDir: String,
    locale: String,
    telemetryConsent: Bool
  ) throws {
    let result = fromCString(
      lantern_setup(
        toCString(logDir),
        toCString(dataDir),
        toCString(locale),
        0,  // logP - Dart port (not used in Swift)
        0,  // appsP - Dart port (not used in Swift)
        0,  // statusP - Dart port (not used in Swift)
        0,  // privateServerP - Dart port (not used in Swift)
        0,  // appEventP - Dart port (not used in Swift)
        telemetryConsent ? 1 : 0,
        nil  // api pointer (not used)
      ))

    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  // MARK: - VPN Operations

  func startVPN() throws -> String {
    let dataDir = FilePath.dataDirectory.path
    let logDir = FilePath.logsDirectory.path
    let locale = Locale.current.identifier

    let result = fromCString(
      lantern_startVPN(
        toCString(logDir),
        toCString(dataDir),
        toCString(locale)
      ))

    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func stopVPN() throws -> String {
    let result = fromCString(lantern_stopVPN())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func connectToServer(location: String, serverName: String) throws -> String {
    let dataDir = FilePath.dataDirectory.path
    let logDir = FilePath.logsDirectory.path
    let locale = Locale.current.identifier

    let result = fromCString(
      lantern_connectToServer(
        toCString(location),
        toCString(serverName),
        toCString(logDir),
        toCString(dataDir),
        toCString(locale)
      ))

    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func isVPNConnected() -> Bool {
    return lantern_isVPNConnected() != 0
  }

  // MARK: - Auto Location

  func getAutoLocation() throws -> String {
    let result = fromCString(lantern_getAutoLocation())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func startAutoLocationListener() throws {
    let result = fromCString(lantern_startAutoLocationListener())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func stopAutoLocationListener() throws {
    let result = fromCString(lantern_stopAutoLocationListener())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  // MARK: - Servers

  func getAvailableServers() throws -> Data {
    let result = fromCString(lantern_getAvailableServers())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result.data(using: .utf8) ?? Data()
  }

  // MARK: - User Data

  func getUserData() throws -> String {
    let result = fromCString(lantern_getUserData())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func fetchUserData() throws -> String {
    let result = fromCString(lantern_fetchUserData())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  // MARK: - Authentication

  func login(email: String, password: String) throws -> String {
    let result = fromCString(
      lantern_login(
        toCString(email),
        toCString(password)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func signup(email: String, password: String) throws {
    let result = fromCString(
      lantern_signup(
        toCString(email),
        toCString(password)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func logout(email: String) throws -> String {
    let result = fromCString(lantern_logout(toCString(email)))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func deleteAccount(email: String, password: String) throws -> String {
    let result = fromCString(
      lantern_deleteAccount(
        toCString(email),
        toCString(password)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  // MARK: - OAuth

  func oauthLoginUrl(provider: String) throws -> String {
    let result = fromCString(lantern_oauthLoginUrl(toCString(provider)))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func oauthLoginCallback(token: String) throws -> String {
    let result = fromCString(lantern_oAuthLoginCallback(toCString(token)))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  // MARK: - Password Recovery

  func startRecoveryByEmail(email: String) throws {
    let result = fromCString(lantern_startRecoveryByEmail(toCString(email)))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func validateRecoveryCode(email: String, code: String) throws {
    let result = fromCString(
      lantern_validateEmailRecoveryCode(
        toCString(email),
        toCString(code)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func completeRecoveryByEmail(email: String, newPassword: String, code: String) throws {
    let result = fromCString(
      lantern_completeRecoveryByEmail(
        toCString(email),
        toCString(newPassword),
        toCString(code)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  // MARK: - Email Change

  func startChangeEmail(newEmail: String, password: String) throws {
    let result = fromCString(
      lantern_startChangeEmail(
        toCString(newEmail),
        toCString(password)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func completeChangeEmail(newEmail: String, password: String, code: String) throws {
    let result = fromCString(
      lantern_completeChangeEmail(
        toCString(newEmail),
        toCString(password),
        toCString(code)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  // MARK: - Device Management

  func removeDevice(deviceId: String) throws {
    let result = fromCString(lantern_removeDevice(toCString(deviceId)))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  // MARK: - Referral

  func referralAttachment(code: String) throws {
    let result = fromCString(lantern_referralAttachment(toCString(code)))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  // MARK: - Plans and Payments

  func plans() throws -> String {
    let result = fromCString(lantern_plans())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func stripeSubscriptionPaymentRedirect(type: String, planId: String, email: String) throws
    -> String
  {
    let result = fromCString(
      lantern_stripeSubscriptionPaymentRedirect(
        toCString(type),
        toCString(planId),
        toCString(email)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func paymentRedirect(provider: String, planId: String, email: String) throws -> String {
    let result = fromCString(
      lantern_paymentRedirect(
        toCString(planId),
        toCString(provider),
        toCString(email)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func stripeBillingPortalUrl() throws -> String {
    let result = fromCString(lantern_stripeBillingPortalUrl())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func activationCode(email: String, resellerCode: String) throws {
    let result = fromCString(
      lantern_activationCode(
        toCString(email),
        toCString(resellerCode)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  // MARK: - Data Cap

  func getDataCapInfo() throws -> String {
    let result = fromCString(lantern_getDataCapInfo())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  // MARK: - Feature Flags

  func availableFeatures() -> String {
    return fromCString(lantern_availableFeatures())
  }

  // MARK: - Locale

  func updateLocale(locale: String) throws {
    let result = fromCString(lantern_updateLocale(toCString(locale)))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  // MARK: - Telemetry

  func updateTelemetryConsent(consent: Bool) throws {
    let result = fromCString(lantern_updateTelemetryConsent(consent ? 1 : 0))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  // MARK: - Issue Reporting

  func reportIssue(
    email: String, issueType: String, description: String,
    device: String, model: String, logPath: String
  ) throws {
    let result = fromCString(
      lantern_reportIssue(
        toCString(email),
        toCString(issueType),
        toCString(description),
        toCString(device),
        toCString(model),
        toCString(logPath)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  // MARK: - Split Tunneling

  func addSplitTunnelItem(filterType: String, item: String) throws {
    let result = fromCString(
      lantern_addSplitTunnelItem(
        toCString(filterType),
        toCString(item)
      ))
    if let r = result as String?, isErrorResult(r) {
      throw FFIError.operationFailed(r)
    }
  }

  func removeSplitTunnelItem(filterType: String, item: String) throws {
    let result = fromCString(
      lantern_removeSplitTunnelItem(
        toCString(filterType),
        toCString(item)
      ))
    if let r = result as String?, isErrorResult(r) {
      throw FFIError.operationFailed(r)
    }
  }

  func setSplitTunnelingEnabled(enabled: Bool) throws {
    let result = fromCString(lantern_setSplitTunnelingEnabled(enabled ? 1 : 0))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func isSplitTunnelingEnabled() -> Bool {
    return lantern_isSplitTunnelingEnabled() != 0
  }

  func loadInstalledApps() throws -> String {
    return try loadInstalledApps(dataDir: FilePath.dataDirectory.path)
  }

  func loadInstalledApps(dataDir: String) throws -> String {
    let result = fromCString(lantern_loadInstalledApps(toCString(dataDir)))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  // MARK: - Block Ads

  func setBlockAdsEnabled(enabled: Bool) throws {
    let result = fromCString(lantern_setBlockAdsEnabled(enabled ? 1 : 0))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func isBlockAdsEnabled() -> Bool {
    return lantern_isBlockAdsEnabled() != 0
  }

  // MARK: - Smart Routing

  func setSmartRoutingEnabled(enabled: Bool) throws {
    let result = fromCString(lantern_setSmartRoutingEnabled(enabled ? 1 : 0))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func isSmartRoutingEnabled() -> Bool {
    return lantern_isSmartRoutingEnabled() != 0
  }

  // MARK: - Private Server Operations

  func digitalOceanPrivateServer() throws {
    let result = fromCString(lantern_digitalOceanPrivateServer())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func selectAccount(account: String) throws {
    let result = fromCString(lantern_selectAccount(toCString(account)))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func selectProject(project: String) throws {
    let result = fromCString(lantern_selectProject(toCString(project)))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func validateSession() throws {
    let result = fromCString(lantern_validateSession())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func startDeployment(location: String, serverName: String) throws {
    let result = fromCString(
      lantern_startDepolyment(
        toCString(location),
        toCString(serverName)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func cancelDeployment() throws {
    let result = fromCString(lantern_cancelDepolyment())
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func addServerManually(ip: String, port: String, accessToken: String, serverName: String) throws {
    let result = fromCString(
      lantern_addServerManagerInstance(
        toCString(ip),
        toCString(port),
        toCString(accessToken),
        toCString(serverName)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func inviteToServerManagerInstance(
    ip: String, port: String, accessToken: String, inviteName: String
  ) throws -> String {
    let result = fromCString(
      lantern_inviteToServerManagerInstance(
        toCString(ip),
        toCString(port),
        toCString(accessToken),
        toCString(inviteName)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
    return result
  }

  func revokeServerManagerInvite(ip: String, port: String, accessToken: String, inviteName: String)
    throws
  {
    let result = fromCString(
      lantern_revokeServerManagerInvite(
        toCString(ip),
        toCString(port),
        toCString(accessToken),
        toCString(inviteName)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }

  func addServerBasedOnURLs(urls: String, skipCertVerification: Bool, serverName: String) throws {
    let result = fromCString(
      lantern_addServerBasedOnURLs(
        toCString(urls),
        skipCertVerification ? 1 : 0,
        toCString(serverName)
      ))
    if isErrorResult(result) {
      throw FFIError.operationFailed(result)
    }
  }
}

// MARK: - FFI Error

enum FFIError: Error, LocalizedError {
  case libraryNotLoaded
  case operationFailed(String)

  var errorDescription: String? {
    switch self {
    case .libraryNotLoaded:
      return "liblantern.dylib is not loaded"
    case .operationFailed(let message):
      return message
    }
  }
}

// MARK: - C Function Wrappers

// These wrap the bridging header functions with lantern_ prefix to avoid conflicts

private func lantern_setup(
  _ logDir: UnsafeMutablePointer<CChar>,
  _ dataDir: UnsafeMutablePointer<CChar>,
  _ locale: UnsafeMutablePointer<CChar>,
  _ logP: Int64,
  _ appsP: Int64,
  _ statusP: Int64,
  _ privateServerP: Int64,
  _ appEventP: Int64,
  _ consent: Int32,
  _ api: UnsafeMutableRawPointer?
) -> UnsafeMutablePointer<CChar>? {
  return setup(logDir, dataDir, locale, logP, appsP, statusP, privateServerP, appEventP, consent, api)
}

private func lantern_startVPN(
  _ logDir: UnsafeMutablePointer<CChar>,
  _ dataDir: UnsafeMutablePointer<CChar>,
  _ locale: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return startVPN(logDir, dataDir, locale)
}

private func lantern_stopVPN() -> UnsafeMutablePointer<CChar>? {
  return stopVPN()
}

private func lantern_connectToServer(
  _ location: UnsafeMutablePointer<CChar>,
  _ tag: UnsafeMutablePointer<CChar>,
  _ logDir: UnsafeMutablePointer<CChar>,
  _ dataDir: UnsafeMutablePointer<CChar>,
  _ locale: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return connectToServer(location, tag, logDir, dataDir, locale)
}

private func lantern_isVPNConnected() -> Int32 {
  return isVPNConnected()
}

private func lantern_getAutoLocation() -> UnsafeMutablePointer<CChar>? {
  return getAutoLocation()
}

private func lantern_startAutoLocationListener() -> UnsafeMutablePointer<CChar>? {
  return startAutoLocationListener()
}

private func lantern_stopAutoLocationListener() -> UnsafeMutablePointer<CChar>? {
  return stopAutoLocationListener()
}

private func lantern_getAvailableServers() -> UnsafeMutablePointer<CChar>? {
  return getAvailableServers()
}

private func lantern_getUserData() -> UnsafeMutablePointer<CChar>? {
  return getUserData()
}

private func lantern_fetchUserData() -> UnsafeMutablePointer<CChar>? {
  return fetchUserData()
}

private func lantern_login(
  _ email: UnsafeMutablePointer<CChar>,
  _ password: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return login(email, password)
}

private func lantern_signup(
  _ email: UnsafeMutablePointer<CChar>,
  _ password: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return signup(email, password)
}

private func lantern_logout(_ email: UnsafeMutablePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
  return logout(email)
}

private func lantern_deleteAccount(
  _ email: UnsafeMutablePointer<CChar>,
  _ password: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return deleteAccount(email, password)
}

private func lantern_oauthLoginUrl(_ provider: UnsafeMutablePointer<CChar>)
  -> UnsafeMutablePointer<CChar>?
{
  return oauthLoginUrl(provider)
}

private func lantern_oAuthLoginCallback(_ token: UnsafeMutablePointer<CChar>)
  -> UnsafeMutablePointer<CChar>?
{
  return oAuthLoginCallback(token)
}

private func lantern_startRecoveryByEmail(_ email: UnsafeMutablePointer<CChar>)
  -> UnsafeMutablePointer<CChar>?
{
  return startRecoveryByEmail(email)
}

private func lantern_validateEmailRecoveryCode(
  _ email: UnsafeMutablePointer<CChar>,
  _ code: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return validateEmailRecoveryCode(email, code)
}

private func lantern_completeRecoveryByEmail(
  _ email: UnsafeMutablePointer<CChar>,
  _ newPassword: UnsafeMutablePointer<CChar>,
  _ code: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return completeRecoveryByEmail(email, newPassword, code)
}

private func lantern_startChangeEmail(
  _ newEmail: UnsafeMutablePointer<CChar>,
  _ password: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return startChangeEmail(newEmail, password)
}

private func lantern_completeChangeEmail(
  _ newEmail: UnsafeMutablePointer<CChar>,
  _ password: UnsafeMutablePointer<CChar>,
  _ code: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return completeChangeEmail(newEmail, password, code)
}

private func lantern_removeDevice(_ deviceId: UnsafeMutablePointer<CChar>)
  -> UnsafeMutablePointer<CChar>?
{
  return removeDevice(deviceId)
}

private func lantern_referralAttachment(_ code: UnsafeMutablePointer<CChar>)
  -> UnsafeMutablePointer<CChar>?
{
  return referralAttachment(code)
}

private func lantern_plans() -> UnsafeMutablePointer<CChar>? {
  return plans()
}

private func lantern_stripeSubscriptionPaymentRedirect(
  _ subType: UnsafeMutablePointer<CChar>,
  _ planId: UnsafeMutablePointer<CChar>,
  _ email: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return stripeSubscriptionPaymentRedirect(subType, planId, email)
}

private func lantern_paymentRedirect(
  _ plan: UnsafeMutablePointer<CChar>,
  _ provider: UnsafeMutablePointer<CChar>,
  _ email: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return paymentRedirect(plan, provider, email)
}

private func lantern_stripeBillingPortalUrl() -> UnsafeMutablePointer<CChar>? {
  return stripeBillingPortalUrl()
}

private func lantern_activationCode(
  _ email: UnsafeMutablePointer<CChar>,
  _ resellerCode: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return activationCode(email, resellerCode)
}

private func lantern_getDataCapInfo() -> UnsafeMutablePointer<CChar>? {
  return getDataCapInfo()
}

private func lantern_availableFeatures() -> UnsafeMutablePointer<CChar>? {
  return availableFeatures()
}

private func lantern_updateLocale(_ locale: UnsafeMutablePointer<CChar>)
  -> UnsafeMutablePointer<CChar>?
{
  return updateLocale(locale)
}

private func lantern_updateTelemetryConsent(_ consent: Int32) -> UnsafeMutablePointer<CChar>? {
  return updateTelemetryConsent(consent)
}

private func lantern_reportIssue(
  _ email: UnsafeMutablePointer<CChar>,
  _ issueType: UnsafeMutablePointer<CChar>,
  _ description: UnsafeMutablePointer<CChar>,
  _ device: UnsafeMutablePointer<CChar>,
  _ model: UnsafeMutablePointer<CChar>,
  _ logPath: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return reportIssue(email, issueType, description, device, model, logPath)
}

private func lantern_addSplitTunnelItem(
  _ filterType: UnsafeMutablePointer<CChar>,
  _ item: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return addSplitTunnelItem(filterType, item)
}

private func lantern_removeSplitTunnelItem(
  _ filterType: UnsafeMutablePointer<CChar>,
  _ item: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return removeSplitTunnelItem(filterType, item)
}

private func lantern_setSplitTunnelingEnabled(_ enabled: Int32) -> UnsafeMutablePointer<CChar>? {
  return setSplitTunnelingEnabled(enabled)
}

private func lantern_isSplitTunnelingEnabled() -> Int32 {
  return isSplitTunnelingEnabled()
}

private func lantern_loadInstalledApps(_ dataDir: UnsafeMutablePointer<CChar>)
  -> UnsafeMutablePointer<CChar>?
{
  return loadInstalledApps(dataDir)
}

private func lantern_setBlockAdsEnabled(_ enabled: Int32) -> UnsafeMutablePointer<CChar>? {
  return setBlockAdsEnabled(enabled)
}

private func lantern_isBlockAdsEnabled() -> Int32 {
  return isBlockAdsEnabled()
}

private func lantern_setSmartRoutingEnabled(_ enabled: Int32) -> UnsafeMutablePointer<CChar>? {
  return setSmartRoutingEnabled(enabled)
}

private func lantern_isSmartRoutingEnabled() -> Int32 {
  return isSmartRoutingEnabled()
}

private func lantern_digitalOceanPrivateServer() -> UnsafeMutablePointer<CChar>? {
  return digitalOceanPrivateServer()
}

private func lantern_selectAccount(_ account: UnsafeMutablePointer<CChar>)
  -> UnsafeMutablePointer<CChar>?
{
  return selectAccount(account)
}

private func lantern_selectProject(_ project: UnsafeMutablePointer<CChar>)
  -> UnsafeMutablePointer<CChar>?
{
  return selectProject(project)
}

private func lantern_validateSession() -> UnsafeMutablePointer<CChar>? {
  return validateSession()
}

private func lantern_startDepolyment(
  _ location: UnsafeMutablePointer<CChar>,
  _ serverName: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return startDepolyment(location, serverName)
}

private func lantern_cancelDepolyment() -> UnsafeMutablePointer<CChar>? {
  return cancelDepolyment()
}

private func lantern_addServerManagerInstance(
  _ ip: UnsafeMutablePointer<CChar>,
  _ port: UnsafeMutablePointer<CChar>,
  _ accessToken: UnsafeMutablePointer<CChar>,
  _ tag: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return addServerManagerInstance(ip, port, accessToken, tag)
}

private func lantern_inviteToServerManagerInstance(
  _ ip: UnsafeMutablePointer<CChar>,
  _ port: UnsafeMutablePointer<CChar>,
  _ accessToken: UnsafeMutablePointer<CChar>,
  _ inviteName: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return inviteToServerManagerInstance(ip, port, accessToken, inviteName)
}

private func lantern_revokeServerManagerInvite(
  _ ip: UnsafeMutablePointer<CChar>,
  _ port: UnsafeMutablePointer<CChar>,
  _ accessToken: UnsafeMutablePointer<CChar>,
  _ inviteName: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return revokeServerManagerInvite(ip, port, accessToken, inviteName)
}

private func lantern_addServerBasedOnURLs(
  _ urls: UnsafeMutablePointer<CChar>,
  _ skipCertVerification: Int32,
  _ serverName: UnsafeMutablePointer<CChar>
) -> UnsafeMutablePointer<CChar>? {
  return addServerBasedOnURLs(urls, skipCertVerification, serverName)
}
