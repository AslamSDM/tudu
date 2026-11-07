package com.tudu.app.sync

import com.tudu.app.data.TodoEntity
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WireSerializationTest {
    private val docExample = """
        {
          "id": "6f1c1e9e-3f43-4c1a-9a43-0b6a3f7f2b11",
          "title": "Buy milk",
          "notes": "",
          "isCompleted": false,
          "priority": 1,
          "dueDate": 1762600000000,
          "tags": ["home"],
          "createdAt": 1762500000000,
          "updatedAt": 1762500000000,
          "completedAt": null,
          "deletedAt": null
        }
    """.trimIndent()

    @Test fun decodesTheDocumentedExample() {
        val todo = WireJson.decodeFromString(WireTodo.serializer(), docExample)
        assertEquals("6f1c1e9e-3f43-4c1a-9a43-0b6a3f7f2b11", todo.id)
        assertEquals("Buy milk", todo.title)
        assertEquals(1, todo.priority)
        assertEquals(1_762_600_000_000L, todo.dueDate)
        assertEquals(listOf("home"), todo.tags)
        assertEquals(1_762_500_000_000L, todo.updatedAt)
        assertNull(todo.completedAt)
        assertNull(todo.deletedAt)
    }

    @Test fun encodesEveryFieldIncludingExplicitNulls() {
        val wire = TodoEntity(
            id = "abc", title = "T", createdAt = 1, updatedAt = 2, tags = listOf("x"), priority = 2,
        ).toWire()
        val json = WireJson.parseToJsonElement(WireJson.encodeToString(WireTodo.serializer(), wire)).jsonObject
        assertEquals(
            setOf("id", "title", "notes", "isCompleted", "priority", "dueDate", "tags", "createdAt", "updatedAt", "completedAt", "deletedAt"),
            json.keys,
        )
        assertEquals(JsonNull, json["dueDate"])
        assertEquals(JsonNull, json["deletedAt"])
        assertEquals(2L, json.getValue("updatedAt").jsonPrimitive.long)
        assertEquals("x", json.getValue("tags").jsonArray.single().jsonPrimitive.content)
        assertFalse("pending is local only", json.containsKey("pending"))
    }

    @Test fun encodesSyncRequestShape() {
        val body = WireJson.encodeToString(SyncRequest.serializer(), SyncRequest(cursor = 42, changes = emptyList()))
        assertEquals("""{"cursor":42,"changes":[]}""", body)
    }

    @Test fun decodesResponseAndIgnoresUnknownKeys() {
        val text = """{"cursor":7,"changes":[{"id":"A","updatedAt":5,"extra":true}],"serverTime":1762600000000,"future":1}"""
        val response = WireJson.decodeFromString(SyncResponse.serializer(), text)
        assertEquals(7L, response.cursor)
        assertEquals(1_762_600_000_000L, response.serverTime)
        val entity = response.changes.single().toEntity()
        assertEquals("a", entity.id)
        assertEquals("", entity.title)
        assertEquals(1, entity.priority)
        assertEquals(5L, entity.createdAt)
        assertFalse(entity.pending)
    }

    @Test fun nullForNonNullFieldFallsBackToDefault() {
        val todo = WireJson.decodeFromString(WireTodo.serializer(), """{"id":"a","title":null,"tags":null,"updatedAt":3}""")
        assertEquals("", todo.title)
        assertTrue(todo.tags.isEmpty())
    }

    @Test fun roundTripsEntity() {
        val entity = TodoEntity(
            id = "6f1c1e9e-3f43-4c1a-9a43-0b6a3f7f2b11", title = "Ship it", notes = "n", isCompleted = true,
            priority = 0, dueDate = 1_762_600_000_000L, tags = listOf("a", "b"), createdAt = 1, updatedAt = 9,
            completedAt = 8, deletedAt = null,
        )
        val decoded = WireJson.decodeFromString(WireTodo.serializer(), WireJson.encodeToString(WireTodo.serializer(), entity.toWire()))
        assertEquals(entity, decoded.toEntity())
    }

    @Test fun errorBodyParses() {
        val body = WireJson.decodeFromString(ErrorResponse.serializer(), """{"error":"bad key"}""")
        assertEquals("bad key", body.error)
        assertTrue(WireJson.parseToJsonElement("""{"error":"x"}""") is JsonObject)
    }
}
