import Foundation

public enum SpanishPunctuationPolicy {
  public static func closingMarksOnly(in text: String) -> String {
    text
      .replacingOccurrences(of: "¿", with: "")
      .replacingOccurrences(of: "¡", with: "")
  }
}
