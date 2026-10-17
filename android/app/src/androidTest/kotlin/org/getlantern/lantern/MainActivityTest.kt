package org.getlantern.lantern

import android.Manifest
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.Process
import android.util.Log
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.ActivityTestRule
import dev.flutter.plugins.integration_test.FlutterTestRunner
import org.junit.Rule
import org.junit.runner.RunWith

/**
 * Entry point for running Flutter integration tests (integration_test/) as an
 * Android instrumentation test, locally via Gradle or on Firebase Test Lab:
 *
 *   ./gradlew app:assembleDebug -Ptarget=../integration_test/<file>_test.dart
 *   ./gradlew app:assembleDebugAndroidTest
 *
 * FlutterTestRunner is a custom JUnit Runner that does NOT process
 * @BeforeClass, so architecture checks and system-dialog pre-grants live in
 * the instance initializer, which runs when the runner instantiates this class
 * to read the @Rule field — before the activity is launched.
 */
@RunWith(FlutterTestRunner::class)
class MainActivityTest {

    init {
        verifyRuntimeArchitecture()
        grantVpnConsent()
        grantNotificationPermission()
    }

    @JvmField
    @Rule
    val rule = ActivityTestRule(MainActivity::class.java, true, false)

    companion object {
        // Check the selected process ABI before Flutter loads native libraries.
        private fun verifyRuntimeArchitecture() {
            val arguments = InstrumentationRegistry.getArguments()
            val is64Bit = Process.is64Bit()
            val supportedAbis = Build.SUPPORTED_ABIS.toList()
            // FlutterTestRunner hides constructor failures; log constraints too.
            Log.i(
                "LanternArchitecture",
                "model=${Build.MANUFACTURER}/${Build.MODEL} " +
                    "sdk=${Build.VERSION.SDK_INT} is64Bit=$is64Bit " +
                    "supportedAbis=$supportedAbis " +
                    "supported64BitAbis=${Build.SUPPORTED_64_BIT_ABIS.toList()} " +
                    "hardware=${Build.HARDWARE} fingerprint=${Build.FINGERPRINT} " +
                    "expectedAbi=${arguments.getString("lanternExpectedAbi")} " +
                    "expectedSdk=${arguments.getString("lanternExpectedSdk")} " +
                    "require32BitOnly=${arguments.getString("lanternRequire32BitOnly")}",
            )

            when (val expectedAbi = arguments.getString("lanternExpectedAbi")) {
                null -> Unit
                "armeabi-v7a" -> check(!is64Bit && expectedAbi in supportedAbis) {
                    "Expected an ARM32 process, got is64Bit=$is64Bit, ABIs=$supportedAbis"
                }
                "arm64-v8a" -> check(is64Bit && expectedAbi in supportedAbis) {
                    "Expected an ARM64 process, got is64Bit=$is64Bit, ABIs=$supportedAbis"
                }
                else -> error("Unsupported lanternExpectedAbi=$expectedAbi")
            }

            arguments.getString("lanternExpectedSdk")?.let { expectedSdk ->
                check(expectedSdk.toIntOrNull() == Build.VERSION.SDK_INT) {
                    "Expected Android API $expectedSdk, got ${Build.VERSION.SDK_INT}"
                }
            }
            when (arguments.getString("lanternRequire32BitOnly")) {
                null, "false" -> Unit
                "true" -> check(
                    !is64Bit && "armeabi-v7a" in supportedAbis &&
                        Build.SUPPORTED_64_BIT_ABIS.isEmpty(),
                ) {
                    "Expected a 32-bit-only Android OS, got ABIs=$supportedAbis"
                }
                else -> error("lanternRequire32BitOnly must be true or false")
            }
        }

        /**
         * Pre-authorizes the VPN (equivalent of the user accepting the
         * VpnService consent dialog) so VpnService.prepare() returns null and
         * the system dialog — unreachable from Flutter tests — never appears.
         * Instrumentation shell commands run with shell privileges, which is
         * enough for `appops set`; no adb or root required, so this also works
         * on Firebase Test Lab devices.
         */
        private fun grantVpnConsent() {
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
         * also unreachable from Flutter tests — never appears. It is only a
         * runtime permission on Android 13 (API 33)+; on older devices it is
         * granted at install time, so we skip. Wrapped defensively so an
         * already-granted / non-grantable device never fails the run.
         */
        private fun grantNotificationPermission() {
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
    }
}
