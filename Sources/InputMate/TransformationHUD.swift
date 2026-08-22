import AppKit

@MainActor
final class TransformationHUD {
  static let shared = TransformationHUD()

  private let panel: NSPanel
  private let iconView = NSImageView()
  private let progressIndicator = NSProgressIndicator()
  private let titleLabel = NSTextField(labelWithString: "")
  private let detailLabel = NSTextField(labelWithString: "")
  private var hideWorkItem: DispatchWorkItem?

  private init() {
    panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 368, height: 72),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .floating
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.ignoresMouseEvents = true
    panel.animationBehavior = .none

    let background = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
    background.autoresizingMask = [.width, .height]
    background.material = .popover
    background.blendingMode = .behindWindow
    background.state = .active
    background.wantsLayer = true
    background.layer?.cornerRadius = 16
    background.layer?.cornerCurve = .continuous
    background.layer?.borderWidth = 0.5
    background.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
    background.setAccessibilityRole(.group)
    background.setAccessibilityLabel("Text transformation status")

    progressIndicator.style = .spinning
    progressIndicator.controlSize = .small
    progressIndicator.frame = NSRect(x: 20, y: 24, width: 24, height: 24)

    iconView.frame = progressIndicator.frame
    iconView.imageScaling = .scaleProportionallyDown
    iconView.contentTintColor = .secondaryLabelColor

    titleLabel.frame = NSRect(x: 58, y: 35, width: 286, height: 19)
    titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    titleLabel.textColor = .labelColor
    titleLabel.lineBreakMode = .byTruncatingTail

    detailLabel.frame = NSRect(x: 58, y: 16, width: 286, height: 17)
    detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
    detailLabel.textColor = .secondaryLabelColor
    detailLabel.lineBreakMode = .byTruncatingTail

    background.addSubview(progressIndicator)
    background.addSubview(iconView)
    background.addSubview(titleLabel)
    background.addSubview(detailLabel)
    panel.contentView = background
  }

  func showProgress(_ text: String) {
    hideWorkItem?.cancel()
    titleLabel.stringValue = text
    detailLabel.stringValue = "Cerebras · gemma-4-31b"
    progressIndicator.isHidden = false
    progressIndicator.startAnimation(nil)
    iconView.isHidden = true
    positionAndShow()
  }

  func showCompletion(_ text: String) {
    titleLabel.stringValue = "Done"
    detailLabel.stringValue = text
    progressIndicator.stopAnimation(nil)
    progressIndicator.isHidden = true
    showIcon("checkmark.circle.fill", color: .systemGreen)
    positionAndShow()
    scheduleHide(after: 1.5)
  }

  func showError(_ text: String) {
    titleLabel.stringValue = "Couldn’t transform text"
    detailLabel.stringValue = text
    progressIndicator.stopAnimation(nil)
    progressIndicator.isHidden = true
    showIcon("exclamationmark.triangle.fill", color: .systemOrange)
    positionAndShow()
    scheduleHide(after: 3.2)
  }

  private func showIcon(_ symbolName: String, color: NSColor) {
    let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
    iconView.image = NSImage(
      systemSymbolName: symbolName,
      accessibilityDescription: titleLabel.stringValue
    )?.withSymbolConfiguration(configuration)
    iconView.contentTintColor = color
    iconView.isHidden = false
  }

  private func positionAndShow() {
    let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    if let screenFrame = screen?.visibleFrame {
      let origin = NSPoint(
        x: screenFrame.midX - panel.frame.width / 2,
        y: screenFrame.maxY - panel.frame.height - 24
      )
      panel.setFrameOrigin(origin)
    }

    guard !panel.isVisible else {
      panel.alphaValue = 1
      return
    }

    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.16
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 1
    }
  }

  private func scheduleHide(after delay: TimeInterval) {
    hideWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      self?.hide()
    }
    hideWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  private func hide() {
    guard panel.isVisible else { return }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.14
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      panel.animator().alphaValue = 0
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
      self?.panel.orderOut(nil)
      self?.panel.alphaValue = 1
    }
  }
}
