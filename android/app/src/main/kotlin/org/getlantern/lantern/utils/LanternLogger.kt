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

object AppLogger {

    private lateinit var logFile: File
    private var writer: FileWriter? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun init(context: Context) {
        logFile = File(LanternApp.application.dataDir, ".lantern/logs/lantern_android.log")
        if (!logFile.exists()) {
            logFile.createNewFile()
        }
        // Rotate only once when initializing
        rotateIfNeeded()
        writer = FileWriter(logFile, true)
        log("Logger", "Logger initialized")
    }

    fun d(tag: String, message: String) {
        Log.d(tag, message)
        writeAsync("DEBUG", tag, message)
    }

    fun i(tag: String, message: String) {
        Log.i(tag, message)
        writeAsync("INFO", tag, message)
    }
    fun w(tag: String, message: String,tr: Throwable? = null) {
        Log.w(tag, message,tr)
        writeAsync("INFO", tag, message)
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

    private fun writeAsync(level: String, tag: String, msg: String) {
        scope.launch {
            try {
                rotateIfNeeded()

                writer?.apply {
                    append("${timestamp()} [$level][$tag] $msg\n")
                    flush()
                }

            } catch (e: Exception) {
                AppLogger.e("MyLogger", "Log write failure", e)
            }
        }
    }

    private fun rotateIfNeeded() {
        // Only rotate if an old file exists and > 5MB
        if (logFile.exists() && logFile.length() > 5 * 1024 * 1024) {
            val rotatedFile = File(
                logFile.parent,
                "lantern_android_${System.currentTimeMillis()}.log"
            )
            logFile.renameTo(rotatedFile)
        }
    }

    fun close() {
        try {
            writer?.close()
            scope.cancel()
        } catch (_: Exception) {
        }
    }

    private fun timestamp(): String {
        val now = System.currentTimeMillis()
        return java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS")
            .format(java.util.Date(now))
    }

    private fun log(tag: String, msg: String) {
        AppLogger.d(tag, msg)
        writeAsync("DEBUG", tag, msg)
    }
}
