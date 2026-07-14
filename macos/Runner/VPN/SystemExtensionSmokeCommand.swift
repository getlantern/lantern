import Foundation

internal enum SystemExtensionSmokeAction: String, Equatable {
  case status
  case activate
}

internal struct SystemExtensionSmokeParseError: Error, Equatable {
  let message: String
}

/// Command-line entry point for macOS smoke tests. It uses the same extension
/// manager as the UI, so macOS still owns the approval flow.
internal struct SystemExtensionSmokeCommand: Equatable {
  static let statusFlag = "--smoke-system-extension-status"
  static let activateFlag = "--smoke-activate-system-extension"
  static let timeoutFlag = "--timeout-seconds"
  static let defaultTimeout: TimeInterval = 120

  let action: SystemExtensionSmokeAction
  let timeout: TimeInterval

  static func parse(
    arguments: [String]
  ) -> Result<SystemExtensionSmokeCommand?, SystemExtensionSmokeParseError> {
    let hasStatusFlag = arguments.contains(statusFlag)
    let hasActivateFlag = arguments.contains(activateFlag)

    guard hasStatusFlag || hasActivateFlag else {
      return .success(nil)
    }

    guard !(hasStatusFlag && hasActivateFlag) else {
      return .failure(
        SystemExtensionSmokeParseError(
          message: "\(statusFlag) and \(activateFlag) cannot be used together")
      )
    }

    switch parseTimeout(arguments: arguments) {
    case .failure(let error):
      return .failure(error)
    case .success(let timeout):
      return .success(
        SystemExtensionSmokeCommand(
          action: hasActivateFlag ? .activate : .status,
          timeout: timeout
        )
      )
    }
  }

  static func writeStdout(_ line: String) {
    guard let data = "\(line)\n".data(using: .utf8) else {
      return
    }
    FileHandle.standardOutput.write(data)
  }

  static func errorJSON(_ message: String) -> String {
    jsonLine([
      "error": message,
      "exitCode": 64,
    ])
  }

  private static func parseTimeout(
    arguments: [String]
  ) -> Result<TimeInterval, SystemExtensionSmokeParseError> {
    var timeout = defaultTimeout
    var parsedTimeout = false

    let timeoutIndexes = arguments.indices.filter { arguments[$0] == timeoutFlag }
    guard timeoutIndexes.count <= 1 else {
      return .failure(
        SystemExtensionSmokeParseError(message: "\(timeoutFlag) can only be set once")
      )
    }

    if let timeoutIndex = timeoutIndexes.first {
      parsedTimeout = true
      let valueIndex = arguments.index(after: timeoutIndex)
      guard valueIndex < arguments.endIndex else {
        return .failure(
          SystemExtensionSmokeParseError(message: "\(timeoutFlag) needs a value")
        )
      }

      let rawValue = arguments[valueIndex]
      guard !rawValue.hasPrefix("--") else {
        return .failure(
          SystemExtensionSmokeParseError(message: "\(timeoutFlag) needs a value")
        )
      }

      guard let parsed = TimeInterval(rawValue), parsed > 0 else {
        return .failure(
          SystemExtensionSmokeParseError(message: "\(timeoutFlag) must be a positive number")
        )
      }
      timeout = parsed
    }

    for argument in arguments where argument.hasPrefix("\(timeoutFlag)=") {
      guard !parsedTimeout else {
        return .failure(
          SystemExtensionSmokeParseError(message: "\(timeoutFlag) can only be set once")
        )
      }

      let rawValue = String(argument.dropFirst(timeoutFlag.count + 1))
      guard let parsed = TimeInterval(rawValue), parsed > 0 else {
        return .failure(
          SystemExtensionSmokeParseError(message: "\(timeoutFlag) must be a positive number")
        )
      }
      timeout = parsed
      parsedTimeout = true
    }

    return .success(timeout)
  }

  fileprivate static func jsonLine(_ payload: [String: Any]) -> String {
    guard
      JSONSerialization.isValidJSONObject(payload),
      let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
      let json = String(data: data, encoding: .utf8)
    else {
      return #"{"error":"failed to encode smoke command response","exitCode":1}"#
    }
    return json
  }
}

internal struct SystemExtensionSmokeResult {
  let action: SystemExtensionSmokeAction
  let status: ExtensionStatus
  let timeout: TimeInterval

  var exitCode: Int32 {
    status.smokeExitCode(for: action)
  }

  var jsonLine: String {
    var payload: [String: Any] = [
      "action": action.rawValue,
      "exitCode": Int(exitCode),
      "status": status.code,
    ]
    if let details = status.details {
      payload["details"] = details
    }
    if status == .timedOut {
      payload["timeoutSeconds"] = timeout
    }
    return SystemExtensionSmokeCommand.jsonLine(payload)
  }
}

internal final class SystemExtensionSmokeCommandRunner {
  private let command: SystemExtensionSmokeCommand
  private let manager: SystemExtensionManager
  private let output: (String) -> Void
  private let complete: (Int32) -> Void
  private var finished = false

  init(
    command: SystemExtensionSmokeCommand,
    manager: SystemExtensionManager,
    output: @escaping (String) -> Void,
    complete: @escaping (Int32) -> Void
  ) {
    self.command = command
    self.manager = manager
    self.output = output
    self.complete = complete
  }

  func start() {
    appLogger.info(
      "Starting system extension smoke command: action=\(command.action.rawValue) timeout=\(command.timeout)"
    )

    DispatchQueue.main.asyncAfter(deadline: .now() + command.timeout) { [weak self] in
      self?.finish(.timedOut)
    }

    switch command.action {
    case .status:
      manager.checkInstallationStatus { [weak self] status in
        self?.handle(status)
      }
    case .activate:
      manager.activateExtension { [weak self] status in
        self?.handle(status)
      }
    }
  }

  private func handle(_ status: ExtensionStatus) {
    switch command.action {
    case .status:
      finish(status)
    case .activate:
      guard status.isSystemExtensionSmokeActivationTerminal else {
        return
      }
      finish(status)
    }
  }

  private func finish(_ status: ExtensionStatus) {
    guard !finished else {
      return
    }

    finished = true

    let result = SystemExtensionSmokeResult(
      action: command.action,
      status: status,
      timeout: command.timeout
    )
    appLogger.info(
      "System extension smoke command finished: action=\(command.action.rawValue) status=\(status.logDescription) exitCode=\(result.exitCode)"
    )
    output(result.jsonLine)
    complete(result.exitCode)
  }
}

private extension ExtensionStatus {
  var isSystemExtensionSmokeActivationTerminal: Bool {
    switch self {
    case .installed, .activated, .requiresApproval, .requiresReboot, .error, .timedOut:
      return true
    case .notInstalled, .uninstalling, .updatePending, .deactivated:
      return false
    }
  }

  func smokeExitCode(for action: SystemExtensionSmokeAction) -> Int32 {
    switch self {
    case .installed, .activated:
      return 0
    case .requiresApproval:
      return action == .activate ? 20 : 0
    case .requiresReboot:
      return action == .activate ? 21 : 0
    case .error:
      return 1
    case .timedOut:
      return 124
    case .notInstalled, .uninstalling, .updatePending, .deactivated:
      return action == .activate ? 10 : 0
    }
  }
}
