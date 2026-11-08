package com.tudu.app.domain

import com.tudu.app.data.Priority
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Parses shorthand typed into the quick-add field: `#tag`, `!high` / `!low` (or `!!`, `!3`, `!1`),
 * and `@today`, `@tomorrow`, `@mon`…`@sun`, `@next week`. Unrecognised tokens stay in the title.
 * Keep the rules in step with `QuickAddParser` in the macOS app (`SharedModels.swift`).
 */
object QuickAddParser {
    enum class Kind { TAG, PRIORITY, DATE }

    /** A recognised shorthand at `[start, end)` in the input. */
    data class Token(val start: Int, val end: Int, val kind: Kind, val priority: Priority? = null)

    data class Result(
        val title: String,
        val tags: List<String> = emptyList(),
        val priority: Priority = Priority.MEDIUM,
        val dueDate: Long? = null,
        val tokens: List<Token> = emptyList(),
    ) {
        val hasMetadata: Boolean get() = tags.isNotEmpty() || priority != Priority.MEDIUM || dueDate != null
        val canSubmit: Boolean get() = title.isNotBlank()
    }

    private val weekdays = mapOf(
        "mon" to DayOfWeek.MONDAY, "monday" to DayOfWeek.MONDAY,
        "tue" to DayOfWeek.TUESDAY, "tues" to DayOfWeek.TUESDAY, "tuesday" to DayOfWeek.TUESDAY,
        "wed" to DayOfWeek.WEDNESDAY, "weds" to DayOfWeek.WEDNESDAY, "wednesday" to DayOfWeek.WEDNESDAY,
        "thu" to DayOfWeek.THURSDAY, "thur" to DayOfWeek.THURSDAY, "thurs" to DayOfWeek.THURSDAY,
        "thursday" to DayOfWeek.THURSDAY,
        "fri" to DayOfWeek.FRIDAY, "friday" to DayOfWeek.FRIDAY,
        "sat" to DayOfWeek.SATURDAY, "saturday" to DayOfWeek.SATURDAY,
        "sun" to DayOfWeek.SUNDAY, "sunday" to DayOfWeek.SUNDAY,
    )

    private data class Word(val text: String, val start: Int, val end: Int)

    private fun words(input: String): List<Word> =
        Regex("\\S+").findAll(input).map { Word(it.value, it.range.first, it.range.last + 1) }.toList()

    fun parse(
        input: String,
        now: Long = System.currentTimeMillis(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): Result {
        val moment = Instant.ofEpochMilli(now).atZone(zone)
        val words = words(input)
        val titleWords = ArrayList<String>()
        val tags = ArrayList<String>()
        val tokens = ArrayList<Token>()
        var priority = Priority.MEDIUM
        var due: Long? = null

        var i = 0
        while (i < words.size) {
            val word = words[i]
            val lower = word.text.lowercase()
            val level = priorityFrom(lower)
            val date = if (lower.startsWith("@")) dateFrom(lower.drop(1), moment) else null

            when {
                word.text.length > 1 && word.text.startsWith("#") -> {
                    tags += word.text.drop(1)
                    tokens += Token(word.start, word.end, Kind.TAG)
                }
                level != null -> {
                    priority = level
                    tokens += Token(word.start, word.end, Kind.PRIORITY, level)
                }
                lower == "@next" && words.getOrNull(i + 1)?.text?.lowercase() == "week" -> {
                    due = dueOn(moment.toLocalDate().plusDays(7), moment)
                    tokens += Token(word.start, words[i + 1].end, Kind.DATE)
                    i += 1
                }
                date != null -> {
                    due = date
                    tokens += Token(word.start, word.end, Kind.DATE)
                }
                else -> titleWords += word.text
            }
            i += 1
        }

        return Result(
            title = titleWords.joinToString(" "),
            tags = TodoLogic.normalizeTags(tags),
            priority = priority,
            dueDate = due,
            tokens = tokens,
        )
    }

    private fun priorityFrom(word: String): Priority? = when (word) {
        "!high", "!h", "!!", "!3", "!urgent" -> Priority.HIGH
        "!low", "!l", "!1" -> Priority.LOW
        "!med", "!medium", "!2" -> Priority.MEDIUM
        else -> null
    }

    private fun dateFrom(word: String, moment: ZonedDateTime): Long? {
        val today = moment.toLocalDate()
        return when (word) {
            "today", "tod" -> dueOn(today, moment)
            "tomorrow", "tom", "tmr" -> dueOn(today.plusDays(1), moment)
            else -> weekdays[word]?.let { target ->
                val delta = ((target.value - today.dayOfWeek.value) + 7) % 7
                dueOn(today.plusDays(if (delta == 0) 7L else delta.toLong()), moment)
            }
        }
    }

    /** 5 PM on `day`, or 11:59 PM when 5 PM has already passed, so a new task is never born overdue. */
    private fun dueOn(day: LocalDate, moment: ZonedDateTime): Long {
        val fivePm = day.atTime(17, 0).atZone(moment.zone)
        val due = if (fivePm.isAfter(moment)) fivePm else day.atTime(LocalTime.of(23, 59)).atZone(moment.zone)
        return due.toInstant().toEpochMilli()
    }

    // MARK: Editing helpers for the suggestion chips

    private fun removing(input: String, ranges: List<Token>): String {
        val out = StringBuilder(input)
        ranges.sortedByDescending { it.start }.forEach { out.delete(it.start, it.end) }
        return words(out.toString()).joinToString(" ") { it.text }
    }

    private fun joined(base: String, token: String?): String =
        if (token == null) base.let { if (it.isEmpty()) it else "$it " } else listOf(base, token).filter { it.isNotEmpty() }.joinToString(" ") + " "

    /** Replaces every token of `kind` with `token`, or removes them when `token` is null. */
    fun withToken(input: String, kind: Kind, token: String?): String =
        joined(removing(input, parse(input).tokens.filter { it.kind == kind }), token)

    /** Adds `#tag`, or removes it when it is already present. */
    fun togglingTag(input: String, tag: String): String {
        val matching = parse(input).tokens.filter {
            it.kind == Kind.TAG && input.substring(it.start + 1, it.end).equals(tag, ignoreCase = true)
        }
        return if (matching.isNotEmpty()) joined(removing(input, matching), null) else joined(words(input).joinToString(" ") { it.text }, "#$tag")
    }
}
