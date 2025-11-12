package org.getlantern.lantern.apps

internal object AppFilters {
    val SYSTEM_APPS_ALLOWLIST: Set<String> = setOf(
        "com.android.chrome",                       // Chrome
        "com.google.android.apps.messaging",        // Google Messages
        "com.google.android.youtube",               // YouTube
        "com.samsung.android.messaging",            // Samsung Messages
        "com.sec.android.app.sbrowser",             // Samsung Internet
        "com.android.browser"                       // AOSP Browser (some OEMs)
    )
}