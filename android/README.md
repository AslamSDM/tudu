# Tudu for Android

Native Android client for Tudu. It syncs with the macOS app through the Cloudflare Worker
described in [`../docs/SYNC_API.md`](../docs/SYNC_API.md).

- Kotlin, Jetpack Compose + Material 3 (dynamic color, light/dark)
- Room (todos + tombstones + a `pending` flag), DataStore (server URL, sync key, cursor, last sync)
- OkHttp + kotlinx.serialization for `POST /v1/sync`
- WorkManager: a periodic sync every 15 minutes, an expedited one-off after each local change and on app foreground. Pull-to-refresh and "Sync now" also sync.
- Jetpack Glance home-screen widget
- Package `com.tudu.app`, minSdk 26, target/compile SDK 36

## Build

You need JDK 17+ (the JBR bundled with Android Studio works) and the Android SDK (platform 36).

```sh
cd android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties   # only if missing
./gradlew assembleDebug          # → app/build/outputs/apk/debug/app-debug.apk
./gradlew testDebugUnitTest      # unit tests (merge/LWW, sync engine, wire format, sort/filter)
```

You can also open the `android/` folder in Android Studio.

## Install

Enable USB debugging on the phone (or start an emulator), then:

```sh
adb devices
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.tudu.app/.MainActivity
```

## Connect sync

The default server is `DEFAULT_SERVER_URL` in
`app/src/main/java/com/tudu/app/Config.kt`. You can change it per device in Settings.

1. Open Tudu → ⋮ → **Settings & sync**.
2. Choose one way to get the key:
   - **First device:** tap **Generate new key**, then **Connect & sync**. Copy the key (or tap **Copy sync link**) to your other devices.
   - **Join an existing space:** tap **Scan QR** and scan the QR code from the Mac app, or **Paste key** (a pasted `tudu://sync?...` link also works).
   - **Deep link:** opening `tudu://sync?url=<urlencoded base URL>&key=<syncKey>` asks you to confirm, then connects. Test it with:
     ```sh
     adb shell am start -a android.intent.action.VIEW \
       -d "'tudu://sync?url=https%3A%2F%2Ftudu-sync.aslamprpd.workers.dev&key=<KEY>'"
     ```
3. Connecting resets the cursor to 0 and marks every local task as pending, so local tasks merge into the space (last write wins).
4. **Disconnect** stops syncing and forgets the key. Tasks stay on the device.

The status card shows the last successful sync time or the last error.

## Widget

Long-press the home screen → Widgets → **Tudu tasks**. It shows pending tasks sorted by due date. Overdue labels are orange.
- Tick a checkbox to complete the task. This writes to Room, marks the task pending, enqueues a sync, and refreshes the widget.
- **+** opens the app with the quick-add field focused.

The widget refreshes after every local change and after every sync that changed data.

## Layout

```
app/src/main/java/com/tudu/app/
  Config.kt            DEFAULT_SERVER_URL
  TuduApp.kt           Application + AppContainer (manual DI), foreground sync
  MainActivity.kt      deep link + widget quick-add intents
  data/                Room entity/DAO/DB, DataStore settings, TodoRepository (all local writes)
  domain/TodoLogic.kt  filter/sort/overdue/due labels (mirrors SharedModels.swift)
  sync/                Wire DTOs, SyncMerge (pure LWW), SyncEngine, SyncApi (OkHttp),
                       RoomSyncStore, SyncWorker + SyncScheduler, SyncKey/SyncLink
  ui/                  Compose screens: list, editor sheet, settings
  widget/TuduWidget.kt Glance widget, toggle action, receiver
```

## Notes

- Tombstones are never purged on the device.
- Debug builds are unsigned for release. Add a signing config before you publish a release build.
