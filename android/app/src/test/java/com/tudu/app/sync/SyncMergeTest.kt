package com.tudu.app.sync

import com.tudu.app.data.TodoEntity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncMergeTest {
    private fun local(id: String, updatedAt: Long, pending: Boolean = false, title: String = "local") =
        TodoEntity(id = id, title = title, createdAt = 1, updatedAt = updatedAt, pending = pending)

    private fun remote(id: String, updatedAt: Long, title: String = "remote") =
        WireTodo(id = id, title = title, createdAt = 1, updatedAt = updatedAt)

    @Test fun remoteAppliesWhenLocalMissing() {
        assertTrue(SyncMerge.shouldApplyRemote(null, remote("a", 5)))
    }

    @Test fun remoteAppliesOnlyWhenStrictlyNewer() {
        assertTrue(SyncMerge.shouldApplyRemote(local("a", 5), remote("a", 6)))
        assertFalse("tie keeps local", SyncMerge.shouldApplyRemote(local("a", 5), remote("a", 5)))
        assertFalse(SyncMerge.shouldApplyRemote(local("a", 5), remote("a", 4)))
    }

    @Test fun timestampsCompareAsLongMillis() {
        val big = 1_762_600_000_123L
        assertTrue(SyncMerge.shouldApplyRemote(local("a", big), remote("a", big + 1)))
        assertFalse(SyncMerge.shouldApplyRemote(local("a", big + 1), remote("a", big)))
    }

    @Test fun mergeWritesNewerAndMissingAsNotPending() {
        val locals = mapOf("a" to local("a", 10, pending = true), "b" to local("b", 10))
        val writes = SyncMerge.merge(locals, listOf(remote("a", 11), remote("b", 9), remote("c", 1)))
        assertEquals(listOf("a", "c"), writes.map { it.id })
        assertTrue(writes.none { it.pending })
        assertEquals("remote", writes.first().title)
    }

    @Test fun mergeCollapsesDuplicateRemoteIdsToNewest() {
        val writes = SyncMerge.merge(emptyMap(), listOf(remote("a", 3, "old"), remote("a", 7, "new"), remote("a", 5, "mid")))
        assertEquals(1, writes.size)
        assertEquals("new", writes.single().title)
    }

    @Test fun mergeLowercasesIds() {
        val id = "6F1C1E9E-3F43-4C1A-9A43-0B6A3F7F2B11"
        val locals = mapOf(id.lowercase() to local(id.lowercase(), 10))
        assertTrue(SyncMerge.merge(locals, listOf(remote(id, 9))).isEmpty())
        assertEquals(id.lowercase(), SyncMerge.merge(emptyMap(), listOf(remote(id, 9))).single().id)
    }

    @Test fun pendingClearsOnlyWhenUnchangedSincePush() {
        val pushed = listOf(local("a", 10, true), local("b", 10, true))
        val current = mapOf("a" to local("a", 10, true), "b" to local("b", 12, true))
        assertEquals(listOf("a"), SyncMerge.clearablePending(pushed, current))
    }

    @Test fun chunksAreAtMost500AndEmptyListStillPulls() {
        assertEquals(listOf(emptyList<Int>()), SyncMerge.chunks(emptyList<Int>()))
        val sizes = SyncMerge.chunks((1..1201).toList()).map { it.size }
        assertEquals(listOf(500, 500, 201), sizes)
    }
}
