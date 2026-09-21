package org.getlantern.lantern.utils

import android.content.Context
import android.util.Log

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.getlantern.lantern.LanternApp
import java.io.File
import java.io.FileWriter
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.zip.GZIPOutputStream

object AppLogger {

    private lateinit var logFile: File
    private var writer: FileWriter? = null

    // Single-threaded so appends stay ordered and rotation can swap the writer
    // without racing an in-flight write.
    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO.limitedParallelism(1))

    private val simpleDateFormat = java.text.SimpleDateFormat(
        "yyyy-MM-dd HH:mm:ss.SSS 'UTC'",
        Locale.US
    ).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    // Rotation mirrors FileLogPrinter in lib/core/services/logger_service.dart
    // and radiance's lumberjack config: bounded live file, a couple of gzipped
    // backups named `<name>-<stamp>.log.gz`. That name shape matters — the
    // issue-report archiver globs `*.log` and reads every match in full, so
    // uncompressed `.log` backups piling up is what broke report submission.
    private const val MAX_FILE_BYTES = 5L * 1024 * 1024
    private const val MAX_BACKUPS = 2
    private const val CHECK_INTERVAL_BYTES = 256L * 1024
    private const val BACKUP_EXT = ".log.gz"

    // Matches the Go/Dart backup stamp: 2026-08-25T19-30-00.000
    private val backupStampFormat = java.text.SimpleDateFormat(
        "yyyy-MM-dd'T'HH-mm-ss.SSS",
        Locale.US
    ).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    // Bytes appended since the last size check, so we don't stat on every line.
    private var sinceCheck = 0L

    fun init() {
        logFile = File(LanternApp.application.dataDir, ".lantern/logs/lantern_android.log")

        if (!logFile.exists()) {
            logFile.createNewFile()
        }
        deleteLegacyBackups()
        rotateIfNeeded()
        writer = FileWriter(logFile, true)
        d("Logger", "Logger initialized")
    }

    fun d(tag: String, message: String) {
        Log.d(tag, message)
        writeAsync("DEBUG", tag, message)
    }

    fun i(tag: String, message: String) {
        Log.i(tag, message)
        writeAsync("INFO", tag, message)
    }

    fun w(tag: String, message: String, throwable: Throwable? = null) {
        Log.w(tag, message, throwable)
        val errorMessage = buildString {
            append(message)
            if (throwable != null) {
                append("\n")
                append(throwable.stackTraceToString())
            }
        }
        writeAsync("WARN", tag, errorMessage)
    }

    fun e(tag: String, message: String, throwable: Throwable? = null) {
        Log.e(tag, message, throwable)
        val errorMessage = buildString {
            append(message)
            if (throwable != null) {
                append("\n")
                append(throwable.stackTraceToString())
            }
        }
        writeAsync("ERROR", tag, errorMessage)
    }
    /**
     * Must be called on the logger's IO scope (or before the writer is opened);
     * writes are serialized there so the writer swap is safe.
     */
    private fun rotateIfNeeded() {
        if (!logFile.exists() || logFile.length() < MAX_FILE_BYTES) return
        val previous = writer
        writer = null
        try {
            previous?.close()
            try {
                compressToBackup()
            } finally {
                // Truncate even if compressing failed (e.g. disk full), so the
                // live file stays bounded instead of growing unchecked.
                writer = FileWriter(logFile, false)
            }
            pruneBackups()
        } catch (e: Exception) {
            Log.e("AppLogger", "Log rotation failure", e)
            if (writer == null) {
                try {
                    writer = FileWriter(logFile, true)
                } catch (reopen: Exception) {
                    Log.e("AppLogger", "Could not reopen log writer", reopen)
                }
            }
        }
    }

    private fun logName(): String = logFile.nameWithoutExtension

    /**
     * Older builds rotated by renaming to `lantern_android_<epoch-ms>.log` and
     * never pruned. Those files are exactly what blew the report archive, so
     * remove them once on upgrade.
     */
    private fun deleteLegacyBackups() {
        val prefix = "${logName()}_"
        logFile.parentFile
            ?.listFiles { f -> f.isFile && f.name.startsWith(prefix) && f.name.endsWith(".log") }
            ?.forEach { it.delete() }
    }

    /** Streams the live file into `<name>-<stamp>.log.gz`; no partial backup is left on failure. */
    private fun compressToBackup() {
        val backup = File(
            logFile.parentFile,
            "${logName()}-${backupStampFormat.format(Date())}$BACKUP_EXT"
        )
        try {
            logFile.inputStream().use { input ->
                GZIPOutputStream(backup.outputStream().buffered()).use { gz ->
                    input.copyTo(gz)
                }
            }
        } catch (e: Exception) {
            backup.delete()
            throw e
        }
    }

    private fun pruneBackups() {
        val prefix = "${logName()}-"
        val backups = logFile.parentFile
            ?.listFiles { f -> f.isFile && f.name.startsWith(prefix) && f.name.endsWith(BACKUP_EXT) }
            ?.sortedBy { it.name } // stamps are fixed-width, so lexical == chronological
            ?: return
        backups.take((backups.size - MAX_BACKUPS).coerceAtLeast(0)).forEach { stale ->
            if (!stale.delete()) Log.w("AppLogger", "Could not delete stale backup ${stale.name}")
        }
    }

    fun close() {
        try {
            writer?.close()
            scope.cancel()
        } catch (_: Exception) {
        }
    }

    private fun writeAsync(level: String, tag: String, msg: String) {
        scope.launch {
            try {
                val line = "time=\"${timestamp()}\" level=$level [$tag] $msg\n"
                writer?.apply {
                    append(line)
                    flush()
                }
                // UTF-16 length, not bytes: undercounts multi-byte text, which
                // only delays the check slightly. The decision itself uses the
                // real file length.
                sinceCheck += line.length
                if (sinceCheck >= CHECK_INTERVAL_BYTES) {
                    sinceCheck = 0
                    rotateIfNeeded()
                }
            } catch (e: Exception) {
                Log.e("AppLogger", "Log write failure", e)
            }
        }
    }

    private fun timestamp(): String {
        return simpleDateFormat.format(Date())
    }

}
