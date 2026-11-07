package com.tudu.app.data

import com.tudu.app.domain.TodoLogic
import kotlinx.coroutines.flow.Flow
import java.util.UUID

/**
 * Every local write goes through here. Each change bumps `updatedAt`, marks the record pending,
 * then calls [onLocalChange] (enqueue a sync and refresh the widget).
 */
class TodoRepository(
    private val dao: TodoDao,
    private val clock: () -> Long = System::currentTimeMillis,
    private val onLocalChange: suspend () -> Unit,
) {
    val todos: Flow<List<TodoEntity>> = dao.observeVisible()

    /** A timestamp that is always newer than the record's previous one. */
    private fun bump(previous: Long?): Long {
        val now = clock()
        return if (previous != null && now <= previous) previous + 1 else now
    }

    suspend fun add(
        title: String,
        notes: String = "",
        priority: Priority = Priority.MEDIUM,
        dueDate: Long? = null,
        tags: List<String> = emptyList(),
    ): TodoEntity? {
        val trimmed = title.trim()
        if (trimmed.isEmpty()) return null
        val now = clock()
        val todo = TodoEntity(
            id = UUID.randomUUID().toString().lowercase(),
            title = trimmed,
            notes = notes,
            priority = priority.wire,
            dueDate = dueDate,
            tags = TodoLogic.normalizeTags(tags),
            createdAt = now,
            updatedAt = now,
            pending = true,
        )
        dao.upsert(todo)
        onLocalChange()
        return todo
    }

    /** Saves edits made in the editor. Completion fields are kept consistent. */
    suspend fun save(edited: TodoEntity) {
        val existing = dao.getById(edited.id)
        val completedAt = when {
            !edited.isCompleted -> null
            existing?.isCompleted == true -> existing.completedAt ?: clock()
            else -> clock()
        }
        dao.upsert(
            edited.copy(
                title = edited.title.trim(),
                tags = TodoLogic.normalizeTags(edited.tags),
                completedAt = completedAt,
                updatedAt = bump(existing?.updatedAt),
                pending = true,
            ),
        )
        onLocalChange()
    }

    /** Sets completion, or flips it when [completed] is null. Returns the previous state. */
    suspend fun setCompleted(id: String, completed: Boolean? = null): Boolean? {
        val todo = dao.getById(id) ?: return null
        if (todo.isDeleted) return null
        val newValue = completed ?: !todo.isCompleted
        val updatedAt = bump(todo.updatedAt)
        dao.upsert(
            todo.copy(
                isCompleted = newValue,
                completedAt = if (newValue) updatedAt else null,
                updatedAt = updatedAt,
                pending = true,
            ),
        )
        onLocalChange()
        return todo.isCompleted
    }

    /** Turns the record into a tombstone. */
    suspend fun delete(id: String) {
        val todo = dao.getById(id) ?: return
        if (todo.isDeleted) return
        val now = bump(todo.updatedAt)
        dao.upsert(todo.copy(deletedAt = now, updatedAt = now, pending = true))
        onLocalChange()
    }

    /** Undo for [delete]. */
    suspend fun restore(id: String) {
        val todo = dao.getById(id) ?: return
        if (!todo.isDeleted) return
        dao.upsert(todo.copy(deletedAt = null, updatedAt = bump(todo.updatedAt), pending = true))
        onLocalChange()
    }

    suspend fun markAllPending() = dao.markAllPending()
}
