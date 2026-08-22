import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import InputMateCore
import OSLog

final class TextTransformationController: @unchecked Sendable {
  @MainActor private var isRunning = false
  @MainActor private let modifierRelease = ModifierReleaseWaiter()
  private let logger = Logger(
    subsystem: "com.robot.InputMate",
    category: "TextTransformation"
  )

  func transform(presetID: String) {
    Task { @MainActor [weak self] in
      await self?.run(presetID: presetID)
    }
  }

  func modifierFlagsChanged(flags: UInt64) {
    Task { @MainActor [weak self] in
      self?.modifierRelease.modifierFlagsChanged(flags: flags)
    }
  }

  @MainActor
  private func run(presetID: String) async {
    guard !isRunning else {
      logger.warning(
        "Transformation ignored because another request is running: preset=\(presetID, privacy: .public)"
      )
      TransformationHUD.shared.showError("A transformation is already running")
      return
    }
    guard let preset = TextTransformationPreset.find(presetID) else {
      TransformationHUD.shared.showError("Unknown text transformation")
      return
    }
    guard let apiKey = KeychainSecretStore.cerebrasAPIKey(), !apiKey.isEmpty else {
      TransformationHUD.shared.showError("Add the Cerebras API key in InputMate Settings")
      return
    }
    guard let targetApplication = NSWorkspace.shared.frontmostApplication else {
      TransformationHUD.shared.showError("Could not identify the active application")
      return
    }

    isRunning = true
    defer { isRunning = false }
    logger.info("Transformation shortcut invoked: preset=\(presetID, privacy: .public)")
    TransformationHUD.shared.showProgress(preset.progressTitle)

    let overallStartedAt = CFAbsoluteTimeGetCurrent()
    var selectionMilliseconds = 0.0
    var requestMilliseconds = 0.0
    var replacementMilliseconds = 0.0
    var selectionRoute = "unavailable"

    do {
      let selectionStartedAt = CFAbsoluteTimeGetCurrent()
      let selection = try await captureSelection()
      selectionMilliseconds = milliseconds(since: selectionStartedAt)
      selectionRoute = selection.route

      let requestStartedAt = CFAbsoluteTimeGetCurrent()
      let responseText = try await requestTransformation(
        text: selection.text,
        preset: preset,
        apiKey: apiKey
      )
      let transformedText =
        preset.id == TextTransformationPreset.spanishID
        ? SpanishPunctuationPolicy.closingMarksOnly(in: responseText)
        : responseText
      requestMilliseconds = milliseconds(since: requestStartedAt)

      let replacementStartedAt = CFAbsoluteTimeGetCurrent()
      let replacementRoute = try await replaceSelection(
        transformedText,
        selection: selection,
        into: targetApplication
      )
      replacementMilliseconds = milliseconds(since: replacementStartedAt)
      selectionRoute = "\(selection.route)->\(replacementRoute)"

      TransformationHUD.shared.showCompletion(preset.completionTitle)
      logTiming(
        presetID: presetID,
        route: selectionRoute,
        selectionMilliseconds: selectionMilliseconds,
        requestMilliseconds: requestMilliseconds,
        replacementMilliseconds: replacementMilliseconds,
        totalMilliseconds: milliseconds(since: overallStartedAt),
        error: nil
      )
    } catch {
      logTiming(
        presetID: presetID,
        route: selectionRoute,
        selectionMilliseconds: selectionMilliseconds,
        requestMilliseconds: requestMilliseconds,
        replacementMilliseconds: replacementMilliseconds,
        totalMilliseconds: milliseconds(since: overallStartedAt),
        error: error
      )
      TransformationHUD.shared.showError(error.localizedDescription)
    }
  }

  @MainActor
  private func captureSelection() async throws -> SelectionTarget {
    if let selection = accessibilitySelection() {
      return selection
    }

    await modifierRelease.wait()
    return .clipboard(text: try await copySelectedText())
  }

  @MainActor
  private func accessibilitySelection() -> SelectionTarget? {
    let systemWideElement = AXUIElementCreateSystemWide()
    var focusedValue: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(
        systemWideElement,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
      ) == .success,
      let focusedValue,
      CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
    else { return nil }

    let focusedElement = focusedValue as! AXUIElement
    var selectedValue: CFTypeRef?
    var isSettable = DarwinBoolean(false)
    guard
      AXUIElementCopyAttributeValue(
        focusedElement,
        kAXSelectedTextAttribute as CFString,
        &selectedValue
      ) == .success,
      let selectedText = selectedValue as? String,
      !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      AXUIElementIsAttributeSettable(
        focusedElement,
        kAXSelectedTextAttribute as CFString,
        &isSettable
      ) == .success,
      isSettable.boolValue
    else { return nil }

    return .accessibility(element: focusedElement, text: selectedText)
  }

  @MainActor
  private func replaceSelection(
    _ text: String,
    selection: SelectionTarget,
    into application: NSRunningApplication
  ) async throws -> String {
    if case .accessibility(let element, let originalText) = selection,
      AXUIElementSetAttributeValue(
        element,
        kAXSelectedTextAttribute as CFString,
        text as CFString
      ) == .success,
      accessibilityWriteLanded(in: element, replacing: originalText)
    {
      return "accessibility"
    }

    await modifierRelease.wait()
    try await paste(text, into: application)
    return "clipboard"
  }

  @MainActor
  private func accessibilityWriteLanded(
    in element: AXUIElement,
    replacing originalText: String
  ) -> Bool {
    var currentValue: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(
        element,
        kAXSelectedTextAttribute as CFString,
        &currentValue
      ) == .success,
      let currentText = currentValue as? String
    else {
      return true
    }
    return currentText != originalText
  }

  @MainActor
  private func copySelectedText() async throws -> String {
    let pasteboard = NSPasteboard.general
    let originalClipboard = PasteboardSnapshot.capture(from: pasteboard)
    let originalChangeCount = pasteboard.changeCount

    postCommandKey(keyCode: 8)
    for _ in 0..<18 {
      if pasteboard.changeCount != originalChangeCount { break }
      try? await Task.sleep(for: .milliseconds(10))
    }

    let selectedText = pasteboard.string(forType: .string)
    let selectionWasCopied = pasteboard.changeCount != originalChangeCount
    originalClipboard.restore(to: pasteboard)

    guard
      selectionWasCopied,
      let selectedText,
      !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw TextTransformationError.noSelectedText
    }
    return selectedText
  }

  @MainActor
  private func paste(_ text: String, into application: NSRunningApplication) async throws {
    let pasteboard = NSPasteboard.general
    let clipboardBeforePaste = PasteboardSnapshot.capture(from: pasteboard)

    if !application.isActive {
      _ = application.activate(options: [.activateIgnoringOtherApps])
      try? await Task.sleep(for: .milliseconds(50))
    }

    pasteboard.clearContents()
    guard pasteboard.setString(text, forType: .string) else {
      throw TextTransformationError.couldNotUseClipboard
    }
    let transformationChangeCount = pasteboard.changeCount
    postCommandKey(keyCode: 9)
    try? await Task.sleep(for: .milliseconds(120))

    if pasteboard.changeCount == transformationChangeCount {
      clipboardBeforePaste.restore(to: pasteboard)
    }
  }

  @MainActor
  private func postCommandKey(keyCode: CGKeyCode) {
    guard
      let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    else { return }

    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.setIntegerValueField(
      .eventSourceUserData,
      value: KeyboardShortcutController.syntheticEventMarker
    )
    keyUp.setIntegerValueField(
      .eventSourceUserData,
      value: KeyboardShortcutController.syntheticEventMarker
    )
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
  }

  private func requestTransformation(
    text: String,
    preset: TextTransformationPreset,
    apiKey: String
  ) async throws -> String {
    guard let url = URL(string: "https://api.cerebras.ai/v1/chat/completions") else {
      throw TextTransformationError.invalidEndpoint
    }

    let body = CerebrasRequest(
      model: "gemma-4-31b",
      stream: false,
      maxTokens: 32_768,
      temperature: preset.temperature,
      topP: 0.95,
      messages: [
        CerebrasMessage(role: "system", content: preset.systemPrompt),
        CerebrasMessage(role: "user", content: preset.userPrompt(for: text)),
      ]
    )
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(body)
    request.timeoutInterval = 60

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
      (200..<300).contains(httpResponse.statusCode)
    else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      throw TextTransformationError.serviceError(status)
    }

    let result = try JSONDecoder().decode(CerebrasResponse.self, from: data)
    guard
      let content = result.choices.first?.message.content
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !content.isEmpty
    else {
      throw TextTransformationError.emptyResponse
    }
    return content
  }

  private func milliseconds(since startedAt: CFAbsoluteTime) -> Double {
    (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000
  }

  private func logTiming(
    presetID: String,
    route: String,
    selectionMilliseconds: Double,
    requestMilliseconds: Double,
    replacementMilliseconds: Double,
    totalMilliseconds: Double,
    error: Error?
  ) {
    let timing = String(
      format: "preset=%@ route=%@ selection=%.0fms request=%.0fms replacement=%.0fms total=%.0fms",
      presetID,
      route,
      selectionMilliseconds,
      requestMilliseconds,
      replacementMilliseconds,
      totalMilliseconds
    )
    if let error {
      logger.error(
        "Transformation failed: \(timing, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
      )
    } else {
      logger.info("Transformation completed: \(timing, privacy: .public)")
    }
  }
}

private enum SelectionTarget {
  case accessibility(element: AXUIElement, text: String)
  case clipboard(text: String)

  var text: String {
    switch self {
    case .accessibility(_, let text), .clipboard(let text):
      text
    }
  }

  var route: String {
    switch self {
    case .accessibility:
      "accessibility"
    case .clipboard:
      "clipboard"
    }
  }
}

private struct PasteboardSnapshot {
  let items: [[NSPasteboard.PasteboardType: Data]]

  static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
    let items = pasteboard.pasteboardItems?.map { item in
      Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
        item.data(forType: type).map { (type, $0) }
      })
    } ?? []
    return PasteboardSnapshot(items: items)
  }

  func restore(to pasteboard: NSPasteboard) {
    pasteboard.clearContents()
    let pasteboardItems = items.map { values in
      let item = NSPasteboardItem()
      for (type, data) in values {
        item.setData(data, forType: type)
      }
      return item
    }
    if !pasteboardItems.isEmpty {
      pasteboard.writeObjects(pasteboardItems)
    }
  }
}

private struct CerebrasRequest: Encodable {
  let model: String
  let stream: Bool
  let maxTokens: Int
  let temperature: Double
  let topP: Double
  let messages: [CerebrasMessage]

  enum CodingKeys: String, CodingKey {
    case model, stream, temperature, messages
    case maxTokens = "max_tokens"
    case topP = "top_p"
  }
}

private struct CerebrasMessage: Codable {
  let role: String
  let content: String
}

private struct CerebrasResponse: Decodable {
  let choices: [Choice]

  struct Choice: Decodable {
    let message: CerebrasMessage
  }
}

private enum TextTransformationError: LocalizedError {
  case noSelectedText
  case couldNotUseClipboard
  case invalidEndpoint
  case serviceError(Int)
  case emptyResponse

  var errorDescription: String? {
    switch self {
    case .noSelectedText:
      "Select some editable text first"
    case .couldNotUseClipboard:
      "Could not prepare the transformed text"
    case .invalidEndpoint:
      "The Cerebras endpoint is invalid"
    case .serviceError(let status):
      status == 0 ? "Could not reach Cerebras" : "Cerebras returned HTTP \(status)"
    case .emptyResponse:
      "Cerebras returned an empty response"
    }
  }
}
