package com.tudu.app.domain

import com.tudu.app.data.TodoEntity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.Locale

class TodoLogicTest {
    private fun todo(id: String, created: Long, due: Long? = null, priority: Int = 1, title: String = id, done: Boolean = false) =
        TodoEntity(id = id, title = title, createdAt = created, updatedAt = created, dueDate = due, priority = priority, isCompleted = done)

    @Test fun dueDateSortPutsUndatedLastAndBreaksTiesByNewest() {
        val list = listOf(todo("none-old", 1), todo("late", 2, due = 200), todo("early", 3, due = 100), todo("none-new", 4), todo("early-new", 5, due = 100))
        assertEquals(listOf("early-new", "early", "late", "none-new", "none-old"), TodoSort.DUE_DATE.sorted(list).map { it.id })
    }

    @Test fun prioritySortHighFirstThenNewest() {
        val list = listOf(todo("lo", 1, priority = 0), todo("hi-old", 2, priority = 2), todo("hi-new", 3, priority = 2), todo("mid", 4))
        assertEquals(listOf("hi-new", "hi-old", "mid", "lo"), TodoSort.PRIORITY.sorted(list).map { it.id })
    }

    @Test fun alphabeticalIsCaseInsensitive() {
        val list = listOf(todo("1", 1, title = "banana"), todo("2", 2, title = "Apple"), todo("3", 3, title = "cherry"))
        assertEquals(listOf("Apple", "banana", "cherry"), TodoSort.ALPHABETICAL.sorted(list).map { it.title })
    }

    @Test fun normalizeTagsTrimsAndDedupesCaseInsensitively() {
        assertEquals(listOf("Home", "work"), TodoLogic.normalizeTags(listOf(" Home ", "", "home", "work", "WORK")))
    }

    @Test fun overdueAndDueToday() {
        val zone = ZoneOffset.UTC
        val now = LocalDateTime.of(2026, 11, 8, 12, 0).toInstant(zone).toEpochMilli()
        val earlierToday = now - 3_600_000
        val laterToday = now + 3_600_000
        assertTrue(TodoLogic.isOverdue(todo("a", 1, due = earlierToday), now))
        assertFalse(TodoLogic.isOverdue(todo("a", 1, due = earlierToday, done = true), now))
        assertTrue(TodoLogic.isDueToday(todo("a", 1, due = laterToday), now, zone))
        assertEquals("Overdue", TodoLogic.dueLabel(todo("a", 1, due = earlierToday), now, zone, Locale.US))
        assertEquals("Today", TodoLogic.dueLabel(todo("a", 1, due = laterToday), now, zone, Locale.US))
        assertEquals("Tomorrow", TodoLogic.dueLabel(todo("a", 1, due = now + 86_400_000), now, zone, Locale.US))
        assertEquals("Nov 20", TodoLogic.dueLabel(todo("a", 1, due = now + 12 * 86_400_000L), now, zone, Locale.US))
    }

    @Test fun searchMatchesTitleNotesAndTags() {
        val t = todo("a", 1, title = "Buy milk").copy(notes = "from the corner shop", tags = listOf("Errands"))
        assertTrue(TodoLogic.matchesSearch(t, "MILK"))
        assertTrue(TodoLogic.matchesSearch(t, "corner"))
        assertTrue(TodoLogic.matchesSearch(t, "errand"))
        assertFalse(TodoLogic.matchesSearch(t, "bread"))
    }
}
