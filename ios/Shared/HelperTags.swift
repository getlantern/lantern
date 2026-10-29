import Foundation

// Helper outbound tags ("helper-" and 12 hex digits) are client-side
// pseudonyms for the user's helper pairings, and the spec forbids exporting
// them. This mirrors lantern-box's RedactHelperTags: a leading ASCII word
// boundary and no trailing one, so a suffix such as "_failed" does not shield
// a tag. radiance's group over them ("personal-proxies") and the app's
// personalProxy location type mark the device as having helpers, so they are
// redacted the same way, as the Dart port (lib/core/utils/helper_tags.dart)
// does.
private let helperTagPattern = try! NSRegularExpression(
  pattern: "(?<![A-Za-z0-9_])helper-[0-9a-f]{12}")
private let personalProxiesTag = "personal-proxies"
private let personalProxyTypePattern = try! NSRegularExpression(
  pattern: "(?<![A-Za-z0-9_])personalProxy(?![A-Za-z0-9_])")

/// Replaces each helper tag, the personal proxies group tag and the
/// personalProxy type in `text` with "helper".
func redactHelperTags(_ text: String) -> String {
  var out = text
  if out.contains("helper-") {
    out = helperTagPattern.stringByReplacingMatches(
      in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "helper")
  }
  if out.contains(personalProxiesTag) {
    out = out.replacingOccurrences(of: personalProxiesTag, with: "helper")
  }
  if out.contains("personalProxy") {
    out = personalProxyTypePattern.stringByReplacingMatches(
      in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "helper")
  }
  return out
}

/// What may be logged about a Flutter event. A server-location event carries
/// the auto-selected server, which may be a helper outbound whose tag,
/// address and city must never reach a log, so only its type is logged.
func loggableFlutterEvent(type: String, message: String) -> String {
  if type == "server-location" { return type }
  return "\(type) - \(redactHelperTags(message))"
}
