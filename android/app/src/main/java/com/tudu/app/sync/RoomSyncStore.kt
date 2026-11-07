package com.tudu.app.sync

import androidx.room.withTransaction
import com.tudu.app.data.AppDatabase
import com.tudu.app.data.TodoEntity

class RoomSyncStore(private val db: AppDatabase) : SyncLocalStore {
    private val dao = db.todoDao()

    override suspend fun pending(): List<TodoEntity> = dao.getPending()

    override suspend fun applyBatch(pushed: List<TodoEntity>, remote: List<WireTodo>): Int =
        db.withTransaction {
            val ids = (remote.map { it.id.lowercase() } + pushed.map { it.id }).distinct()
            // Stay well under SQLite's bound-variable limit.
            val locals = ids.chunked(500).flatMap { dao.getByIds(it) }.associateBy { it.id }
            val writes = SyncMerge.merge(locals, remote)
            if (writes.isNotEmpty()) dao.upsertAll(writes)
            for (p in pushed) dao.clearPending(p.id, p.updatedAt)
            writes.size
        }
}
