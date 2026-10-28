package org.getlantern.lantern.service

internal class VpnAppCapture(include: List<String>, exclude: List<String>) {
    private val includeOnly = include.isNotEmpty()
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
        val seen = mutableSetOf(selfUid)
        var allowed = 0
        if (!includeOnly) {
            check(disallow(selfPackage)) { "Could not exclude Lantern from its VPN" }
        }
        for (pkg in packages) {
            val uid = uidOf(pkg) ?: continue
            if (uid in seen) continue
            if (if (includeOnly) allow(pkg) else disallow(pkg)) {
                seen.add(uid)
                allowed++
            }
        }
        if (includeOnly && allowed == 0) {
            // An empty Android allowlist captures every app; protected Lantern sockets keep this fallback direct.
            check(allow(selfPackage)) { "Could not establish an empty VPN app allowlist" }
        }
    }

    private companion object {
        // Radiance uses this non-package token to preserve empty-allowlist intent through TunOptions.
        const val EMPTY_INCLUDE = "@none"
    }
}
