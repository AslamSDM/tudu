package com.tudu.app.data

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface TodoDao {
    /** Every record that is not a tombstone. */
    @Query("SELECT * FROM todos WHERE deletedAt IS NULL")
    fun observeVisible(): Flow<List<TodoEntity>>

    @Query("SELECT * FROM todos WHERE id = :id")
    suspend fun getById(id: String): TodoEntity?

    @Query("SELECT * FROM todos WHERE id IN (:ids)")
    suspend fun getByIds(ids: List<String>): List<TodoEntity>

    @Query("SELECT * FROM todos WHERE pending = 1 ORDER BY updatedAt")
    suspend fun getPending(): List<TodoEntity>

    @Query("SELECT COUNT(*) FROM todos WHERE pending = 1")
    fun observePendingCount(): Flow<Int>

    @Upsert
    suspend fun upsert(todo: TodoEntity)

    @Upsert
    suspend fun upsertAll(todos: List<TodoEntity>)

    /** Clears the pending flag only when the record has not changed since it was pushed. */
    @Query("UPDATE todos SET pending = 0 WHERE id = :id AND updatedAt = :pushedUpdatedAt")
    suspend fun clearPending(id: String, pushedUpdatedAt: Long): Int

    /** Used when joining a sync space, so every local record is uploaded. */
    @Query("UPDATE todos SET pending = 1")
    suspend fun markAllPending()
}
