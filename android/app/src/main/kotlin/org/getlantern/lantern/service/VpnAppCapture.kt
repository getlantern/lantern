package org.getlantern.lantern.service

internal class VpnAppCapture(include: List<String>, exclude: List<String>) {
    val includeOnly = include.isNotEmpty()
    private val packages = (if (includeOnly) include else exclude)
        .filter { it.isNotBlank() && it != EMPTY_INCLUDE }
        .distinct()

    init {
        require(include.isEmpty() || exclude.isEmpty()) { "VPN capture cannot allow and disallow apps together" }
    }

    fun contains(packageName: String): Boolean = packageName in packages

    fun apply(
        selfPackage: String,
        selfUid: Int,
        uidOf: (String) -> Int?,
        allow: (String) -> Boolean,
        disallow: (String) -> Boolean,
    ) {
        val add = if (includeOnly) allow else disallow
        val seen = mutableSetOf(selfUid)
        var added = false
        if (!includeOnly) {
            check(disallow(selfPackage)) { "Could not exclude Lantern from its VPN" }
        }
        for (pkg in packages) {
            val uid = uidOf(pkg) ?: continue
            if (uid !in seen && add(pkg)) {
                seen.add(uid)
                added = true
            }
        }
        if (includeOnly && !added) {
            // An empty allowlist would capture every app, so allow only Lantern,
            // whose own sockets are protected and bypass the tunnel anyway.
            check(allow(selfPackage)) { "Could not establish an empty VPN app allowlist" }
        }
    }

    private companion object {
        // Radiance's placeholder for an empty include list.
        const val EMPTY_INCLUDE = "@none"
    }
}
