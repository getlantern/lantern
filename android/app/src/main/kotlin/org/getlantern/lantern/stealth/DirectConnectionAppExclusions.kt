package org.getlantern.lantern.stealth

import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

data class DirectConnectionAppExclusion(
    val packageName: String,
    val displayName: String,
    val reasonFlags: Set<String>,
    val source: String,
    val confidence: String,
    val version: String,
)

object DirectConnectionAppExclusions {
    const val DEFAULT_ASSET_PATH = "flutter_assets/assets/stealth/default_exclusions.json"

    private const val SUPPORTED_SCHEMA_VERSION = 1

    private val packageNamePattern =
        Regex("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$")

    fun normalizePackageName(raw: String?): String {
        return raw.orEmpty().trim().lowercase(Locale.US)
    }

    fun isValidPackageName(packageName: String): Boolean {
        return packageNamePattern.matches(packageName)
    }

    fun parseDefaults(json: String): List<DirectConnectionAppExclusion> {
        val root = JSONObject(json)
        val schemaVersion = root.optInt("schema_version", -1)
        if (schemaVersion != SUPPORTED_SCHEMA_VERSION) {
            throw IllegalArgumentException(
                "Unsupported direct-connection defaults schema_version=$schemaVersion",
            )
        }

        val defaults = root.optJSONArray("defaults") ?: JSONArray()
        val out = ArrayList<DirectConnectionAppExclusion>(defaults.length())
        val seen = LinkedHashSet<String>()

        for (i in 0 until defaults.length()) {
            val item = defaults.optJSONObject(i) ?: continue
            val packageName = normalizePackageName(item.optString("package_name"))
            if (!isValidPackageName(packageName) || !seen.add(packageName)) {
                continue
            }

            out += DirectConnectionAppExclusion(
                packageName = packageName,
                displayName = item.optString("display_name").trim().ifEmpty { packageName },
                reasonFlags = item.optJSONArray("reason_flags").toStringSet(),
                source = item.optString("source").trim(),
                confidence = item.optString("confidence").trim(),
                version = item.optString("version").trim(),
            )
        }

        return out
    }

    fun effectivePackageNames(
        defaultPackages: Iterable<String>,
        userAddedPackages: Iterable<String>,
        userRemovedDefaultPackages: Iterable<String>,
    ): Set<String> {
        val effective = LinkedHashSet<String>()
        defaultPackages
            .map(::normalizePackageName)
            .filter(::isValidPackageName)
            .forEach { effective += it }

        userAddedPackages
            .map(::normalizePackageName)
            .filter(::isValidPackageName)
            .forEach { effective += it }

        userRemovedDefaultPackages
            .map(::normalizePackageName)
            .filter(::isValidPackageName)
            .forEach { effective -= it }

        return effective.toSortedSet()
    }
}

private fun JSONArray?.toStringSet(): Set<String> {
    if (this == null) return emptySet()
    val out = LinkedHashSet<String>()
    for (i in 0 until length()) {
        val value = optString(i).trim()
        if (value.isNotEmpty()) {
            out += value
        }
    }
    return out
}
