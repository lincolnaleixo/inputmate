import CoreGraphics
import Foundation
import InputMateCore

/// Waits until the hyper modifiers are physically released.
@MainActor
final class ModifierReleaseWaiter {
  private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

  private static let timeout = Duration.milliseconds(250)

  func modifierFlagsChanged(flags: UInt64) {
    guard flags & ShortcutChord.leftHyperModifiers == 0 else { return }
    resumeAll()
  }

  func wait() async {
    let currentFlags = CGEventSource.flagsState(.combinedSessionState).rawValue
    guard currentFlags & ShortcutChord.leftHyperModifiers != 0 else { return }

    let waiterID = UUID()
    await withCheckedContinuation { continuation in
      waiters[waiterID] = continuation

      let refreshedFlags = CGEventSource.flagsState(.combinedSessionState).rawValue
      if refreshedFlags & ShortcutChord.leftHyperModifiers == 0 {
        resume(id: waiterID)
        return
      }

      Task { @MainActor [weak self] in
        try? await Task.sleep(for: Self.timeout)
        self?.resume(id: waiterID)
      }
    }
  }

  private func resume(id: UUID) {
    waiters.removeValue(forKey: id)?.resume()
  }

  private func resumeAll() {
    let continuations = Array(waiters.values)
    waiters.removeAll()
    for continuation in continuations {
      continuation.resume()
    }
  }
}
