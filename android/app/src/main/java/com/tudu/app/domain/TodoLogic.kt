package com.tudu.app.domain

import com.tudu.app.data.TodoEntity
import java.text.Collator
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Filter and sort semantics mirror the macOS app (`SharedModels.swift`). */
object TodoLogic {
    fun displayTitle(todo: TodoEntity): String = todo.title.trim().ifEmpty { "Untitled Task" }

    /** Trims, drops blanks, and removes case-insensitive duplicates, keeping the first order. */
    fun normalizeTags(tags: List<String>): List<String> {
        val seen = HashSet<String>()
        return tags.mapNotNull { raw ->
            val tag = raw.trim()
            if (tag.isEmpty() || !seen.add(tag.lowercase())) null else tag
        }
    }

    fun isOverdue(todo: TodoEntity, now: Long = System.currentTimeMillis()): Boolean {
        val due = todo.dueDate ?: return false
        return !todo.isCompleted && due < now
    }

    fun isDueToday(
        todo: TodoEntity,
        now: Long = System.currentTimeMillis(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): Boolean {
        val due = todo.dueDate ?: return false
        if (todo.isCompleted) return false
        return localDate(due, zone) == localDate(now, zone)
    }

    /** "Overdue", "Today", "Tomorrow", "Yesterday", or a short date like "Nov 8". */
    fun dueLabel(
        todo: TodoEntity,
        now: Long = System.currentTimeMillis(),
        zone: ZoneId = ZoneId.systemDefault(),
        locale: Locale = Locale.getDefault(),
    ): String? {
        val due = todo.dueDate ?: return null
        if (isOverdue(todo, now)) return "Overdue"
        val dueDay = localDate(due, zone)
        val today = localDate(now, zone)
        return when (dueDay) {
            today -> "Today"
            today.plusDays(1) -> "Tomorrow"
            today.minusDays(1) -> "Yesterday"
            else -> dueDay.format(DateTimeFormatter.ofPattern("MMM d", locale))
        }
    }

    fun matchesSearch(todo: TodoEntity, query: String): Boolean {
        val q = query.trim()
        if (q.isEmpty()) return true
        return todo.title.contains(q, ignoreCase = true) ||
            todo.notes.contains(q, ignoreCase = true) ||
            todo.tags.any { it.contains(q, ignoreCase = true) }
    }

    fun hasTag(todo: TodoEntity, tag: String?): Boolean =
        tag == null || todo.tags.any { it.equals(tag, ignoreCase = true) }

    /** Every tag in use, case-insensitively unique, sorted A–Z. */
    fun allTags(todos: List<TodoEntity>): List<String> =
        normalizeTags(todos.flatMap { it.tags }).sortedWith(String.CASE_INSENSITIVE_ORDER)

    private fun localDate(ms: Long, zone: ZoneId): LocalDate = Instant.ofEpochMilli(ms).atZone(zone).toLocalDate()
}

enum class TodoFilter(val title: String) {
    ALL("All"),
    ACTIVE("Active"),
    COMPLETED("Completed"),
}

enum class TodoSort(val title: String) {
    CREATED("Newest"),
    DUE_DATE("Due Date"),
    PRIORITY("Priority"),
    ALPHABETICAL("A–Z");

    /** Sorts *pending* tasks. Completed tasks are sorted by [sortCompleted]. */
    fun sorted(todos: List<TodoEntity>): List<TodoEntity> = when (this) {
        CREATED -> todos.sortedByDescending { it.createdAt }
        DUE_DATE -> todos.sortedWith(
            compareBy<TodoEntity, Long?>(nullsLast()) { it.dueDate }
                .thenByDescending { it.createdAt },
        )
        PRIORITY -> todos.sortedWith(
            compareByDescending<TodoEntity> { it.priority }.thenByDescending { it.createdAt },
        )
        ALPHABETICAL -> {
            val collator = Collator.getInstance().apply { strength = Collator.SECONDARY }
            todos.sortedWith { a, b -> collator.compare(a.title, b.title) }
        }
    }

    companion object {
        /** Most recently completed first. */
        fun sortCompleted(todos: List<TodoEntity>): List<TodoEntity> =
            todos.sortedByDescending { it.completedAt ?: it.updatedAt }
    }
}
