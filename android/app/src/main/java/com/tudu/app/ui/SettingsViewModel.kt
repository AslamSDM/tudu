package com.tudu.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.tudu.app.AppContainer
import com.tudu.app.data.SyncSettings
import com.tudu.app.sync.SyncKey
import com.tudu.app.sync.SyncResult
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class SettingsViewModel(private val container: AppContainer) : ViewModel() {
    val settings: StateFlow<SyncSettings?> =
        container.settings.settings.stateIn(viewModelScope, SharingStarted.Eagerly, null)

    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()

    private val _messages = Channel<String>(Channel.BUFFERED)
    val messages = _messages.receiveAsFlow()

    fun connect(serverUrl: String, syncKey: String) {
        val url = serverUrl.trim()
        val key = syncKey.trim()
        if (!(url.startsWith("https://") || url.startsWith("http://"))) {
            viewModelScope.launch { _messages.send("Enter a server URL that starts with https://") }
            return
        }
        if (!SyncKey.isValid(key)) {
            viewModelScope.launch { _messages.send("A sync key has at least 32 characters: letters, digits, - and _") }
            return
        }
        launchSync { container.connect(url, key) }
    }

    fun syncNow() = launchSync { container.syncEngine.sync() }

    fun disconnect() {
        viewModelScope.launch {
            container.disconnect()
            _messages.send("Disconnected. Your tasks stay on this device.")
        }
    }

    private fun launchSync(block: suspend () -> SyncResult) {
        if (_busy.value) return
        viewModelScope.launch {
            _busy.value = true
            val result = block()
            _busy.value = false
            _messages.send(
                when (result) {
                    is SyncResult.Success -> "Synced"
                    is SyncResult.Failure -> result.message
                    SyncResult.NotConfigured -> "Enter a server URL and a sync key first"
                },
            )
        }
    }
}
