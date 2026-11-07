package com.tudu.app

import android.app.Application
import android.content.Context
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.tudu.app.data.AppDatabase
import com.tudu.app.data.SettingsStore
import com.tudu.app.data.TodoRepository
import com.tudu.app.sync.RoomSyncStore
import com.tudu.app.sync.SyncApi
import com.tudu.app.sync.SyncEngine
import com.tudu.app.sync.SyncResult
import com.tudu.app.sync.SyncScheduler
import com.tudu.app.widget.WidgetUpdater
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Manual dependency container, shared by the UI, the worker, and the widget. */
class AppContainer(context: Context) {
    private val appContext = context.applicationContext
    val database: AppDatabase = AppDatabase.build(appContext)
    val settings = SettingsStore(appContext)
    val api = SyncApi()
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    val syncEngine = SyncEngine(
        local = RoomSyncStore(database),
        state = settings,
        transport = api,
        onDataChanged = { WidgetUpdater.refresh(appContext) },
    )

    val repository = TodoRepository(
        dao = database.todoDao(),
        onLocalChange = {
            SyncScheduler.syncSoon(appContext)
            WidgetUpdater.refresh(appContext)
        },
    )

    /** Saves a new server/key, re-uploads every local record, and syncs. */
    suspend fun connect(serverUrl: String, syncKey: String): SyncResult {
        settings.connect(SyncApi.normalizeBaseUrl(serverUrl), syncKey.trim())
        repository.markAllPending()
        SyncScheduler.schedulePeriodic(appContext)
        return syncEngine.sync()
    }

    suspend fun disconnect() {
        SyncScheduler.cancelAll(appContext)
        settings.disconnect()
    }
}

class TuduApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        SyncScheduler.schedulePeriodic(this)
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                SyncScheduler.syncSoon(this@TuduApp)
            }
        })
        container.scope.launch { WidgetUpdater.refresh(this@TuduApp) }
    }

    companion object {
        fun container(context: Context): AppContainer = (context.applicationContext as TuduApp).container
    }
}
