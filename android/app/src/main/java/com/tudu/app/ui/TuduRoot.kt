package com.tudu.app.ui

import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import com.tudu.app.LaunchEvent
import com.tudu.app.TuduApp
import com.tudu.app.sync.SyncLink
import kotlinx.coroutines.flow.StateFlow

private enum class Screen { List, Settings }

@Composable
fun TuduRoot(events: StateFlow<LaunchEvent?>, onEventConsumed: () -> Unit) {
    val context = LocalContext.current
    val container = remember { TuduApp.container(context) }
    val listVm: TodoListViewModel = viewModel { TodoListViewModel(container) }
    val settingsVm: SettingsViewModel = viewModel { SettingsViewModel(container) }

    var screen by rememberSaveable { mutableStateOf(Screen.List) }
    var quickAddRequest by remember { mutableIntStateOf(0) }
    var pendingLink by remember { mutableStateOf<SyncLink?>(null) }
    val event by events.collectAsState()

    LaunchedEffect(event) {
        when (val e = event) {
            LaunchEvent.QuickAdd -> {
                screen = Screen.List
                quickAddRequest++
            }
            is LaunchEvent.Connect -> pendingLink = e.link
            LaunchEvent.InvalidLink -> Toast.makeText(context, "That sync link is not valid", Toast.LENGTH_LONG).show()
            null -> return@LaunchedEffect
        }
        onEventConsumed()
    }

    BackHandler(enabled = screen == Screen.Settings) { screen = Screen.List }

    AnimatedContent(
        targetState = screen,
        transitionSpec = {
            val forward = targetState == Screen.Settings
            (slideInHorizontally { if (forward) it / 3 else -it / 3 } + fadeIn()) togetherWith
                (slideOutHorizontally { if (forward) -it / 3 else it / 3 } + fadeOut())
        },
        label = "screen",
    ) { current ->
        when (current) {
            Screen.List -> TodoListScreen(
                viewModel = listVm,
                quickAddRequest = quickAddRequest,
                onQuickAddHandled = { quickAddRequest = 0 },
                onOpenSettings = { screen = Screen.Settings },
            )
            Screen.Settings -> SettingsScreen(
                viewModel = settingsVm,
                onBack = { screen = Screen.List },
                onScannedLink = { pendingLink = it },
            )
        }
    }

    pendingLink?.let { link ->
        AlertDialog(
            onDismissRequest = { pendingLink = null },
            title = { Text("Connect sync?") },
            text = {
                Text(
                    "This device will sync with the space for this key on\n${link.url}\n\n" +
                        "Tasks on this device are merged into it.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    settingsVm.connect(link.url, link.key)
                    pendingLink = null
                    screen = Screen.Settings
                }) { Text("Connect") }
            },
            dismissButton = { TextButton(onClick = { pendingLink = null }) { Text("Cancel") } },
        )
    }
}
