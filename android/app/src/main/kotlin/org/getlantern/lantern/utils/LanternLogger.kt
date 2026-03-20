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

object AppLogger {

    private lateinit var logFile: File
    private var writer: FileWriter? = null

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val simpleDateFormat = java.text.SimpleDateFormat(
        "yyyy-MM-dd HH:mm:ss.SSS 'UTC'",
        Locale.US
    ).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    fun init() {
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
    private fun log(tag: String, msg: String) {
        d(tag, msg)
        writeAsync("DEBUG", tag, msg)
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

    private fun writeAsync(level: String, tag: String, msg: String) {
        scope.launch {
            try {
                writer?.apply {
                    append("time=\"${timestamp()}\" level=$level [$tag] $msg\n")
                    flush()
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
