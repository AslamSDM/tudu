# How to Set Up Your Tudu Widget

Your todo app code is ready! Now you need to set up the widget extension target in Xcode.

## Current Status

✅ Fixed duplicate `Todo` struct definitions
✅ Removed redundant files
✅ All code is ready for the widget
⚠️ Widget extension target needs to be created in Xcode

## Step-by-Step Setup

### Step 1: Open the Project in Xcode

```bash
open /Users/aslam/tempy/todo-widget/Tudu/Tudu.xcodeproj
```

### Step 2: Create Widget Extension Target

1. In Xcode, go to **File → New → Target**
2. Search for and select **Widget Extension**
3. Click **Next**
4. Configure the target:
   - **Product Name**: `TuduWidget`
   - **Include Configuration Intent**: **UNCHECK** this box
5. Click **Finish**
6. When prompted "Activate TuduWidget scheme?", click **Activate**

### Step 3: Replace Widget Files

The widget extension will create default files. You need to replace them with your custom files:

1. **Delete the generated widget file**:
   - In the Project Navigator, find the new `TuduWidget` folder
   - Delete the auto-generated widget file (usually named `TuduWidget.swift`)
   - Click "Move to Trash" when prompted

2. **Add your widget files**:
   - Find `TuduWidget.swift` and `TuduWidgetBundle.swift` in the `Tudu` folder
   - Select both files
   - In the File Inspector (right panel), under **Target Membership**:
     - ✅ Check **TuduWidget** (widget extension)
     - ⬜ **UNCHECK** Tudu (main app)

3. **Add SharedModels.swift to both targets**:
   - Select `SharedModels.swift`
   - In the File Inspector, under **Target Membership**:
     - ✅ Check **Tudu** (main app)
     - ✅ Check **TuduWidget** (widget extension)

### Step 4: Configure App Groups

This allows the app and widget to share data:

#### For Main App:
1. Select the **Tudu** target in the project settings
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and add: `group.com.Tudu`
6. Make sure it's checked ✅

#### For Widget Extension:
1. Select the **TuduWidget** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** and add the **exact same**: `group.com.Tudu`
6. Make sure it's checked ✅

### Step 5: Update Bundle Identifiers (Important!)

1. Select **TuduWidget** target
2. Go to **General** tab
3. Update **Bundle Identifier** to match your app's pattern:
   - If your main app is `com.yourname.Tudu`
   - Widget should be `com.yourname.Tudu.TuduWidget`

### Step 6: Clean and Build

1. **Product → Clean Build Folder** (⌘⇧K)
2. Close Xcode
3. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Tudu-*
   ```
4. Reopen Xcode
5. Build the **Tudu** scheme (⌘B)
6. Build the **TuduWidget** scheme

## Testing Your Widget

### Run the Main App First:
1. Select **Tudu** scheme (top-left in Xcode)
2. Click **Run** (⌘R)
3. Add some todos to test with
4. Stop the app

### Run the Widget:
1. Select **TuduWidget** scheme
2. Click **Run** (⌘R)
3. Xcode will ask you to choose a widget size:
   - Select **Small**, **Medium**, or **Large**
4. Click **Run**
5. The widget preview will appear!

## Adding Widget to macOS

1. Run your main app and add some todos
2. Open **Notification Center** (click the date/time in menu bar)
3. Scroll to bottom and click **Edit Widgets**
4. Search for "Tudu"
5. Drag your widget to add it
6. Choose the size you want

## Widget Features

- **Small Widget**: Shows pending task count and next task
- **Medium Widget**: Shows up to 4 tasks with checkmarks
- **Large Widget**: Shows up to 9 tasks, separated by pending/completed

The widget updates:
- Every 15 minutes automatically
- Immediately when you add/edit/delete todos in the main app
- On-demand when you refresh

## Troubleshooting

### "Cannot find 'Todo' in scope" error in widget
- Make sure `SharedModels.swift` has both targets checked (Tudu + TuduWidget)

### "Two @main attributes" error
- Make sure `TuduWidget.swift` and `TuduWidgetBundle.swift` are **ONLY** in TuduWidget target
- Make sure they're **NOT** in the Tudu (main app) target

### Widget shows "Unable to Load"
- Verify both targets have the **same** App Group name
- Clean build and rebuild

### Widget doesn't appear in widget gallery
- Check bundle identifier format
- Clean derived data and rebuild

## Next Steps

Once your widget is working, you can:
- Customize colors and styling
- Adjust the update frequency
- Add deep links to open the app from the widget
- Add more widget sizes or configurations

Need help? Check the error messages in Xcode's Issue Navigator (⌘5) for specific guidance!
