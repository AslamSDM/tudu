package com.tudu.app.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.ui.draw.drawBehind
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DeleteSweep
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.TaskAlt
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Surface
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.tudu.app.data.Priority
import com.tudu.app.data.TodoEntity
import com.tudu.app.domain.TodoFilter
import com.tudu.app.domain.TodoLogic
import com.tudu.app.domain.TodoSort
import com.tudu.app.ui.theme.LocalTuduColors
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodoListScreen(
    viewModel: TodoListViewModel,
    quickAddRequest: Int,
    onQuickAddHandled: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    val state by viewModel.state.collectAsState()
    val refreshing by viewModel.refreshing.collectAsState()
    val syncSettings by viewModel.syncSettings.collectAsState()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var editing by remember { mutableStateOf<TodoEntity?>(null) }
    var searching by rememberSaveable { mutableStateOf(false) }
    val quickAddFocus = remember { FocusRequester() }
    val scrollBehavior = TopAppBarDefaults.pinnedScrollBehavior()

    val keyboard = LocalSoftwareKeyboardController.current
    LaunchedEffect(quickAddRequest) {
        if (quickAddRequest > 0) {
            // Wait for the first layout so the focus target is attached (cold start from the widget).
            kotlinx.coroutines.delay(150)
            runCatching { quickAddFocus.requestFocus() }
            keyboard?.show()
            onQuickAddHandled()
        }
    }

    LaunchedEffect(Unit) {
        viewModel.messages.collect { message ->
            snackbar.currentSnackbarData?.dismiss()
            when (message) {
                is ListMessage.Deleted -> scope.launch {
                    val result = snackbar.showSnackbar(
                        message = "Deleted “${TodoLogic.displayTitle(message.todo)}”",
                        actionLabel = "Undo",
                        duration = SnackbarDuration.Short,
                    )
                    if (result == SnackbarResult.ActionPerformed) viewModel.restore(message.todo)
                }
                is ListMessage.Toggled -> scope.launch {
                    val result = snackbar.showSnackbar(
                        message = if (message.nowCompleted) "Marked as done" else "Marked as not done",
                        actionLabel = "Undo",
                        duration = SnackbarDuration.Short,
                    )
                    if (result == SnackbarResult.ActionPerformed) {
                        viewModel.setCompleted(message.todo, !message.nowCompleted)
                    }
                }
                is ListMessage.Info -> scope.launch { snackbar.showSnackbar(message.text) }
            }
        }
    }

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                scrollBehavior = scrollBehavior,
                title = {
                    if (searching) {
                        SearchField(
                            value = state.search,
                            onValueChange = viewModel::setSearch,
                            onClose = {
                                viewModel.setSearch("")
                                searching = false
                            },
                        )
                    } else {
                        Text("Tudu", fontWeight = FontWeight.SemiBold)
                    }
                },
                actions = {
                    if (!searching) {
                        IconButton(onClick = { searching = true }) { Icon(Icons.Default.Search, "Search") }
                    }
                    SortMenu(current = state.sort, onSelect = viewModel::setSort)
                    OverflowMenu(
                        canClearCompleted = state.hasCompleted,
                        onClearCompleted = viewModel::clearCompleted,
                        onOpenSettings = onOpenSettings,
                    )
                },
            )
        },
        bottomBar = {
            QuickAddBar(
                focusRequester = quickAddFocus,
                knownTags = state.allTags,
                contextTag = state.tag,
                onAdd = viewModel::add,
            )
        },
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = refreshing,
            onRefresh = viewModel::refresh,
            modifier = Modifier.fillMaxSize().padding(padding),
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                item(key = "header") {
                    ProgressHeader(
                        stats = state.stats,
                        syncLabel = syncLabel(syncSettings),
                        syncError = syncSettings?.lastSyncOk == false,
                    )
                }
                item(key = "filters") {
                    FilterRow(current = state.filter, onSelect = viewModel::setFilter)
                }
                if (state.allTags.isNotEmpty()) {
                    item(key = "tags") {
                        TagRow(tags = state.allTags, selected = state.tag, onSelect = viewModel::setTag)
                    }
                }

                if (state.loaded && state.isEmpty) {
                    item(key = "empty") { EmptyState(state) }
                }

                if (state.pending.isNotEmpty()) {
                    item(key = "pending-header") { SectionHeader("To Do", state.pending.size, MaterialTheme.colorScheme.primary) }
                    items(state.pending, key = { it.id }) { todo ->
                        SwipeableTodoRow(
                            todo = todo,
                            onToggle = { viewModel.setCompleted(todo, !todo.isCompleted) },
                            onSwipeComplete = { viewModel.setCompleted(todo, !todo.isCompleted, announce = true) },
                            onDelete = { viewModel.delete(todo) },
                            onOpen = { editing = todo },
                            modifier = Modifier.animateItem(),
                        )
                    }
                }
                if (state.completed.isNotEmpty()) {
                    item(key = "completed-header") {
                        SectionHeader("Completed", state.completed.size, LocalTuduColors.current.success)
                    }
                    items(state.completed, key = { it.id }) { todo ->
                        SwipeableTodoRow(
                            todo = todo,
                            onToggle = { viewModel.setCompleted(todo, !todo.isCompleted) },
                            onSwipeComplete = { viewModel.setCompleted(todo, !todo.isCompleted, announce = true) },
                            onDelete = { viewModel.delete(todo) },
                            onOpen = { editing = todo },
                            modifier = Modifier.animateItem(),
                        )
                    }
                }
            }
        }
    }

    editing?.let { todo ->
        TodoEditorSheet(
            todo = todo,
            onDismiss = { editing = null },
            onSave = {
                viewModel.save(it)
                editing = null
            },
            onDelete = {
                viewModel.delete(todo)
                editing = null
            },
        )
    }
}

private fun syncLabel(settings: com.tudu.app.data.SyncSettings?): String? {
    settings ?: return null
    if (!settings.isConnected) return "Sync off"
    if (settings.lastSyncOk == false) return settings.lastSyncMessage ?: "Sync failed"
    val at = settings.lastSyncAt ?: return "Not synced yet"
    return "Synced ${relativeTime(at)}"
}

internal fun relativeTime(ms: Long, now: Long = System.currentTimeMillis()): String {
    val diff = (now - ms).coerceAtLeast(0) / 1000
    return when {
        diff < 45 -> "just now"
        diff < 3600 -> "${maxOf(1, diff / 60)} min ago"
        diff < 86_400 -> "${diff / 3600} h ago"
        else -> "${diff / 86_400} d ago"
    }
}

@Composable
private fun SearchField(value: String, onValueChange: (String) -> Unit, onClose: () -> Unit) {
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
    TextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = { Text("Search tasks") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth().focusRequester(focus),
        leadingIcon = { Icon(Icons.Default.Search, null) },
        trailingIcon = { IconButton(onClick = onClose) { Icon(Icons.Default.Close, "Close search") } },
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
        ),
    )
}

@Composable
private fun SortMenu(current: TodoSort, onSelect: (TodoSort) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { open = true }) { Icon(Icons.AutoMirrored.Filled.Sort, "Sort") }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            TodoSort.entries.forEach { sort ->
                DropdownMenuItem(
                    text = { Text(sort.title) },
                    onClick = {
                        onSelect(sort)
                        open = false
                    },
                    trailingIcon = { if (sort == current) Icon(Icons.Default.Check, null) },
                )
            }
        }
    }
}

@Composable
private fun OverflowMenu(canClearCompleted: Boolean, onClearCompleted: () -> Unit, onOpenSettings: () -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { open = true }) { Icon(Icons.Default.MoreVert, "More") }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            DropdownMenuItem(
                text = { Text("Clear completed") },
                leadingIcon = { Icon(Icons.Default.DeleteSweep, null) },
                enabled = canClearCompleted,
                onClick = {
                    open = false
                    onClearCompleted()
                },
            )
            DropdownMenuItem(
                text = { Text("Settings & sync") },
                leadingIcon = { Icon(Icons.Default.Settings, null) },
                onClick = {
                    open = false
                    onOpenSettings()
                },
            )
        }
    }
}

@Composable
private fun ProgressHeader(stats: TodoStats, syncLabel: String?, syncError: Boolean) {
    val colors = LocalTuduColors.current
    val progress by animateFloatAsState(stats.progress, label = "progress")
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    "${stats.completed}",
                    style = MaterialTheme.typography.displaySmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
                Text(
                    " of ${stats.total} done",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f),
                    modifier = Modifier.padding(bottom = 6.dp),
                )
            }
            Spacer(Modifier.height(12.dp))
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth().height(8.dp).clip(CircleShape),
                trackColor = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.12f),
                drawStopIndicator = {},
            )
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                if (stats.overdue > 0) StatPill("${stats.overdue} overdue", colors.overdue)
                if (stats.dueToday > 0) StatPill("${stats.dueToday} due today", MaterialTheme.colorScheme.primary)
                Spacer(Modifier.weight(1f))
                if (syncLabel != null) {
                    Text(
                        syncLabel,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (syncError) colors.danger else MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

@Composable
private fun StatPill(text: String, color: Color) {
    Surface(shape = CircleShape, color = color.copy(alpha = 0.16f)) {
        Text(
            text,
            color = color,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FilterRow(current: TodoFilter, onSelect: (TodoFilter) -> Unit) {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        TodoFilter.entries.forEachIndexed { index, filter ->
            SegmentedButton(
                selected = filter == current,
                onClick = { onSelect(filter) },
                shape = SegmentedButtonDefaults.itemShape(index, TodoFilter.entries.size),
            ) { Text(filter.title) }
        }
    }
}

@Composable
private fun TagRow(tags: List<String>, selected: String?, onSelect: (String?) -> Unit) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        items(tags, key = { it.lowercase() }) { tag ->
            val isSelected = tag.equals(selected, ignoreCase = true)
            FilterChip(
                selected = isSelected,
                onClick = { onSelect(if (isSelected) null else tag) },
                label = { Text("#$tag") },
                leadingIcon = if (isSelected) {
                    { Icon(Icons.Default.Check, null, Modifier.size(FilterChipDefaults.IconSize)) }
                } else {
                    null
                },
            )
        }
    }
}

@Composable
private fun SectionHeader(title: String, count: Int, color: Color) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(top = 8.dp, bottom = 2.dp, start = 4.dp),
    ) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(color))
        Spacer(Modifier.width(8.dp))
        Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.width(6.dp))
        Text("$count", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun EmptyState(state: TodoListUiState) {
    val (title, message) = when {
        state.search.isNotBlank() || state.tag != null -> "No matches" to "Try a different search or tag."
        state.filter == TodoFilter.COMPLETED -> "Nothing completed" to "Completed tasks will show up here."
        state.filter == TodoFilter.ACTIVE && state.stats.total > 0 -> "All caught up" to "Every task is done. Nice work."
        else -> "No tasks yet" to "Add your first task below."
    }
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth().padding(vertical = 48.dp),
    ) {
        Icon(
            Icons.Default.TaskAlt,
            null,
            modifier = Modifier.size(56.dp),
            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.6f),
        )
        Spacer(Modifier.height(12.dp))
        Text(title, style = MaterialTheme.typography.titleMedium)
        Text(message, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun SwipeableTodoRow(
    todo: TodoEntity,
    onToggle: () -> Unit,
    onSwipeComplete: () -> Unit,
    onDelete: () -> Unit,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = LocalTuduColors.current
    val dismissState = rememberSwipeToDismissBoxState()

    LaunchedEffect(dismissState.currentValue) {
        when (dismissState.currentValue) {
            SwipeToDismissBoxValue.StartToEnd -> {
                onSwipeComplete()
                dismissState.snapTo(SwipeToDismissBoxValue.Settled)
            }
            SwipeToDismissBoxValue.EndToStart -> onDelete()
            SwipeToDismissBoxValue.Settled -> Unit
        }
    }

    SwipeToDismissBox(
        state = dismissState,
        modifier = modifier,
        backgroundContent = {
            val direction = dismissState.dismissDirection
            val target = when (direction) {
                SwipeToDismissBoxValue.StartToEnd -> colors.success
                SwipeToDismissBoxValue.EndToStart -> colors.danger
                else -> Color.Transparent
            }
            val bg by animateColorAsState(target, label = "swipe-bg")
            val (icon, alignment) = when (direction) {
                SwipeToDismissBoxValue.EndToStart -> Icons.Default.Delete to Alignment.CenterEnd
                else -> (if (todo.isCompleted) Icons.AutoMirrored.Filled.Undo else Icons.Default.Check) to Alignment.CenterStart
            }
            Box(
                Modifier.fillMaxSize().clip(RoundedCornerShape(18.dp)).background(bg).padding(horizontal = 24.dp),
                contentAlignment = alignment,
            ) {
                if (direction != SwipeToDismissBoxValue.Settled) Icon(icon, null, tint = Color.White)
            }
        },
    ) {
        TodoRow(todo = todo, onToggle = onToggle, onOpen = onOpen)
    }
}

@Composable
private fun TodoRow(todo: TodoEntity, onToggle: () -> Unit, onOpen: () -> Unit) {
    val colors = LocalTuduColors.current
    val overdue = TodoLogic.isOverdue(todo)
    Card(
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
        modifier = Modifier.fillMaxWidth().clickable(onClick = onOpen),
    ) {
        val accent = when {
            todo.isCompleted -> Color.Transparent
            todo.priorityLevel == Priority.HIGH -> colors.high
            todo.priorityLevel == Priority.LOW -> MaterialTheme.colorScheme.primary
            else -> Color.Transparent
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .drawBehind { drawRect(accent, size = androidx.compose.ui.geometry.Size(4.dp.toPx(), size.height)) }
                .padding(start = 4.dp, end = 16.dp, top = 6.dp, bottom = 6.dp),
        ) {
            IconButton(onClick = onToggle) {
                Icon(
                    imageVector = if (todo.isCompleted) Icons.Default.CheckCircle else Icons.Default.RadioButtonUnchecked,
                    contentDescription = if (todo.isCompleted) "Mark as not done" else "Mark as done",
                    tint = when {
                        todo.isCompleted -> colors.success
                        overdue -> colors.overdue
                        todo.priorityLevel == Priority.HIGH -> colors.high
                        else -> MaterialTheme.colorScheme.outline
                    },
                )
            }
            Column(Modifier.weight(1f).padding(vertical = 6.dp)) {
                Text(
                    TodoLogic.displayTitle(todo),
                    style = MaterialTheme.typography.bodyLarge,
                    textDecoration = if (todo.isCompleted) TextDecoration.LineThrough else null,
                    color = if (todo.isCompleted) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (todo.notes.isNotBlank()) {
                    Text(
                        todo.notes.trim(),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                val due = if (!todo.isCompleted) TodoLogic.dueLabel(todo) else null
                val showPriority = !todo.isCompleted && todo.priorityLevel != Priority.MEDIUM
                if (due != null || showPriority || todo.tags.isNotEmpty()) {
                    Spacer(Modifier.height(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        if (due != null) {
                            Badge(
                                Icons.Default.CalendarToday,
                                due,
                                if (overdue || TodoLogic.isDueToday(todo)) colors.overdue else MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        if (showPriority) {
                            Badge(
                                Icons.Default.Flag,
                                todo.priorityLevel.title,
                                if (todo.priorityLevel == Priority.HIGH) colors.high else MaterialTheme.colorScheme.primary,
                            )
                        }
                        todo.tags.take(3).forEach { Badge(null, "#$it", MaterialTheme.colorScheme.tertiary) }
                    }
                }
            }
        }
    }
}

@Composable
internal fun Badge(icon: ImageVector?, text: String, color: Color) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .clip(CircleShape)
            .background(color.copy(alpha = 0.12f))
            .padding(horizontal = 8.dp, vertical = 2.dp),
    ) {
        if (icon != null) {
            Icon(icon, null, tint = color, modifier = Modifier.size(12.dp))
            Spacer(Modifier.width(4.dp))
        }
        Text(text, color = color, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Medium, maxLines = 1)
    }
}
