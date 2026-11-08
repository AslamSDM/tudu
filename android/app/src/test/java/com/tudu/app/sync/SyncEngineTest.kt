package com.tudu.app.sync

import com.tudu.app.data.TodoEntity
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** In-memory stand-ins with the same semantics as the Room/DataStore implementations. */
private class FakeLocal(initial: List<TodoEntity>) : SyncLocalStore {
    val rows = initial.associateBy { it.id }.toMutableMap()

    override suspend fun pending() = rows.values.filter { it.pending }.sortedBy { it.updatedAt }

    override suspend fun applyBatch(pushed: List<TodoEntity>, remote: List<WireTodo>): Int {
        val writes = SyncMerge.merge(rows, remote)
        writes.forEach { rows[it.id] = it }
        SyncMerge.clearablePending(pushed, rows).forEach { id -> rows[id] = rows.getValue(id).copy(pending = false) }
        return writes.size
    }
}

private class FakeState(var cursor: Long = 0, var connected: Boolean = true) : SyncStateStore {
    var lastOk: Boolean? = null
    var lastMessage: String? = null
    override suspend fun config() = if (connected) SyncConfig("https://example.test", "k".repeat(43), cursor) else null
    override suspend fun saveCursor(cursor: Long) { this.cursor = cursor }
    override suspend fun recordResult(at: Long, ok: Boolean, message: String?) { lastOk = ok; lastMessage = message }
}

/** A tiny LWW server, following docs/SYNC_API.md. */
private class FakeServer : SyncTransport {
    val stored = mutableMapOf<String, Pair<WireTodo, Long>>()
    var seq = 0L
    val requests = mutableListOf<SyncRequest>()
    var beforeRespond: () -> Unit = {}

    override suspend fun sync(baseUrl: String, syncKey: String, request: SyncRequest): SyncResponse {
        require(request.changes.size <= 500) { "413" }
        requests += request
        for (todo in request.changes) {
            val existing = stored[todo.id]?.first
            if (existing == null || todo.updatedAt > existing.updatedAt) stored[todo.id] = todo to ++seq
        }
        beforeRespond()
        val changes = stored.values.filter { it.second > request.cursor }.sortedBy { it.second }.map { it.first }
        return SyncResponse(cursor = seq, changes = changes, serverTime = 0)
    }
}

class SyncEngineTest {
    private fun todo(id: String, updatedAt: Long, pending: Boolean = true, title: String = id) =
        TodoEntity(id = id, title = title, createdAt = 1, updatedAt = updatedAt, pending = pending)

    @Test fun pushesInChunksOf500AndAdvancesCursor() = runTest {
        val local = FakeLocal((1..1201).map { todo("id-$it", it.toLong()) })
        val state = FakeState()
        val server = FakeServer()
        val result = SyncEngine(local, state, server).sync()

        assertEquals(SyncResult.Success(pushed = 1201, pulled = 0), result)
        assertEquals(listOf(500, 500, 201), server.requests.map { it.changes.size })
        assertEquals(listOf(0L, 500L, 1000L), server.requests.map { it.cursor })
        assertEquals(1201L, state.cursor)
        assertTrue(local.rows.values.none { it.pending })
        assertEquals(true, state.lastOk)
    }

    @Test fun pullsRemoteChangesWithEmptyPush() = runTest {
        val server = FakeServer().apply {
            stored["r"] = WireTodo(id = "r", title = "from mac", createdAt = 1, updatedAt = 50) to ++seq
        }
        val local = FakeLocal(emptyList())
        val state = FakeState()
        val result = SyncEngine(local, state, server).sync()

        assertEquals(SyncResult.Success(pushed = 0, pulled = 1), result)
        assertEquals(1, server.requests.size)
        assertTrue(server.requests.single().changes.isEmpty())
        assertEquals("from mac", local.rows.getValue("r").title)
        assertFalse(local.rows.getValue("r").pending)
    }

    @Test fun recordChangedDuringRequestStaysPending() = runTest {
        val local = FakeLocal(listOf(todo("a", 10)))
        val server = FakeServer()
        server.beforeRespond = { local.rows["a"] = todo("a", 20, title = "edited again") }
        SyncEngine(local, FakeState(), server).sync()

        val row = local.rows.getValue("a")
        assertTrue(row.pending)
        assertEquals("edited again", row.title)
    }

    @Test fun newerServerRecordBeatsOlderLocalEdit() = runTest {
        val server = FakeServer().apply {
            stored["a"] = WireTodo(id = "a", title = "server", createdAt = 1, updatedAt = 100) to ++seq
        }
        val local = FakeLocal(listOf(todo("a", 50, title = "stale local")))
        SyncEngine(local, FakeState(), server).sync()

        assertEquals("server", local.rows.getValue("a").title)
        assertFalse(local.rows.getValue("a").pending)
        assertEquals("server", server.stored.getValue("a").first.title)
    }

    @Test fun tombstonesSyncAndStay() = runTest {
        val local = FakeLocal(listOf(todo("a", 10).copy(deletedAt = 10)))
        val server = FakeServer()
        SyncEngine(local, FakeState(), server).sync()
        assertEquals(10L, server.stored.getValue("a").first.deletedAt)
        assertEquals(10L, local.rows.getValue("a").deletedAt)
    }

    @Test fun notConfiguredDoesNothing() = runTest {
        val server = FakeServer()
        val result = SyncEngine(FakeLocal(listOf(todo("a", 1))), FakeState(connected = false), server).sync()
        assertEquals(SyncResult.NotConfigured, result)
        assertTrue(server.requests.isEmpty())
    }

    @Test fun authErrorIsNotRetryableAndKeepsPending() = runTest {
        val local = FakeLocal(listOf(todo("a", 1)))
        val state = FakeState()
        val result = SyncEngine(local, state, SyncTransport { _, _, _ -> throw SyncHttpException(401, "Invalid sync key") }).sync()
        assertEquals(SyncResult.Failure("Invalid sync key", retryable = false), result)
        assertEquals(false, state.lastOk)
        assertTrue(local.rows.getValue("a").pending)
    }

    @Test fun networkErrorIsRetryable() = runTest {
        val result = SyncEngine(FakeLocal(emptyList()), FakeState(), SyncTransport { _, _, _ -> throw java.io.IOException("offline") }).sync()
        assertTrue(result is SyncResult.Failure && result.retryable)
    }
}
