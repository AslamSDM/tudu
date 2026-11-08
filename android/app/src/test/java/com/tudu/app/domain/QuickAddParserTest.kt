package com.tudu.app.domain

import com.tudu.app.data.Priority
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneOffset
import java.time.ZonedDateTime

class QuickAddParserTest {
    private val zone = ZoneOffset.UTC

    /** 2026-11-08 is a Sunday. */
    private fun at(hour: Int) = ZonedDateTime.of(2026, 11, 8, hour, 0, 0, 0, zone).toInstant().toEpochMilli()
    private fun on(day: Int, hour: Int = 17, minute: Int = 0) =
        ZonedDateTime.of(2026, 11, day, hour, minute, 0, 0, zone).toInstant().toEpochMilli()

    private fun parse(text: String, hour: Int = 10) = QuickAddParser.parse(text, at(hour), zone)

    @Test fun `parses the documented example`() {
        val r = parse("Pay rent #home !high @fri")
        assertEquals("Pay rent", r.title)
        assertEquals(listOf("home"), r.tags)
        assertEquals(Priority.HIGH, r.priority)
        assertEquals(on(13), r.dueDate)
    }

    @Test fun `tokens work anywhere and in any case`() {
        val r = parse("!LOW Call @Tomorrow the bank #Work")
        assertEquals("Call the bank", r.title)
        assertEquals(Priority.LOW, r.priority)
        assertEquals(on(9), r.dueDate)
        assertEquals(listOf("Work"), r.tags)
    }

    @Test fun `every priority alias resolves`() {
        listOf("!high", "!h", "!!", "!3", "!urgent").forEach { assertEquals(it, Priority.HIGH, parse("x $it").priority) }
        listOf("!low", "!l", "!1").forEach { assertEquals(it, Priority.LOW, parse("x $it").priority) }
        listOf("!med", "!medium", "!2").forEach {
            val r = parse("x $it")
            assertEquals(it, Priority.MEDIUM, r.priority)
            assertEquals(it, "x", r.title)
        }
    }

    @Test fun `date aliases resolve`() {
        assertEquals(on(8), parse("x @today").dueDate)
        assertEquals(on(8), parse("x @tod").dueDate)
        assertEquals(on(9), parse("x @tom").dueDate)
        assertEquals(on(9), parse("x @tmr").dueDate)
        assertEquals(on(15), parse("x @next week").dueDate)
        assertEquals(on(11), parse("x @wednesday").dueDate)
    }

    @Test fun `same weekday means next week`() {
        assertEquals(on(15), parse("x @sun").dueDate)
    }

    @Test fun `today after five is not overdue`() {
        val r = parse("x @today", hour = 20)
        assertEquals(on(8, 23, 59), r.dueDate)
        assertTrue(r.dueDate!! > at(20))
        assertEquals(on(9), parse("x @tomorrow", hour = 20).dueDate)
    }

    @Test fun `unknown tokens stay in the title`() {
        val r = parse("email @monica about # and !important @3pm")
        assertEquals("email @monica about # and !important @3pm", r.title)
        assertFalse(r.hasMetadata)
        assertNull(r.dueDate)
    }

    @Test fun `metadata only cannot be submitted`() {
        assertFalse(parse("#home !high").canSubmit)
        assertTrue(parse("a #home").canSubmit)
    }

    @Test fun `duplicate tags collapse`() {
        assertEquals(listOf("home"), parse("x #home #HOME").tags)
    }

    @Test fun `token ranges cover the shorthand`() {
        val text = "Pay #home @next week !low"
        val spans = parse(text).tokens.map { text.substring(it.start, it.end) }
        assertEquals(listOf("#home", "@next week", "!low"), spans)
    }

    @Test fun `chip helpers replace remove and toggle`() {
        val kind = QuickAddParser.Kind.DATE
        assertEquals("Pay @tomorrow ", QuickAddParser.withToken("Pay @today", kind, "@tomorrow"))
        assertEquals("Pay #a ", QuickAddParser.withToken("Pay @next week #a", kind, null))
        assertEquals("@today ", QuickAddParser.withToken("", kind, "@today"))
        assertEquals("Pay #home ", QuickAddParser.togglingTag("Pay", "home"))
        assertEquals("Pay ", QuickAddParser.togglingTag("Pay #Home", "home"))
    }
}
