package com.tudu.app.sync

import com.tudu.app.data.TodoEntity
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

data class SyncConfig(val baseUrl: String, val syncKey: String, val cursor: Long)

/** Persists the sync cursor and the last result (DataStore in the app, a fake in tests). */
interface SyncStateStore {
    suspend fun config(): SyncConfig?
    suspend fun saveCursor(cursor: Long)
    suspend fun recordResult(at: Long, ok: Boolean, message: String?)
}

/** Local records (Room in the app, a fake in tests). */
interface SyncLocalStore {
    suspend fun pending(): List<TodoEntity>

    /** Merges [remote] and clears pending flags for [pushed], atomically. Returns records written. */
    suspend fun applyBatch(pushed: List<TodoEntity>, remote: List<WireTodo>): Int
}

fun interface SyncTransport {
    suspend fun sync(baseUrl: String, syncKey: String, request: SyncRequest): SyncResponse
}

sealed interface SyncResult {
    data class Success(val pushed: Int, val pulled: Int) : SyncResult
    data object NotConfigured : SyncResult
    data class Failure(val message: String, val retryable: Boolean) : SyncResult
}

/**
 * Runs the client algorithm from docs/SYNC_API.md: push pending records in chunks of 500 with
 * the stored cursor, merge each response with LWW, store the new cursor, clear pending ids
 * that did not change during the request. Calls are serialized within the process.
 */
class SyncEngine(
    private val local: SyncLocalStore,
    private val state: SyncStateStore,
    private val transport: SyncTransport,
    private val clock: () -> Long = System::currentTimeMillis,
    private val onDataChanged: suspend () -> Unit = {},
) {
    private val mutex = Mutex()

    suspend fun sync(): SyncResult = mutex.withLock {
        val config = state.config() ?: return@withLock SyncResult.NotConfigured
        var cursor = config.cursor
        var pushed = 0
        var pulled = 0
        try {
            for (batch in SyncMerge.chunks(local.pending())) {
                val response = transport.sync(
                    config.baseUrl,
                    config.syncKey,
                    SyncRequest(cursor = cursor, changes = batch.map { it.toWire() }),
                )
                pulled += local.applyBatch(batch, response.changes)
                pushed += batch.size
                cursor = response.cursor
                state.saveCursor(cursor)
            }
            state.recordResult(clock(), ok = true, message = null)
            SyncResult.Success(pushed = pushed, pulled = pulled)
        } catch (e: SyncHttpException) {
            state.recordResult(clock(), ok = false, message = e.message)
            SyncResult.Failure(e.message ?: "Sync failed", retryable = e.retryable)
        } catch (e: java.io.IOException) {
            val message = "Network error: ${e.message ?: e.javaClass.simpleName}"
            state.recordResult(clock(), ok = false, message = message)
            SyncResult.Failure(message, retryable = true)
        } finally {
            if (pushed > 0 || pulled > 0) onDataChanged()
        }
    }
}
