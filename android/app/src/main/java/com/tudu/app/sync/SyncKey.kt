package com.tudu.app.sync

import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder
import java.security.SecureRandom
import java.util.Base64

object SyncKey {
    private val pattern = Regex("^[A-Za-z0-9_-]{32,}$")

    /** 32 random bytes, base64url, no padding (43 characters). */
    fun generate(random: SecureRandom = SecureRandom()): String {
        val bytes = ByteArray(32).also(random::nextBytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    fun isValid(key: String): Boolean = pattern.matches(key)
}

/** The QR / deep-link payload: `tudu://sync?url=<urlencoded base URL>&key=<syncKey>`. */
data class SyncLink(val url: String, val key: String) {
    fun toUri(): String =
        "tudu://sync?url=${URLEncoder.encode(url, "UTF-8")}&key=${URLEncoder.encode(key, "UTF-8")}"

    companion object {
        fun parse(raw: String): SyncLink? {
            val uri = runCatching { URI(raw.trim()) }.getOrNull() ?: return null
            if (!uri.scheme.equals("tudu", ignoreCase = true) || !uri.host.equals("sync", ignoreCase = true)) return null
            val params = (uri.rawQuery ?: return null).split('&').mapNotNull { part ->
                val idx = part.indexOf('=')
                if (idx <= 0) null
                else part.substring(0, idx) to URLDecoder.decode(part.substring(idx + 1), "UTF-8")
            }.toMap()
            val url = params["url"]?.trim().orEmpty()
            val key = params["key"]?.trim().orEmpty()
            if (!(url.startsWith("https://") || url.startsWith("http://")) || !SyncKey.isValid(key)) return null
            return SyncLink(url = url, key = key)
        }
    }
}
