package com.tudu.app.sync

import com.tudu.app.data.TodoEntity

/** Pure last-write-wins merge rules from docs/SYNC_API.md. */
object SyncMerge {
    const val MAX_CHANGES_PER_REQUEST = 500

    /** Take the remote record when the local one is missing or strictly older. */
    fun shouldApplyRemote(local: TodoEntity?, remote: WireTodo): Boolean =
        local == null || remote.updatedAt > local.updatedAt

    /**
     * Returns the records to write locally. Duplicate remote ids collapse to the newest one.
     * Written records are not pending: they now match the server.
     */
    fun merge(locals: Map<String, TodoEntity>, remote: List<WireTodo>): List<TodoEntity> {
        val newestRemote = LinkedHashMap<String, WireTodo>()
        for (r in remote) {
            val id = r.id.lowercase()
            val seen = newestRemote[id]
            if (seen == null || r.updatedAt > seen.updatedAt) newestRemote[id] = r
        }
        return newestRemote.values
            .filter { shouldApplyRemote(locals[it.id.lowercase()], it) }
            .map { it.toEntity(pending = false) }
    }

    /**
     * Ids whose pending flag can be cleared after a push: the local record still has the
     * `updatedAt` that was sent. A record changed again during the request stays pending.
     */
    fun clearablePending(pushed: List<TodoEntity>, current: Map<String, TodoEntity>): List<String> =
        pushed.filter { p -> current[p.id]?.let { it.pending && it.updatedAt == p.updatedAt } == true }
            .map { it.id }

    fun <T> chunks(items: List<T>, size: Int = MAX_CHANGES_PER_REQUEST): List<List<T>> =
        if (items.isEmpty()) listOf(emptyList()) else items.chunked(size)
}
