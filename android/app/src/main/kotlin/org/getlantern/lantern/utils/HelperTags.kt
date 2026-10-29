package org.getlantern.lantern.utils

/**
 * Helper outbound tags ("helper-" and 12 hex digits) are client-side
 * pseudonyms for the user's helper pairings, and the spec forbids exporting
 * them. This mirrors lantern-box's RedactHelperTags: a leading ASCII word
 * boundary and no trailing one, so a suffix such as "_failed" does not shield
 * a tag. radiance's group over them ("personal-proxies") and the app's
 * personalProxy location type mark the device as having helpers, so they are
 * redacted the same way, as the Dart port (lib/core/utils/helper_tags.dart)
 * does.
 *
 * This redacts tags only: helper-…, personal-proxies and personalProxy.
 * Addresses on lines naming helpers are not touched here; the Dart and
 * radiance redaction remove those.
 */
object HelperTags {
    private val helperTag = Regex("(?<![A-Za-z0-9_])helper-[0-9a-f]{12}")
    private const val PERSONAL_PROXIES_TAG = "personal-proxies"
    private val personalProxyType = Regex("(?<![A-Za-z0-9_])personalProxy(?![A-Za-z0-9_])")

    /**
     * Replaces each helper tag, the personal proxies group tag and the
     * personalProxy type in [text] with "helper".
     */
    fun redact(text: String): String {
        var out = text
        if (out.contains("helper-")) out = helperTag.replace(out, "helper")
        if (out.contains(PERSONAL_PROXIES_TAG)) out = out.replace(PERSONAL_PROXIES_TAG, "helper")
        if (out.contains("personalProxy")) out = personalProxyType.replace(out, "helper")
        return out
    }

    /**
     * What may be logged about a Flutter event. A server-location event carries
     * the auto-selected server, which may be a helper outbound whose tag,
     * address and city must never reach a log, so only its type is logged.
     */
    fun loggableEvent(type: String, message: String): String =
        if (type == "server-location") type else "$type - ${redact(message)}"
}
