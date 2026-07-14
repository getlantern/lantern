import Foundation
import XCTest

final class LanternSmokeUITests: XCTestCase {
  private let stateIdentifiers = [
    "vpn.status.disconnected",
    "vpn.status.connecting",
    "vpn.status.connected",
    "vpn.status.disconnecting",
    "vpn.status.missingPermission",
    "vpn.status.error",
  ]

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testConnectTrafficAndDisconnect() throws {
    let environment = ProcessInfo.processInfo.environment
    let appPath = environment["LANTERN_APP_PATH"] ?? "/Applications/Lantern.app"
    guard FileManager.default.fileExists(atPath: appPath) else {
      throw SmokeError.missingApp(appPath)
    }

    let app = XCUIApplication(url: URL(fileURLWithPath: appPath))
    app.launchArguments = ["--smoke-ui-test", "-ApplePersistenceIgnoreState", "YES"]
    app.launchEnvironment["LANTERN_SMOKE_UI_TEST"] = "true"
    app.launch()
    app.activate()
    defer { cleanUp(app) }

    XCTAssertTrue(
      app.windows.firstMatch.waitForExistence(timeout: 30),
      "Lantern did not present its main window"
    )

    let checkIP = ProcessInfo.processInfo.environment["ENABLE_IP_CHECK"] == "true"
    let baselineIP = checkIP ? try fetchPublicIPWithRetry(timeout: 30) : nil

    try finishOnboardingIfNeeded(app)
    guard let initialState = waitForAnyIdentifier(stateIdentifiers, in: app, timeout: 90) else {
      XCTFail("Lantern did not expose a VPN state")
      return
    }

    if initialState == "vpn.status.connected" {
      try clickToggle(in: app)
      XCTAssertTrue(
        waitForIdentifier("vpn.status.disconnected", in: app, timeout: 45),
        "VPN did not start the smoke test disconnected"
      )
    } else if initialState == "vpn.status.missingPermission" {
      XCTFail("The runner is missing its saved VPN configuration permission")
    }

    try clickToggle(in: app)
    XCTAssertTrue(
      waitForIdentifier("vpn.status.connected", in: app, timeout: 60),
      "VPN did not reach connected state"
    )

    if let baselineIP {
      try waitForPublicIPChange(from: baselineIP, timeout: 45)
    } else {
      _ = try fetchPublicIPWithRetry(timeout: 45)
    }

    try clickToggle(in: app)
    XCTAssertTrue(
      waitForIdentifier("vpn.status.disconnected", in: app, timeout: 45),
      "VPN did not return to disconnected state"
    )
  }

  private func cleanUp(_ app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Lantern final state"
    attachment.lifetime = .keepAlways
    add(attachment)

    if element("vpn.status.connected", in: app).exists,
      element("vpn.toggle", in: app).exists
    {
      element("vpn.toggle", in: app).click()
      _ = waitForIdentifier("vpn.status.disconnected", in: app, timeout: 30)
    }
    app.terminate()
  }

  private func finishOnboardingIfNeeded(_ app: XCUIApplication) throws {
    if waitForAnyIdentifier(stateIdentifiers, in: app, timeout: 5) != nil {
      return
    }

    for _ in 0..<4 {
      let skip = element("onboarding.skip", in: app)
      let primary = element("onboarding.primary", in: app)
      if skip.exists {
        skip.click()
      } else if primary.exists {
        primary.click()
      } else if waitForAnyIdentifier(stateIdentifiers, in: app, timeout: 5) != nil {
        return
      } else {
        throw SmokeError.missingControls
      }

      if waitForAnyIdentifier(stateIdentifiers, in: app, timeout: 10) != nil {
        return
      }
    }

    throw SmokeError.onboardingDidNotFinish
  }

  private func clickToggle(in app: XCUIApplication) throws {
    let toggle = element("vpn.toggle", in: app)
    guard toggle.waitForExistence(timeout: 20) else {
      throw SmokeError.missingToggle
    }
    toggle.click()
  }

  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    let predicate = NSPredicate(
      format: "identifier == %@ OR label == %@ OR label BEGINSWITH %@",
      identifier,
      identifier,
      identifier
    )
    return app.descendants(matching: .any).matching(predicate).firstMatch
  }

  private func waitForIdentifier(
    _ identifier: String,
    in app: XCUIApplication,
    timeout: TimeInterval
  ) -> Bool {
    element(identifier, in: app).waitForExistence(timeout: timeout)
  }

  private func waitForAnyIdentifier(
    _ identifiers: [String],
    in app: XCUIApplication,
    timeout: TimeInterval
  ) -> String? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if let identifier = identifiers.first(where: { element($0, in: app).exists }) {
        return identifier
      }
      Thread.sleep(forTimeInterval: 0.25)
    } while Date() < deadline
    return nil
  }

  private func fetchPublicIPWithRetry(timeout: TimeInterval) throws -> String {
    let deadline = Date().addingTimeInterval(timeout)
    var lastError: Error = SmokeError.trafficUnavailable

    repeat {
      do {
        return try fetchPublicIP()
      } catch {
        lastError = error
        Thread.sleep(forTimeInterval: 2)
      }
    } while Date() < deadline

    throw lastError
  }

  private func waitForPublicIPChange(from baselineIP: String, timeout: TimeInterval) throws {
    let deadline = Date().addingTimeInterval(timeout)

    repeat {
      if try fetchPublicIP() != baselineIP {
        return
      }
      Thread.sleep(forTimeInterval: 2)
    } while Date() < deadline

    XCTFail("Public IP did not change after VPN connected")
  }

  private func fetchPublicIP() throws -> String {
    let requestFinished = expectation(description: "public IP request")
    let url = URL(string: "https://api64.ipify.org")!
    var result: Result<String, Error>?

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
      defer { requestFinished.fulfill() }

      if let error {
        result = .failure(error)
        return
      }
      guard let response = response as? HTTPURLResponse,
        response.statusCode == 200,
        let data,
        let value = String(data: data, encoding: .utf8)?.trimmingCharacters(
          in: .whitespacesAndNewlines
        ),
        !value.isEmpty
      else {
        result = .failure(SmokeError.invalidTrafficResponse)
        return
      }
      result = .success(value)
    }
    task.resume()
    wait(for: [requestFinished], timeout: 10)
    task.cancel()

    guard let result else {
      throw SmokeError.trafficUnavailable
    }
    return try result.get()
  }
}

private enum SmokeError: LocalizedError {
  case invalidTrafficResponse
  case missingApp(String)
  case missingControls
  case missingToggle
  case onboardingDidNotFinish
  case trafficUnavailable

  var errorDescription: String? {
    switch self {
    case .invalidTrafficResponse:
      return "The traffic check returned an invalid response"
    case .missingApp(let path):
      return "Lantern.app was not found at \(path)"
    case .missingControls:
      return "Neither Lantern's VPN state nor onboarding controls were visible"
    case .missingToggle:
      return "The VPN toggle was not visible"
    case .onboardingDidNotFinish:
      return "Lantern onboarding did not reach the home screen"
    case .trafficUnavailable:
      return "Traffic was unavailable while the VPN was connected"
    }
  }
}
