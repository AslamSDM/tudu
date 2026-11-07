package com.tudu.app.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardOptions
import com.journeyapps.barcodescanner.ScanContract
import com.journeyapps.barcodescanner.ScanOptions
import com.tudu.app.DEFAULT_SERVER_URL
import com.tudu.app.sync.SyncKey
import com.tudu.app.sync.SyncLink
import com.tudu.app.ui.theme.LocalTuduColors
import androidx.activity.compose.rememberLauncherForActivityResult
import java.text.DateFormat
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    onBack: () -> Unit,
    onScannedLink: (SyncLink) -> Unit,
) {
    val context = LocalContext.current
    val settings by viewModel.settings.collectAsState()
    val busy by viewModel.busy.collectAsState()
    val snackbar = remember { SnackbarHostState() }

    var url by rememberSaveable { mutableStateOf<String?>(null) }
    var key by rememberSaveable { mutableStateOf<String?>(null) }
    var showKey by rememberSaveable { mutableStateOf(false) }
    var confirmDisconnect by remember { mutableStateOf(false) }

    // Fill the fields from storage once, then keep them in sync after connect/disconnect.
    LaunchedEffect(settings?.serverUrl, settings?.syncKey) {
        settings?.let {
            url = it.serverUrl
            key = it.syncKey
        }
    }
    LaunchedEffect(Unit) { viewModel.messages.collect { snackbar.showSnackbar(it) } }

    val scanLauncher = rememberLauncherForActivityResult(ScanContract()) { result ->
        val contents = result.contents ?: return@rememberLauncherForActivityResult
        val link = SyncLink.parse(contents)
        if (link != null) onScannedLink(link) else showToast(context, "That QR code is not a Tudu sync code")
    }

    val urlValue = url.orEmpty()
    val keyValue = key.orEmpty()
    val connected = settings?.isConnected == true
    val unchanged = connected && urlValue.trim().trimEnd('/') == settings?.serverUrl && keyValue.trim() == settings?.syncKey
    val keyValid = SyncKey.isValid(keyValue.trim())

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") } },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            StatusCard(settings = settings, busy = busy)

            SettingsCard(title = "Server") {
                OutlinedTextField(
                    value = urlValue,
                    onValueChange = { url = it },
                    label = { Text("Server URL") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                    modifier = Modifier.fillMaxWidth(),
                )
                if (urlValue.trim().trimEnd('/') != DEFAULT_SERVER_URL) {
                    TextButton(onClick = { url = DEFAULT_SERVER_URL }) { Text("Use default server") }
                }
            }

            SettingsCard(title = "Sync key") {
                Text(
                    "Use the same key on every device. Anyone with the key can read and change your tasks.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = keyValue,
                    onValueChange = { key = it },
                    label = { Text("Sync key") },
                    singleLine = true,
                    isError = keyValue.isNotBlank() && !keyValid,
                    supportingText = if (keyValue.isNotBlank() && !keyValid) {
                        { Text("At least 32 characters: A–Z, a–z, 0–9, - and _") }
                    } else {
                        null
                    },
                    textStyle = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                    visualTransformation = if (showKey) VisualTransformation.None else PasswordVisualTransformation(),
                    trailingIcon = {
                        IconButton(onClick = { showKey = !showKey }) {
                            Icon(if (showKey) Icons.Default.VisibilityOff else Icons.Default.Visibility, if (showKey) "Hide key" else "Show key")
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                )
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    FilledTonalButton(onClick = {
                        val pasted = readClipboard(context)?.trim()
                        val link = pasted?.let(SyncLink::parse)
                        when {
                            link != null -> onScannedLink(link)
                            pasted.isNullOrEmpty() -> showToast(context, "Clipboard is empty")
                            else -> key = pasted
                        }
                    }) { ButtonContent(Icons.Default.ContentPaste, "Paste key") }
                    FilledTonalButton(onClick = {
                        key = SyncKey.generate()
                        showKey = true
                    }) { ButtonContent(Icons.Default.AutoAwesome, "Generate new key") }
                    FilledTonalButton(onClick = {
                        scanLauncher.launch(
                            ScanOptions()
                                .setDesiredBarcodeFormats(ScanOptions.QR_CODE)
                                .setPrompt("Scan the Tudu sync QR code")
                                .setBeepEnabled(false)
                                .setOrientationLocked(false),
                        )
                    }) { ButtonContent(Icons.Default.QrCodeScanner, "Scan QR") }
                    if (connected) {
                        FilledTonalButton(onClick = {
                            val s = settings ?: return@FilledTonalButton
                            copyToClipboard(context, SyncLink(s.serverUrl, s.syncKey).toUri())
                            showToast(context, "Sync link copied")
                        }) { ButtonContent(Icons.Default.ContentCopy, "Copy sync link") }
                    }
                }
            }

            if (unchanged) {
                Button(onClick = viewModel::syncNow, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                    ButtonContent(Icons.Default.Sync, "Sync now")
                }
            } else {
                Button(
                    onClick = { viewModel.connect(urlValue, keyValue) },
                    enabled = !busy && keyValid && urlValue.isNotBlank(),
                    modifier = Modifier.fillMaxWidth(),
                ) { ButtonContent(Icons.Default.Sync, if (connected) "Save & sync" else "Connect & sync") }
            }

            if (connected) {
                OutlinedButton(
                    onClick = { confirmDisconnect = true },
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                    modifier = Modifier.fillMaxWidth(),
                ) { ButtonContent(Icons.Default.CloudOff, "Disconnect") }
            }
        }
    }

    if (confirmDisconnect) {
        AlertDialog(
            onDismissRequest = { confirmDisconnect = false },
            title = { Text("Disconnect sync?") },
            text = { Text("This device stops syncing and forgets the key. Your tasks stay on this device. Save the key first if you have no other device with it.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDisconnect = false
                    viewModel.disconnect()
                }) { Text("Disconnect", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { confirmDisconnect = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun StatusCard(settings: com.tudu.app.data.SyncSettings?, busy: Boolean) {
    val colors = LocalTuduColors.current
    val connected = settings?.isConnected == true
    val failed = settings?.lastSyncOk == false
    val (icon, title) = when {
        !connected -> Icons.Default.CloudOff to "Sync is off"
        failed -> Icons.Default.ErrorOutline to "Last sync failed"
        else -> Icons.Default.CloudDone to "Connected"
    }
    val detail = when {
        !connected -> "Tasks are saved on this device only. Connect with a sync key to share them with your Mac."
        failed -> settings.lastSyncMessage ?: "Unknown error"
        else -> settings.lastSyncAt?.let {
            "Last synced ${relativeTime(it)} · ${DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(it))}"
        } ?: "Not synced yet"
    }
    val tint = when {
        !connected -> MaterialTheme.colorScheme.onSurfaceVariant
        failed -> colors.danger
        else -> colors.success
    }
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
            if (busy) {
                CircularProgressIndicator(Modifier.size(28.dp), strokeWidth = 3.dp)
            } else {
                Icon(icon, null, tint = tint, modifier = Modifier.size(28.dp))
            }
            Spacer(Modifier.size(16.dp))
            Column {
                Text(if (busy) "Syncing…" else title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.8f))
            }
        }
    }
}

@Composable
private fun SettingsCard(title: String, content: @Composable () -> Unit) {
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            content()
        }
    }
}

@Composable
private fun ButtonContent(icon: ImageVector, text: String) {
    Icon(icon, null, Modifier.size(18.dp))
    Spacer(Modifier.size(8.dp))
    Text(text)
}

private fun readClipboard(context: Context): String? {
    val clipboard = context.getSystemService(ClipboardManager::class.java) ?: return null
    val clip = clipboard.primaryClip ?: return null
    if (clip.itemCount == 0) return null
    return clip.getItemAt(0).coerceToText(context)?.toString()
}

private fun copyToClipboard(context: Context, text: String) {
    val clip = ClipData.newPlainText("Tudu sync link", text)
    // The link contains the sync key: keep it out of clipboard previews.
    clip.description.extras = android.os.PersistableBundle().apply {
        putBoolean("android.content.extra.IS_SENSITIVE", true)
    }
    context.getSystemService(ClipboardManager::class.java)?.setPrimaryClip(clip)
}

private fun showToast(context: Context, text: String) {
    android.widget.Toast.makeText(context, text, android.widget.Toast.LENGTH_SHORT).show()
}
