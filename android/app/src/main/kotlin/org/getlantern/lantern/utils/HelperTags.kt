package org.getlantern.lantern.utils

/**
 * Helper outbound tags ("helper-" and 12 hex digits) are client-side
 * pseudonyms for the user's helper pairings, and the spec forbids exporting
 * them. This mirrors lantern-box's RedactHelperTags: a leading ASCII word
 * boundary and no trailing one, so a suffix such as "_failed" does not shield
 * a tag.
 */
object HelperTags {
    private val helperTag = Regex("(?<![A-Za-z0-9_])helper-[0-9a-f]{12}")

    /** Replaces each helper tag in [text] with "helper". */
    fun redact(text: String): String =
        if (!text.contains("helper-")) text else helperTag.replace(text, "helper")

    /**
     * What may be logged about a Flutter event. A server-location event carries
     * the auto-selected server, which may be a helper outbound whose tag,
     * address and city must never reach a log, so only its type is logged.
     */
    fun loggableEvent(type: String, message: String): String =
        if (type == "server-location") type else "$type - ${redact(message)}"
}
