package org.getlantern.lantern.utils

import java.io.File
import java.io.RandomAccessFile
import java.nio.charset.Charset
import java.util.ArrayDeque
class LogTailer(private val bufferSize: Int = 8192) {
    fun tail(file: File, maxLines: Int = 80, charset: Charset = Charsets.UTF_8): List<String> {
        if (!file.exists() || file.length() == 0L) return emptyList()

        val lines = ArrayDeque<String>(maxLines)
        RandomAccessFile(file, "r").use { raf ->
            var filePointer = raf.length()
            var carry = ""

            while (filePointer > 0 && lines.size < maxLines) {
                val bytesToRead = minOf(bufferSize.toLong(), filePointer).toInt()
                filePointer -= bytesToRead
                raf.seek(filePointer)

                val buffer = ByteArray(bytesToRead)
                raf.readFully(buffer)
                val chunk = String(buffer, charset)
                val combined = chunk + carry

                var end = combined.length
                for (i in combined.length - 1 downTo 0) {
                    if (combined[i] == '\n') {
                        if (lines.size == maxLines) break
                        val raw = combined.substring(i + 1, end)
                        val line = if (raw.endsWith('\r')) raw.dropLast(1) else raw
                        lines.addFirst(line)
                        end = i
                    }
                }
                carry = combined.take(end)
            }

            if (carry.isNotEmpty() && lines.size < maxLines) {
                carry.split('\n').reversed().forEach { part ->
                    if (lines.size == maxLines) return@forEach
                    lines.addFirst(part.trimEnd('\r'))
                }
            }
        }
        return lines.toList()
    }
}
