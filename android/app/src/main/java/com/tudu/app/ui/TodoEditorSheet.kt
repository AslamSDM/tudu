package com.tudu.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.InputChip
import androidx.compose.material3.InputChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import com.tudu.app.data.Priority
import com.tudu.app.data.TodoEntity
import com.tudu.app.domain.TodoLogic
import com.tudu.app.ui.theme.LocalTuduColors
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TodoEditorSheet(
    todo: TodoEntity,
    onDismiss: () -> Unit,
    onSave: (TodoEntity) -> Unit,
    onDelete: () -> Unit,
) {
    val zone = ZoneId.systemDefault()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var title by remember { mutableStateOf(todo.title) }
    var notes by remember { mutableStateOf(todo.notes) }
    var priority by remember { mutableStateOf(todo.priorityLevel) }
    var due by remember { mutableStateOf(todo.dueDate?.let { LocalDateTime.ofInstant(Instant.ofEpochMilli(it), zone) }) }
    var tags by remember { mutableStateOf(todo.tags) }
    var tagInput by remember { mutableStateOf("") }
    var completed by remember { mutableStateOf(todo.isCompleted) }
    var showDatePicker by remember { mutableStateOf(false) }
    var showTimePicker by remember { mutableStateOf(false) }

    fun addTag() {
        val parts = tagInput.split(',').map { it.trim().removePrefix("#") }.filter { it.isNotEmpty() }
        if (parts.isNotEmpty()) tags = TodoLogic.normalizeTags(tags + parts)
        tagInput = ""
    }

    fun save() {
        addTag()
        onSave(
            todo.copy(
                title = title.trim().ifEmpty { todo.title },
                notes = notes,
                priority = priority.wire,
                dueDate = due?.atZone(zone)?.toInstant()?.toEpochMilli(),
                tags = TodoLogic.normalizeTags(tags + tagInput.split(',')),
                isCompleted = completed,
            ),
        )
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .navigationBarsPadding()
                .imePadding(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Edit task", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Text("Done", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.size(8.dp))
                Switch(checked = completed, onCheckedChange = { completed = it })
            }

            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("Title") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                modifier = Modifier.fillMaxWidth(),
            )

            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("Notes") },
                minLines = 3,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                modifier = Modifier.fillMaxWidth(),
            )

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Priority", style = MaterialTheme.typography.labelLarge)
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    Priority.entries.forEachIndexed { index, p ->
                        SegmentedButton(
                            selected = p == priority,
                            onClick = { priority = p },
                            shape = SegmentedButtonDefaults.itemShape(index, Priority.entries.size),
                        ) { Text(p.title) }
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Due", style = MaterialTheme.typography.labelLarge)
                val current = due
                if (current == null) {
                    AssistChip(
                        onClick = { showDatePicker = true },
                        label = { Text("Add due date") },
                        leadingIcon = { Icon(Icons.Default.CalendarToday, null, Modifier.size(18.dp)) },
                    )
                } else {
                    val overdue = !completed && current.atZone(zone).toInstant().toEpochMilli() < System.currentTimeMillis()
                    val tint = if (overdue) LocalTuduColors.current.overdue else MaterialTheme.colorScheme.onSurfaceVariant
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        AssistChip(
                            onClick = { showDatePicker = true },
                            label = { Text(current.toLocalDate().format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))) },
                            leadingIcon = { Icon(Icons.Default.CalendarToday, null, Modifier.size(18.dp), tint = tint) },
                        )
                        AssistChip(
                            onClick = { showTimePicker = true },
                            label = { Text(current.toLocalTime().format(DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT))) },
                            leadingIcon = { Icon(Icons.Default.Schedule, null, Modifier.size(18.dp)) },
                        )
                        IconButton(onClick = { due = null }) { Icon(Icons.Default.Close, "Remove due date") }
                    }
                    if (overdue) {
                        Text("Overdue", color = LocalTuduColors.current.overdue, style = MaterialTheme.typography.labelMedium)
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Tags", style = MaterialTheme.typography.labelLarge)
                if (tags.isNotEmpty()) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        tags.forEach { tag ->
                            InputChip(
                                selected = false,
                                onClick = { tags = tags - tag },
                                label = { Text("#$tag") },
                                trailingIcon = { Icon(Icons.Default.Close, "Remove $tag", Modifier.size(InputChipDefaults.IconSize)) },
                            )
                        }
                    }
                }
                OutlinedTextField(
                    value = tagInput,
                    onValueChange = { value ->
                        if (value.endsWith(",")) {
                            tagInput = value
                            addTag()
                        } else {
                            tagInput = value
                        }
                    },
                    placeholder = { Text("Add a tag") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { addTag() }),
                    trailingIcon = {
                        IconButton(onClick = { addTag() }, enabled = tagInput.isNotBlank()) { Icon(Icons.Default.Add, "Add tag") }
                    },
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 16.dp)) {
                TextButton(onClick = onDelete) {
                    Icon(Icons.Default.Delete, null, tint = MaterialTheme.colorScheme.error)
                    Spacer(Modifier.size(6.dp))
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = onDismiss) { Text("Cancel") }
                Spacer(Modifier.size(8.dp))
                Button(onClick = { save() }, enabled = title.isNotBlank()) { Text("Save") }
            }
            Spacer(Modifier.height(8.dp))
        }
    }

    if (showDatePicker) {
        val initialDate = (due?.toLocalDate() ?: LocalDate.now(zone))
        val pickerState = rememberDatePickerState(
            initialSelectedDateMillis = initialDate.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    pickerState.selectedDateMillis?.let { utcMillis ->
                        val date = Instant.ofEpochMilli(utcMillis).atZone(ZoneOffset.UTC).toLocalDate()
                        val time = due?.toLocalTime() ?: defaultDueTime(date, zone)
                        due = LocalDateTime.of(date, time)
                    }
                    showDatePicker = false
                }) { Text("OK") }
            },
            dismissButton = { TextButton(onClick = { showDatePicker = false }) { Text("Cancel") } },
        ) {
            DatePicker(state = pickerState)
        }
    }

    if (showTimePicker) {
        val initial = due?.toLocalTime() ?: LocalTime.of(18, 0)
        val timeState = rememberTimePickerState(initialHour = initial.hour, initialMinute = initial.minute)
        AlertDialog(
            onDismissRequest = { showTimePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    due = due?.let { LocalDateTime.of(it.toLocalDate(), LocalTime.of(timeState.hour, timeState.minute)) }
                    showTimePicker = false
                }) { Text("OK") }
            },
            dismissButton = { TextButton(onClick = { showTimePicker = false }) { Text("Cancel") } },
            text = { TimePicker(state = timeState) },
        )
    }
}

/** 6 PM by default; end of day when the date is today and 6 PM has passed. */
private fun defaultDueTime(date: LocalDate, zone: ZoneId): LocalTime {
    val evening = LocalTime.of(18, 0)
    val now = LocalDateTime.now(zone)
    return if (date == now.toLocalDate() && now.toLocalTime() >= evening) LocalTime.of(23, 59) else evening
}
