package com.tudu.app.data

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/** How urgent a task is. `wire` matches the sync API (0 = low, 1 = medium, 2 = high). */
enum class Priority(val wire: Int, val title: String) {
    LOW(0, "Low"),
    MEDIUM(1, "Medium"),
    HIGH(2, "High");

    companion object {
        fun fromWire(value: Int): Priority = entries.firstOrNull { it.wire == value } ?: MEDIUM
    }
}

/**
 * A todo as stored on this device. Tombstones (`deletedAt != null`) stay in the table so the
 * delete can sync; the UI hides them. `pending` marks records changed locally since the last
 * successful push. All timestamps are milliseconds since the Unix epoch.
 */
@Entity(tableName = "todos", indices = [Index("pending"), Index("deletedAt")])
data class TodoEntity(
    @PrimaryKey val id: String,
    val title: String,
    val notes: String = "",
    val isCompleted: Boolean = false,
    val priority: Int = Priority.MEDIUM.wire,
    val dueDate: Long? = null,
    val tags: List<String> = emptyList(),
    val createdAt: Long,
    val updatedAt: Long,
    val completedAt: Long? = null,
    val deletedAt: Long? = null,
    val pending: Boolean = false,
) {
    val priorityLevel: Priority get() = Priority.fromWire(priority)
    val isDeleted: Boolean get() = deletedAt != null
}
