package com.tudu.app.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.tudu.app.DEFAULT_SERVER_URL
import com.tudu.app.domain.TodoSort
import com.tudu.app.sync.SyncConfig
import com.tudu.app.sync.SyncStateStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

data class SyncSettings(
    val serverUrl: String,
    val syncKey: String,
    val cursor: Long,
    val lastSyncAt: Long?,
    val lastSyncOk: Boolean?,
    val lastSyncMessage: String?,
) {
    val isConnected: Boolean get() = syncKey.isNotBlank() && serverUrl.isNotBlank()
}

class SettingsStore(context: Context) : SyncStateStore {
    private val store = context.applicationContext.dataStore

    private object Keys {
        val serverUrl = stringPreferencesKey("server_url")
        val syncKey = stringPreferencesKey("sync_key")
        val cursor = longPreferencesKey("cursor")
        val lastSyncAt = longPreferencesKey("last_sync_at")
        val lastSyncOk = booleanPreferencesKey("last_sync_ok")
        val lastSyncMessage = stringPreferencesKey("last_sync_message")
        val sort = stringPreferencesKey("sort")
    }

    val settings: Flow<SyncSettings> = store.data.map { p ->
        SyncSettings(
            serverUrl = p[Keys.serverUrl] ?: DEFAULT_SERVER_URL,
            syncKey = p[Keys.syncKey].orEmpty(),
            cursor = p[Keys.cursor] ?: 0L,
            lastSyncAt = p[Keys.lastSyncAt],
            lastSyncOk = p[Keys.lastSyncOk],
            lastSyncMessage = p[Keys.lastSyncMessage],
        )
    }

    val sort: Flow<TodoSort> = store.data.map { p ->
        TodoSort.entries.firstOrNull { it.name == p[Keys.sort] } ?: TodoSort.CREATED
    }

    suspend fun setSort(sort: TodoSort) {
        store.edit { it[Keys.sort] = sort.name }
    }

    /** Stores a new server/key pair and resets the cursor so the next sync is a full resync. */
    suspend fun connect(serverUrl: String, syncKey: String) {
        store.edit {
            it[Keys.serverUrl] = serverUrl
            it[Keys.syncKey] = syncKey
            it[Keys.cursor] = 0L
            it.remove(Keys.lastSyncAt)
            it.remove(Keys.lastSyncOk)
            it.remove(Keys.lastSyncMessage)
        }
    }

    suspend fun disconnect() {
        store.edit {
            it.remove(Keys.syncKey)
            it[Keys.cursor] = 0L
            it.remove(Keys.lastSyncAt)
            it.remove(Keys.lastSyncOk)
            it.remove(Keys.lastSyncMessage)
        }
    }

    override suspend fun config(): SyncConfig? {
        val s = settings.first()
        if (!s.isConnected) return null
        return SyncConfig(baseUrl = s.serverUrl, syncKey = s.syncKey, cursor = s.cursor)
    }

    override suspend fun saveCursor(cursor: Long) {
        store.edit { it[Keys.cursor] = cursor }
    }

    override suspend fun recordResult(at: Long, ok: Boolean, message: String?) {
        store.edit {
            if (ok) it[Keys.lastSyncAt] = at
            it[Keys.lastSyncOk] = ok
            if (message == null) it.remove(Keys.lastSyncMessage) else it[Keys.lastSyncMessage] = message
        }
    }
}
