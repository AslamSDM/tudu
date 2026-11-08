package com.tudu.app.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncKeyTest {
    @Test fun generatedKeyIs43UrlSafeChars() {
        val key = SyncKey.generate()
        assertEquals(43, key.length)
        assertTrue(SyncKey.isValid(key))
        assertFalse(key.contains('='))
        assertNotEquals(key, SyncKey.generate())
    }

    @Test fun validation() {
        assertFalse(SyncKey.isValid("short"))
        assertFalse(SyncKey.isValid("a".repeat(31)))
        assertTrue(SyncKey.isValid("a".repeat(32)))
        assertFalse(SyncKey.isValid("a".repeat(31) + "+"))
    }

    @Test fun parsesDeepLink() {
        val key = "Ab-_" + "x".repeat(40)
        val link = SyncLink.parse("tudu://sync?url=https%3A%2F%2Ftudu-sync.example.workers.dev&key=$key")
        assertEquals(SyncLink("https://tudu-sync.example.workers.dev", key), link)
    }

    @Test fun roundTripsLink() {
        val link = SyncLink("https://example.com/base", SyncKey.generate())
        assertEquals(link, SyncLink.parse(link.toUri()))
    }

    @Test fun rejectsBadLinks() {
        val key = "k".repeat(43)
        assertNull(SyncLink.parse("https://sync?url=https%3A%2F%2Fa.b&key=$key"))
        assertNull(SyncLink.parse("tudu://other?url=https%3A%2F%2Fa.b&key=$key"))
        assertNull(SyncLink.parse("tudu://sync?url=ftp%3A%2F%2Fa.b&key=$key"))
        assertNull(SyncLink.parse("tudu://sync?url=https%3A%2F%2Fa.b&key=short"))
        assertNull(SyncLink.parse("tudu://sync"))
    }
}
