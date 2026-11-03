import Foundation

// Helper outbound tags ("helper-" and 12 hex digits) are client-side
// pseudonyms for the user's helper pairings, and the spec forbids exporting
// them. This mirrors lantern-box's RedactHelperTags: a leading ASCII word
// boundary and no trailing one, so a suffix such as "_failed" does not shield
// a tag. radiance's group over them ("personal-proxies") and the app's
// personalProxy location type mark the device as having helpers, so they are
// redacted the same way, as the Dart port (lib/core/utils/helper_tags.dart)
// does.
//
// This redacts tags only: helper-…, personal-proxies, personal-proxy (and so a
// friend's selection, personal-proxy:helper-…) and personalProxy.
// Addresses on lines naming helpers are not touched here; the Dart and
// radiance redaction remove those.
private let helperTagPattern = try! NSRegularExpression(
  pattern: "(?<![A-Za-z0-9_])helper-[0-9a-f]{12}")
/// radiance's url-test group over every helper outbound.
let personalProxiesTag = "personal-proxies"
/// radiance's url-test group over one friend's outbounds. The app selects a
/// friend as "personal-proxy:<helper tag>".
let personalProxyTag = "personal-proxy"

/// Whether `tag` selects one friend ("personal-proxy:<helper tag>").
func isPersonalProxySelection(_ tag: String) -> Bool {
  tag.hasPrefix(personalProxyTag + ":")
}
private let personalProxyTypePattern = try! NSRegularExpression(
  pattern: "(?<![A-Za-z0-9_])personalProxy(?![A-Za-z0-9_])")

/// Replaces each helper tag, the personal proxy group tags and the
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
  if out.contains(personalProxyTag) {
    out = out.replacingOccurrences(of: personalProxyTag, with: "helper")
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
