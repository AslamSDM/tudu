package com.tudu.app.sync

import com.tudu.app.data.TodoEntity
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** A todo on the wire. See docs/SYNC_API.md. Timestamps are ms since the Unix epoch. */
@Serializable
data class WireTodo(
    val id: String,
    val title: String = "",
    val notes: String = "",
    val isCompleted: Boolean = false,
    val priority: Int = 1,
    val dueDate: Long? = null,
    val tags: List<String> = emptyList(),
    val createdAt: Long = 0,
    val updatedAt: Long = 0,
    val completedAt: Long? = null,
    val deletedAt: Long? = null,
)

@Serializable
data class SyncRequest(val cursor: Long, val changes: List<WireTodo>)

@Serializable
data class SyncResponse(val cursor: Long, val changes: List<WireTodo> = emptyList(), val serverTime: Long? = null)

@Serializable
data class ErrorResponse(val error: String? = null)

val WireJson: Json = Json {
    ignoreUnknownKeys = true
    explicitNulls = true
    encodeDefaults = true
    coerceInputValues = true
}

fun TodoEntity.toWire(): WireTodo = WireTodo(
    id = id.lowercase(),
    title = title,
    notes = notes,
    isCompleted = isCompleted,
    priority = priority,
    dueDate = dueDate,
    tags = tags,
    createdAt = createdAt,
    updatedAt = updatedAt,
    completedAt = completedAt,
    deletedAt = deletedAt,
)

fun WireTodo.toEntity(pending: Boolean = false): TodoEntity = TodoEntity(
    id = id.lowercase(),
    title = title,
    notes = notes,
    isCompleted = isCompleted,
    priority = priority.coerceIn(0, 2),
    dueDate = dueDate,
    tags = tags,
    createdAt = if (createdAt > 0) createdAt else updatedAt,
    updatedAt = updatedAt,
    completedAt = completedAt,
    deletedAt = deletedAt,
    pending = pending,
)
