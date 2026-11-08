package com.tudu.app.widget

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.CheckBox
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.tudu.app.MainActivity
import com.tudu.app.R
import com.tudu.app.TuduApp
import com.tudu.app.data.TodoEntity
import com.tudu.app.domain.TodoLogic
import com.tudu.app.domain.TodoSort

private val Orange = ColorProvider(day = Color(0xFFE8710A), night = Color(0xFFFFA65C))

class TuduWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val repository = TuduApp.container(context).repository
        provideContent {
            val todos by repository.todos.collectAsState(initial = null)
            GlanceTheme {
                WidgetContent(context, todos)
            }
        }
    }
}

@Composable
private fun WidgetContent(context: Context, todos: List<TodoEntity>?) {
    val now = System.currentTimeMillis()
    val pending = TodoSort.DUE_DATE.sorted(todos.orEmpty().filter { !it.isCompleted })
    val overdue = pending.count { TodoLogic.isOverdue(it, now) }
    val openApp = actionStartActivity(
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
    )
    val quickAdd = actionStartActivity(
        Intent(context, MainActivity::class.java)
            .setAction(MainActivity.ACTION_QUICK_ADD)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
    )

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.widgetBackground)
            .cornerRadius(20.dp)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = GlanceModifier.defaultWeight().clickable(openApp)) {
                Text(
                    text = "Tudu",
                    style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 16.sp, fontWeight = FontWeight.Bold),
                )
                val header = when {
                    todos == null -> "Loading…"
                    pending.isEmpty() -> "All done"
                    overdue > 0 -> "${pending.size} to do · $overdue overdue"
                    else -> "${pending.size} to do"
                }
                Text(
                    text = header,
                    style = TextStyle(
                        color = if (overdue > 0) Orange else GlanceTheme.colors.onSurfaceVariant,
                        fontSize = 12.sp,
                    ),
                )
            }
            Box(
                modifier = GlanceModifier
                    .size(36.dp)
                    .cornerRadius(18.dp)
                    .background(GlanceTheme.colors.primaryContainer)
                    .clickable(quickAdd),
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    provider = ImageProvider(R.drawable.ic_add),
                    contentDescription = "Add task",
                    modifier = GlanceModifier.size(20.dp),
                    colorFilter = androidx.glance.ColorFilter.tint(GlanceTheme.colors.onPrimaryContainer),
                )
            }
        }
        Spacer(GlanceModifier.height(8.dp))
        if (todos != null && pending.isEmpty()) {
            Box(modifier = GlanceModifier.fillMaxSize().clickable(openApp), contentAlignment = Alignment.Center) {
                Text(
                    text = "Nothing left to do 🎉",
                    style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 13.sp),
                )
            }
        } else {
            LazyColumn(modifier = GlanceModifier.fillMaxSize()) {
                items(pending, itemId = { it.id.hashCode().toLong() }) { todo ->
                    TodoRow(todo, now, openApp)
                }
            }
        }
    }
}

@Composable
private fun TodoRow(todo: TodoEntity, now: Long, openApp: androidx.glance.action.Action) {
    val overdue = TodoLogic.isOverdue(todo, now)
    Row(
        modifier = GlanceModifier.fillMaxWidth().padding(vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CheckBox(
            checked = false,
            onCheckedChange = actionRunCallback<ToggleTodoAction>(actionParametersOf(ToggleTodoAction.TodoId to todo.id)),
        )
        Column(modifier = GlanceModifier.defaultWeight().clickable(openApp)) {
            Text(
                text = TodoLogic.displayTitle(todo),
                maxLines = 1,
                style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 14.sp),
            )
            TodoLogic.dueLabel(todo, now)?.let { label ->
                Text(
                    text = label,
                    style = TextStyle(
                        color = if (overdue) Orange else GlanceTheme.colors.onSurfaceVariant,
                        fontSize = 11.sp,
                        fontWeight = if (overdue) FontWeight.Medium else FontWeight.Normal,
                    ),
                )
            }
        }
    }
}

/** Widget checkbox: toggles completion in Room, marks it pending, enqueues a sync, refreshes. */
class ToggleTodoAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val id = parameters[TodoId] ?: return
        // The repository enqueues the sync and refreshes every widget.
        TuduApp.container(context).repository.setCompleted(id)
    }

    companion object {
        val TodoId = ActionParameters.Key<String>("todoId")
    }
}

class TuduWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TuduWidget()
}

object WidgetUpdater {
    suspend fun refresh(context: Context) {
        runCatching { TuduWidget().updateAll(context) }
    }
}
