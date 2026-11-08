package com.tudu.app.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Tag
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.tudu.app.data.Priority
import com.tudu.app.domain.QuickAddParser
import com.tudu.app.domain.QuickAddParser.Kind
import com.tudu.app.ui.theme.LocalTuduColors
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Colors each recognised shorthand in the text field as it is typed. */
private class ShorthandHighlight(
    private val tag: Color,
    private val date: Color,
    private val high: Color,
    private val low: Color,
    private val medium: Color,
) : VisualTransformation {
    override fun filter(text: AnnotatedString): TransformedText {
        val styled = buildAnnotatedString {
            append(text)
            QuickAddParser.parse(text.text).tokens.forEach { token ->
                val color = when (token.kind) {
                    Kind.TAG -> tag
                    Kind.DATE -> date
                    Kind.PRIORITY -> when (token.priority) {
                        Priority.HIGH -> high
                        Priority.LOW -> low
                        else -> medium
                    }
                }
                addStyle(
                    SpanStyle(color = color, background = color.copy(alpha = 0.14f), fontWeight = FontWeight.SemiBold),
                    token.start,
                    token.end,
                )
            }
        }
        return TransformedText(styled, OffsetMapping.Identity)
    }
}

/** "Today · 5 PM", "Tomorrow · 5 PM", "Fri, Nov 13 · 5 PM". */
private fun previewDue(millis: Long, locale: Locale = Locale.getDefault()): String {
    val zone = ZoneId.systemDefault()
    val due = Instant.ofEpochMilli(millis).atZone(zone)
    val today = LocalDate.now(zone)
    val day = when (due.toLocalDate()) {
        today -> "Today"
        today.plusDays(1) -> "Tomorrow"
        else -> due.format(DateTimeFormatter.ofPattern("EEE, MMM d", locale))
    }
    val time = due.format(DateTimeFormatter.ofPattern(if (due.minute == 0) "h a" else "h:mm a", locale))
    return "$day · $time"
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun QuickAddBar(
    focusRequester: FocusRequester,
    knownTags: List<String>,
    contextTag: String?,
    onAdd: (String) -> Unit,
) {
    var value by rememberSaveable(stateSaver = TextFieldValue.Saver) { mutableStateOf(TextFieldValue("")) }
    var focused by remember { mutableStateOf(false) }
    val keyboard = LocalSoftwareKeyboardController.current
    val colors = LocalTuduColors.current
    val scheme = MaterialTheme.colorScheme

    val parsed = QuickAddParser.parse(value.text)
    val previewTags = com.tudu.app.domain.TodoLogic.normalizeTags(listOfNotNull(contextTag) + parsed.tags)
    val highlight = remember(colors, scheme) {
        ShorthandHighlight(scheme.tertiary, colors.overdue, colors.high, scheme.primary, scheme.onSurfaceVariant)
    }

    fun setText(text: String) {
        value = TextFieldValue(text, TextRange(text.length))
    }

    val submit = {
        if (parsed.canSubmit) {
            onAdd(value.text)
            setText("")
        }
    }

    Surface(tonalElevation = 3.dp, shadowElevation = 8.dp) {
        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .imePadding()
                .padding(horizontal = 12.dp, vertical = 8.dp),
        ) {
            // What the task will get, once something was recognised.
            AnimatedVisibility(
                visible = parsed.hasMetadata || (contextTag != null && value.text.isNotBlank()),
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.padding(horizontal = 4.dp),
                ) {
                    parsed.dueDate?.let { Badge(Icons.Default.CalendarToday, previewDue(it), colors.overdue) }
                    if (parsed.priority != Priority.MEDIUM) {
                        Badge(
                            Icons.Default.Flag,
                            parsed.priority.title,
                            if (parsed.priority == Priority.HIGH) colors.high else scheme.primary,
                        )
                    }
                    previewTags.forEach { Badge(null, "#$it", scheme.tertiary) }
                }
            }

            // One-tap shorthand, because @ ! # sit behind the symbol layer on most keyboards.
            AnimatedVisibility(
                visible = focused,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically(),
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                ) {
                    listOf("Today" to "@today", "Tomorrow" to "@tomorrow", "Next week" to "@next week").forEach { (label, token) ->
                        val selected = parsed.dueDate != null && parsed.dueDate == QuickAddParser.parse(token).dueDate
                        Suggestion(label, Icons.Default.CalendarToday, colors.overdue, selected) {
                            setText(QuickAddParser.withToken(value.text, Kind.DATE, if (selected) null else token))
                        }
                    }
                    listOf(Triple("High", "!high", Priority.HIGH), Triple("Low", "!low", Priority.LOW)).forEach { (label, token, level) ->
                        val selected = parsed.priority == level
                        val tint = if (level == Priority.HIGH) colors.high else scheme.primary
                        Suggestion(label, Icons.Default.Flag, tint, selected) {
                            setText(QuickAddParser.withToken(value.text, Kind.PRIORITY, if (selected) null else token))
                        }
                    }
                    knownTags.take(6).forEach { tag ->
                        val selected = parsed.tags.any { it.equals(tag, ignoreCase = true) }
                        Suggestion(tag, Icons.Default.Tag, scheme.tertiary, selected) {
                            setText(QuickAddParser.togglingTag(value.text, tag))
                        }
                    }
                    Suggestion("New tag", Icons.Default.Tag, scheme.tertiary, selected = false) {
                        setText(value.text.trimEnd().let { if (it.isEmpty()) "#" else "$it #" })
                    }
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = value,
                    onValueChange = { value = it },
                    placeholder = { Text("Add a task…  #tag !high @fri", maxLines = 1) },
                    singleLine = true,
                    visualTransformation = highlight,
                    shape = RoundedCornerShape(28.dp),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = {
                        if (value.text.isBlank()) keyboard?.hide()
                        submit()
                    }),
                    modifier = Modifier
                        .weight(1f)
                        .focusRequester(focusRequester)
                        .onFocusChanged { focused = it.isFocused },
                )
                Spacer(Modifier.width(8.dp))
                FilledIconButton(
                    onClick = submit,
                    enabled = parsed.canSubmit,
                    modifier = Modifier.size(52.dp),
                ) { Icon(Icons.AutoMirrored.Filled.Send, "Add task") }
            }
        }
    }
}

@Composable
private fun Suggestion(label: String, icon: ImageVector, tint: Color, selected: Boolean, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(label, maxLines = 1) },
        leadingIcon = { Icon(icon, null, tint = tint, modifier = Modifier.size(FilterChipDefaults.IconSize)) },
        colors = FilterChipDefaults.filterChipColors(selectedContainerColor = tint.copy(alpha = 0.18f)),
    )
}
