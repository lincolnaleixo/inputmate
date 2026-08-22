import AppKit
import InputMateCore
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
  @Binding var chord: ShortcutChord
  @Binding var displayShortcut: String

  func makeNSView(context: Context) -> RecorderButton {
    let button = RecorderButton()
    button.bezelStyle = .rounded
    button.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
    button.target = button
    button.action = #selector(RecorderButton.beginRecording)
    button.onRecord = record
    button.displayShortcut = displayShortcut
    button.setAccessibilityLabel("Record keyboard shortcut")
    button.setAccessibilityHelp("Click, then press the new shortcut")
    button.refreshTitle()
    return button
  }

  func updateNSView(_ button: RecorderButton, context: Context) {
    button.onRecord = record
    button.displayShortcut = displayShortcut
    button.refreshTitle()
  }

  private func record(_ newChord: ShortcutChord) {
    chord = newChord
    displayShortcut = ShortcutFormatter.string(for: newChord)
  }
}

final class RecorderButton: NSButton {
  var onRecord: ((ShortcutChord) -> Void)?
  var displayShortcut = "Not set"
  private var isRecording = false
  private var systemEventMonitor: Any?

  override var acceptsFirstResponder: Bool { true }

  @objc func beginRecording() {
    isRecording = true
    title = "Type shortcut…"
    window?.makeFirstResponder(self)
    installSystemEventMonitor()
  }

  override func keyDown(with event: NSEvent) {
    guard isRecording else {
      super.keyDown(with: event)
      return
    }

    if event.keyCode == 53 {
      finishRecording()
      return
    }

    let flags = event.cgEvent?.flags.rawValue ?? UInt64(event.modifierFlags.rawValue)
    let chord = ShortcutChord.capturing(keyCode: Int64(event.keyCode), flags: flags)
    onRecord?(chord)
    finishRecording()
  }

  override func resignFirstResponder() -> Bool {
    isRecording = false
    removeSystemEventMonitor()
    refreshTitle()
    return super.resignFirstResponder()
  }

  func refreshTitle() {
    guard !isRecording else { return }
    title = displayShortcut
  }

  private func finishRecording() {
    isRecording = false
    removeSystemEventMonitor()
    refreshTitle()
    window?.makeFirstResponder(nil)
  }

  private func installSystemEventMonitor() {
    removeSystemEventMonitor()
    systemEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) {
      [weak self] event in
      guard let self, self.isRecording,
        ShortcutChord.isSystemDefinedKeyDown(data1: Int64(event.data1)),
        let keyCode = ShortcutChord.mediaKeyCode(systemDefinedData1: Int64(event.data1))
      else { return event }

      let flags = event.cgEvent?.flags.rawValue ?? UInt64(event.modifierFlags.rawValue)
      self.onRecord?(ShortcutChord.capturing(keyCode: keyCode, flags: flags))
      self.finishRecording()
      return nil
    }
  }

  private func removeSystemEventMonitor() {
    if let systemEventMonitor {
      NSEvent.removeMonitor(systemEventMonitor)
      self.systemEventMonitor = nil
    }
  }
}
