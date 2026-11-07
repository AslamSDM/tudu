package com.tudu.app.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.tudu.app.AppContainer
import com.tudu.app.data.SyncSettings
import com.tudu.app.data.TodoEntity
import com.tudu.app.domain.TodoFilter
import com.tudu.app.domain.TodoLogic
import com.tudu.app.domain.TodoSort
import com.tudu.app.sync.SyncResult
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class TodoStats(val total: Int, val completed: Int, val overdue: Int, val dueToday: Int) {
    val progress: Float get() = if (total == 0) 0f else completed.toFloat() / total
}

data class TodoListUiState(
    val loaded: Boolean = false,
    val pending: List<TodoEntity> = emptyList(),
    val completed: List<TodoEntity> = emptyList(),
    val allTags: List<String> = emptyList(),
    val stats: TodoStats = TodoStats(0, 0, 0, 0),
    val filter: TodoFilter = TodoFilter.ALL,
    val sort: TodoSort = TodoSort.CREATED,
    val search: String = "",
    val tag: String? = null,
) {
    val isEmpty: Boolean get() = pending.isEmpty() && completed.isEmpty()
    val hasCompleted: Boolean get() = stats.completed > 0
}

private data class Query(val filter: TodoFilter, val search: String, val tag: String?, val sort: TodoSort)

sealed interface ListMessage {
    data class Deleted(val todo: TodoEntity) : ListMessage
    data class Toggled(val todo: TodoEntity, val nowCompleted: Boolean) : ListMessage
    data class Info(val text: String) : ListMessage
}

class TodoListViewModel(private val container: AppContainer) : ViewModel() {
    private val repository = container.repository
    private val filter = MutableStateFlow(TodoFilter.ALL)
    private val search = MutableStateFlow("")
    private val tag = MutableStateFlow<String?>(null)

    private val query = combine(filter, search, tag, container.settings.sort) { f, s, t, sort -> Query(f, s, t, sort) }

    val state: StateFlow<TodoListUiState> = combine(repository.todos, query) { todos, q ->
        val now = System.currentTimeMillis()
        val allTags = TodoLogic.allTags(todos)
        val activeTag = q.tag?.takeIf { t -> allTags.any { it.equals(t, ignoreCase = true) } }
        val visible = todos.filter { todo ->
            TodoLogic.matchesSearch(todo, q.search) &&
                TodoLogic.hasTag(todo, activeTag) &&
                when (q.filter) {
                    TodoFilter.ALL -> true
                    TodoFilter.ACTIVE -> !todo.isCompleted
                    TodoFilter.COMPLETED -> todo.isCompleted
                }
        }
        TodoListUiState(
            loaded = true,
            pending = q.sort.sorted(visible.filter { !it.isCompleted }),
            completed = TodoSort.sortCompleted(visible.filter { it.isCompleted }),
            allTags = allTags,
            stats = TodoStats(
                total = todos.size,
                completed = todos.count { it.isCompleted },
                overdue = todos.count { TodoLogic.isOverdue(it, now) },
                dueToday = todos.count { TodoLogic.isDueToday(it, now) },
            ),
            filter = q.filter,
            sort = q.sort,
            search = q.search,
            tag = activeTag,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TodoListUiState())

    val syncSettings: StateFlow<SyncSettings?> =
        container.settings.settings.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    private val _refreshing = MutableStateFlow(false)
    val refreshing: StateFlow<Boolean> = _refreshing.asStateFlow()

    private val _messages = Channel<ListMessage>(Channel.BUFFERED)
    val messages = _messages.receiveAsFlow()

    fun setFilter(value: TodoFilter) { filter.value = value }
    fun setSearch(value: String) { search.value = value }
    fun setTag(value: String?) { tag.value = value }
    fun setSort(value: TodoSort) { viewModelScope.launch { container.settings.setSort(value) } }

    fun add(title: String) {
        viewModelScope.launch { repository.add(title) }
    }

    fun setCompleted(todo: TodoEntity, completed: Boolean, announce: Boolean = false) {
        viewModelScope.launch {
            repository.setCompleted(todo.id, completed)
            if (announce) _messages.send(ListMessage.Toggled(todo, completed))
        }
    }

    fun delete(todo: TodoEntity) {
        viewModelScope.launch {
            repository.delete(todo.id)
            _messages.send(ListMessage.Deleted(todo))
        }
    }

    fun restore(todo: TodoEntity) {
        viewModelScope.launch { repository.restore(todo.id) }
    }

    fun save(todo: TodoEntity) {
        viewModelScope.launch { repository.save(todo) }
    }

    fun clearCompleted() {
        viewModelScope.launch {
            val done = state.value.let { it.stats.completed }
            repositoryCompleted().forEach { repository.delete(it.id) }
            _messages.send(ListMessage.Info("Deleted $done completed task${if (done == 1) "" else "s"}"))
        }
    }

    private suspend fun repositoryCompleted(): List<TodoEntity> =
        repository.todos.first().filter { it.isCompleted }

    fun refresh() {
        if (_refreshing.value) return
        viewModelScope.launch {
            _refreshing.value = true
            val result = container.syncEngine.sync()
            _refreshing.value = false
            when (result) {
                is SyncResult.Failure -> _messages.send(ListMessage.Info(result.message))
                SyncResult.NotConfigured -> _messages.send(ListMessage.Info("Sync is not set up. Open Settings to connect."))
                is SyncResult.Success -> Unit
            }
        }
    }
}
