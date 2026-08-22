import Foundation
import OSLog

final class CapsLockHyperMapper {
  private static let sourceCapsLockUsage: UInt64 = 0x7_0000_0039
  private static let destinationF18Usage: UInt64 = 0x7_0000_006D
  private static let refreshInterval: TimeInterval = 30

  private let logger = Logger(
    subsystem: "com.robot.InputMate",
    category: "CapsLockHyper"
  )
  private var lastCheckedAt: TimeInterval?
  private var lastResult = false

  func maintain(force: Bool = false) -> Bool {
    let now = Date().timeIntervalSince1970
    if !force,
      let lastCheckedAt,
      now - lastCheckedAt < Self.refreshInterval
    {
      return lastResult
    }

    lastCheckedAt = now
    let existingResult = runHIDUtil(arguments: ["property", "--get", "UserKeyMapping"])
    if mappingIsPresent(in: existingResult) {
      lastResult = true
      return true
    }

    let mapping =
      """
      {"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":\(Self.sourceCapsLockUsage),"HIDKeyboardModifierMappingDst":\(Self.destinationF18Usage)}]}
      """
    let setResult = runHIDUtil(arguments: ["property", "--set", mapping])
    guard setResult.status == 0 else {
      lastResult = false
      logger.error(
        "Could not map Caps Lock to InputMate Hyper: \(setResult.output, privacy: .public)"
      )
      return false
    }

    let readResult = runHIDUtil(arguments: ["property", "--get", "UserKeyMapping"])
    lastResult = mappingIsPresent(in: readResult)

    if lastResult {
      logger.info("Caps Lock is mapped to the InputMate Hyper key")
    } else {
      logger.error(
        "Caps Lock mapping could not be verified: \(readResult.output, privacy: .public)"
      )
    }
    return lastResult
  }

  private func mappingIsPresent(in result: (status: Int32, output: String)) -> Bool {
    result.status == 0
      && result.output.contains(String(Self.sourceCapsLockUsage))
      && result.output.contains(String(Self.destinationF18Usage))
  }

  private func runHIDUtil(arguments: [String]) -> (status: Int32, output: String) {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      return (
        process.terminationStatus,
        String(decoding: data, as: UTF8.self)
      )
    } catch {
      return (-1, error.localizedDescription)
    }
  }
}
