import AppKit
import Foundation

/// Caches the frontmost application so the event tap can read it cheaply.
///
/// `KeyboardShortcutController.handle(event:)` runs inside the CGEvent tap
/// callback, off the main actor. Asking `NSWorkspace` for the frontmost
/// application on every key down would perform main-thread-affine IPC inside a
/// tap macOS disables when it takes too long. Observing activation instead keeps
/// the hot path to a lock and two field reads.
final class FrontmostApplicationTracker: @unchecked Sendable {
  private let lock = NSLock()
  private var cachedBundleID: String?
  private var cachedProcessIdentifier: pid_t = -1
  private var observer: NSObjectProtocol?

  init(workspace: NSWorkspace = .shared) {
    let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    if let application = workspace.frontmostApplication {
      cachedBundleID = application.bundleIdentifier
      cachedProcessIdentifier = application.processIdentifier
    }

    observer = workspace.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: nil
    ) { [weak self] notification in
      guard
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication,
        application.processIdentifier != ownProcessIdentifier
      else { return }
      self?.update(
        bundleID: application.bundleIdentifier,
        processIdentifier: application.processIdentifier
      )
    }
  }

  deinit {
    if let observer {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
  }

  var bundleIdentifier: String? {
    lock.withLock { cachedBundleID }
  }

  var processIdentifier: pid_t {
    lock.withLock { cachedProcessIdentifier }
  }

  private func update(bundleID: String?, processIdentifier: pid_t) {
    lock.withLock {
      cachedBundleID = bundleID
      cachedProcessIdentifier = processIdentifier
    }
  }
}
