package org.getlantern.lantern.apps

internal object AppFilters {
    // Alipay and WeChat are domestic and never need circumvention; the VPN
    // service keeps them off-tunnel, so the split-tunnel picker hides them.
    val TUNNEL_BYPASS: Set<String> = setOf(
        "com.eg.android.AlipayGphone",
        "com.tencent.mm",
    )

    val SYSTEM_EXCLUDE_EXACT: Set<String> = setOf(
        "com.android.systemui",
        "com.android.settings",
        "com.google.android.setupwizard",
        "com.android.packageinstaller",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.android.shell",
        "com.android.phone",
        "com.android.mms.service",
        "com.android.bluetooth",
        "com.android.nfc",
        "com.google.android.gms",
        "com.google.android.gsf",
        "com.google.android.cellbroadcastservice",
    )

    val SYSTEM_EXCLUDE_PREFIXES: Set<String> = setOf(
        "com.android.",
        "com.google.android.apps.work.",
        "com.google.android.projection.",
        "com.samsung.android.service.",
        "com.samsung.android.knox",
        "com.huawei.",
        "com.miui.",
    )

    val ALWAYS_INCLUDE: Set<String> = setOf(
        "com.android.chrome",
        "com.google.android.apps.messaging",
        "com.google.android.youtube",
        "com.sec.android.app.sbrowser",
        "com.samsung.android.messaging",
    )

    fun shouldSkip(pkg: String, ownPkg: String): Boolean {
        if (pkg == ownPkg) return true
        if (TUNNEL_BYPASS.contains(pkg)) return true
        if (ALWAYS_INCLUDE.contains(pkg)) return false
        if (SYSTEM_EXCLUDE_EXACT.contains(pkg)) return true
        if (SYSTEM_EXCLUDE_PREFIXES.any { pkg.startsWith(it) }) return !ALWAYS_INCLUDE.contains(pkg)
        return false
    }
}