package org.getlantern.lantern.updater

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.getlantern.lantern.BuildConfig
import org.getlantern.lantern.MainActivity
import org.getlantern.lantern.service.LanternVpnService
import org.getlantern.lantern.utils.AppLogger
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale

data class AndroidSideloadUpdateRequest(
    val url: String,
    val checksum: String,
    val version: String,
)

object AndroidSideloadInstallStatus {
    const val InstallerStarted = "installer_started"
    const val PermissionRequired = "permission_required"
}

object AndroidSideloadInstaller {
    private const val TAG = "A/SideloadInstaller"
    private const val TARGET_PACKAGE_NAME = "org.getlantern.lantern"
    private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    private const val DOWNLOAD_TIMEOUT_MS = 30_000

    suspend fun install(
        activity: MainActivity,
        update: AndroidSideloadUpdateRequest,
    ): String {
        if (needsUnknownAppSourcePermission(activity)) {
            withContext(Dispatchers.Main.immediate) {
                openUnknownAppSourceSettings(activity)
            }
            return AndroidSideloadInstallStatus.PermissionRequired
        }

        val apkFile = withContext(Dispatchers.IO) {
            val file = downloadApk(activity, update.url)
            verifyDownloadedApk(activity, file, update)
            file
        }

        // Release the active TUN before Android replaces the package.
        runCatching {
            LanternVpnService.resetVpnForUpgrade(
                activity,
                "sideload installer handoff version=${update.version}",
            )
        }.onFailure { e ->
            AppLogger.e(TAG, "Failed to reset VPN before sideload installer handoff", e)
        }

        withContext(Dispatchers.Main.immediate) {
            launchPackageInstaller(activity, apkFile)
        }
        return AndroidSideloadInstallStatus.InstallerStarted
    }

    private fun needsUnknownAppSourcePermission(activity: MainActivity): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !activity.packageManager.canRequestPackageInstalls()
    }

    private fun openUnknownAppSourceSettings(activity: MainActivity) {
        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
            data = Uri.parse("package:${activity.packageName}")
        }
        activity.startActivity(intent)
    }

    private fun downloadApk(activity: MainActivity, rawUrl: String): File {
        try {
            val parsedUrl = URL(rawUrl)
            require(parsedUrl.protocol == "https") {
                "Android sideload update URL must use HTTPS"
            }

            val updatesDir = File(activity.cacheDir, "updates")
            check(updatesDir.exists() || updatesDir.mkdirs()) {
                "Unable to create update cache directory"
            }

            val partialFile = File(updatesDir, "Lantern.apk.part")
            val apkFile = File(updatesDir, "Lantern.apk")
            if (partialFile.exists()) partialFile.delete()

            AppLogger.d(TAG, "Downloading sideload APK from $rawUrl")
            val connection = (parsedUrl.openConnection() as HttpURLConnection).apply {
                connectTimeout = DOWNLOAD_TIMEOUT_MS
                readTimeout = DOWNLOAD_TIMEOUT_MS
                instanceFollowRedirects = true
                requestMethod = "GET"
            }

            try {
                val statusCode = connection.responseCode
                check(statusCode in 200..299) {
                    "APK download failed with HTTP $statusCode"
                }
                connection.inputStream.use { input ->
                    FileOutputStream(partialFile).use { output ->
                        input.copyTo(output)
                    }
                }
            } finally {
                connection.disconnect()
            }

            if (apkFile.exists()) apkFile.delete()
            check(partialFile.renameTo(apkFile)) {
                "Unable to finalize APK download"
            }

            return apkFile
        } catch (e: Exception) {
            val reason = e.localizedMessage ?: e.javaClass.simpleName
            throw IllegalStateException("APK download failed: $reason", e)
        }
    }

    private fun verifyDownloadedApk(
        activity: MainActivity,
        apkFile: File,
        update: AndroidSideloadUpdateRequest,
    ) {
        require(update.checksum.isNotBlank()) {
            "Update response missing APK SHA256 checksum"
        }

        val expectedChecksum = normalizeHex(update.checksum)
        val actualChecksum = sha256(apkFile)
        require(actualChecksum == expectedChecksum) {
            "APK checksum mismatch"
        }

        val archiveInfo = archivePackageInfo(
            activity.packageManager,
            apkFile,
            flags = 0,
        ) ?: throw IllegalStateException("Unable to read APK package metadata")

        require(archiveInfo.packageName == TARGET_PACKAGE_NAME) {
            "APK package name ${archiveInfo.packageName} does not match $TARGET_PACKAGE_NAME"
        }

        val currentInfo = packageInfo(activity.packageManager, TARGET_PACKAGE_NAME)
        val archiveVersionCode = longVersionCode(archiveInfo)
        val currentVersionCode = longVersionCode(currentInfo)
        require(archiveVersionCode > currentVersionCode) {
            "APK versionCode $archiveVersionCode is not newer than installed $currentVersionCode"
        }

        val expectedCert = normalizeHex(BuildConfig.SIDELOAD_SIGNING_CERTIFICATE_SHA256)
        require(expectedCert.isNotBlank()) {
            "Expected sideload signing certificate is not configured"
        }
        val certDigests = signingCertificateSha256s(activity.packageManager, apkFile)
        require(certDigests.contains(expectedCert)) {
            "APK signing certificate does not match expected sideload certificate"
        }
    }

    private fun launchPackageInstaller(activity: MainActivity, apkFile: File) {
        val uri = FileProvider.getUriForFile(
            activity,
            "${BuildConfig.APPLICATION_ID}.fileProvider",
            apkFile,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, APK_MIME_TYPE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
    }

    private fun signingCertificateSha256s(
        packageManager: PackageManager,
        apkFile: File,
    ): Set<String> {
        @Suppress("DEPRECATION")
        val signatureFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val info = archivePackageInfo(
            packageManager,
            apkFile,
            signatureFlags,
        ) ?: throw IllegalStateException("Unable to read APK signing metadata")

        val signatures: Array<Signature>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = info.signingInfo
                ?: throw IllegalStateException("No APK signing info found")
            signingInfo.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            info.signatures
        }

        require(signatures != null && signatures.size == 1) {
            "Expected exactly one APK signing certificate, found ${signatures?.size ?: 0}"
        }
        return signatures.map { signature: Signature ->
            sha256(signature.toByteArray())
        }.toSet()
    }

    @Suppress("DEPRECATION")
    private fun archivePackageInfo(
        packageManager: PackageManager,
        apkFile: File,
        flags: Int,
    ): PackageInfo? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageArchiveInfo(
                apkFile.absolutePath,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            packageManager.getPackageArchiveInfo(apkFile.absolutePath, flags)
        }
    }

    @Suppress("DEPRECATION")
    private fun packageInfo(packageManager: PackageManager, packageName: String): PackageInfo {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0L))
        } else {
            packageManager.getPackageInfo(packageName, 0)
        }
    }

    @Suppress("DEPRECATION")
    private fun longVersionCode(info: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().toHex()
    }

    private fun sha256(bytes: ByteArray): String {
        return MessageDigest.getInstance("SHA-256").digest(bytes).toHex()
    }

    private fun normalizeHex(value: String): String {
        return value.trim()
            .replace(":", "")
            .replace(" ", "")
            .lowercase(Locale.US)
    }

    private fun ByteArray.toHex(): String =
        joinToString(separator = "") { byte -> "%02x".format(byte) }
}
