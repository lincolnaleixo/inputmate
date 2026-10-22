import Combine
import Sparkle
import SwiftUI

// InputMate is a menu bar app that never quits, so Sparkle's "install on quit"
// would leave a downloaded update staged forever. Install it as soon as it is ready.
final class InstallReadyUpdateDelegate: NSObject, SPUUpdaterDelegate {
  func updater(
    _ updater: SPUUpdater,
    willInstallUpdateOnQuit item: SUAppcastItem,
    immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
  ) -> Bool {
    immediateInstallHandler()
    return true
  }
}

@MainActor
final class UpdateController {
  let updaterController: SPUStandardUpdaterController
  private let updaterDelegate = InstallReadyUpdateDelegate()

  init() {
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: updaterDelegate,
      userDriverDelegate: nil
    )
  }

  var updater: SPUUpdater {
    updaterController.updater
  }
}

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
  @Published private(set) var canCheckForUpdates = false

  init(updater: SPUUpdater) {
    updater.publisher(for: \.canCheckForUpdates)
      .assign(to: &$canCheckForUpdates)
  }
}

@MainActor
struct CheckForUpdatesView: View {
  @ObservedObject private var viewModel: CheckForUpdatesViewModel
  private let updater: SPUUpdater

  init(updater: SPUUpdater) {
    self.updater = updater
    viewModel = CheckForUpdatesViewModel(updater: updater)
  }

  var body: some View {
    Button("Check for Updates…", action: updater.checkForUpdates)
      .disabled(!viewModel.canCheckForUpdates)
  }
}
