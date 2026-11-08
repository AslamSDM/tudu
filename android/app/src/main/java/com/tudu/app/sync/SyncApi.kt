package com.tudu.app.sync

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class SyncHttpException(val code: Int, message: String) : java.lang.Exception(message) {
    /** 4xx errors other than 408/429 will not succeed on retry. */
    val retryable: Boolean get() = code >= 500 || code == 408 || code == 429
}

/** HTTP client for the Tudu Worker. */
class SyncApi(
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build(),
) : SyncTransport {

    override suspend fun sync(baseUrl: String, syncKey: String, request: SyncRequest): SyncResponse =
        withContext(Dispatchers.IO) {
            val body = WireJson.encodeToString(SyncRequest.serializer(), request)
                .toRequestBody(JSON)
            val httpRequest = Request.Builder()
                .url(normalizeBaseUrl(baseUrl) + "/v1/sync")
                .header("Authorization", "Bearer $syncKey")
                .post(body)
                .build()
            client.newCall(httpRequest).execute().use { response ->
                val text = response.body.string()
                if (!response.isSuccessful) throw SyncHttpException(response.code, errorMessage(response.code, text))
                WireJson.decodeFromString(SyncResponse.serializer(), text)
            }
        }

    /** `GET /v1/health`. Returns true when the server answers `{ "ok": true }`. */
    suspend fun health(baseUrl: String): Boolean = withContext(Dispatchers.IO) {
        val request = Request.Builder().url(normalizeBaseUrl(baseUrl) + "/v1/health").get().build()
        runCatching {
            client.newCall(request).execute().use { it.isSuccessful && it.body.string().contains("true") }
        }.getOrDefault(false)
    }

    private fun errorMessage(code: Int, body: String): String {
        val serverMessage = runCatching { WireJson.decodeFromString(ErrorResponse.serializer(), body).error }.getOrNull()
        return when (code) {
            401 -> "Invalid sync key"
            413 -> "Too many changes in one request"
            else -> serverMessage?.let { "Server error $code: $it" } ?: "Server error $code"
        }
    }

    companion object {
        private val JSON = "application/json; charset=utf-8".toMediaType()

        fun normalizeBaseUrl(url: String): String = url.trim().trimEnd('/')
    }
}
