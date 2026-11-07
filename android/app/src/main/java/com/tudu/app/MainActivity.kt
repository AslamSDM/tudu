package com.tudu.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.tudu.app.sync.SyncLink
import com.tudu.app.ui.TuduRoot
import com.tudu.app.ui.theme.TuduTheme
import kotlinx.coroutines.flow.MutableStateFlow

sealed interface LaunchEvent {
    data object QuickAdd : LaunchEvent
    data class Connect(val link: SyncLink) : LaunchEvent
    data object InvalidLink : LaunchEvent
}

class MainActivity : ComponentActivity() {
    private val events = MutableStateFlow<LaunchEvent?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) handleIntent(intent)
        setContent {
            TuduTheme {
                TuduRoot(events = events, onEventConsumed = { events.value = null })
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        intent ?: return
        when {
            intent.action == ACTION_QUICK_ADD -> events.value = LaunchEvent.QuickAdd
            intent.action == Intent.ACTION_VIEW && intent.data?.scheme == "tudu" -> {
                val link = SyncLink.parse(intent.dataString.orEmpty())
                events.value = if (link != null) LaunchEvent.Connect(link) else LaunchEvent.InvalidLink
            }
        }
    }

    companion object {
        const val ACTION_QUICK_ADD = "com.tudu.app.action.QUICK_ADD"
    }
}
