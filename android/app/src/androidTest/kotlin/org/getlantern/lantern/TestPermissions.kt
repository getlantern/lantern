package org.getlantern.lantern

import android.Manifest
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.test.platform.app.InstrumentationRegistry

/**
 * Pre-authorizes the VPN (equivalent of the user accepting the
 * VpnService consent dialog) so VpnService.prepare() returns null and
 * the system dialog — unreachable from tests — never appears.
 * Instrumentation shell commands run with shell privileges, which is
 * enough for `appops set`; no adb or root required, so this also works
 * on Firebase Test Lab devices.
 */
internal fun grantVpnConsent() {
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val packageName = instrumentation.targetContext.packageName
    val pfd = instrumentation.uiAutomation.executeShellCommand(
        "appops set $packageName ACTIVATE_VPN allow",
    )
    // Drain the output so the command completes before tests start.
    ParcelFileDescriptor.AutoCloseInputStream(pfd).use { it.readBytes() }
}

/**
 * Pre-grants POST_NOTIFICATIONS so the runtime notification prompt —
 * also unreachable from tests — never appears. It is only a
 * runtime permission on Android 13 (API 33)+; on older devices it is
 * granted at install time, so we skip. Wrapped defensively so an
 * already-granted / non-grantable device never fails the run.
 */
internal fun grantNotificationPermission() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
        return
    }
    val instrumentation = InstrumentationRegistry.getInstrumentation()
    val packageName = instrumentation.targetContext.packageName
    try {
        instrumentation.uiAutomation.grantRuntimePermission(
            packageName,
            Manifest.permission.POST_NOTIFICATIONS,
        )
    } catch (_: Exception) {
        // Best-effort: ignore if already granted or not grantable here.
    }
}
