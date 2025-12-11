# Widget Setup Checklist - Fix Build Errors

## Files Structure

You now have 3 files:
1. **SharedModels.swift** - Contains the `Todo` struct (shared between app and widget)
2. **TuduApp.swift** - Your main app
3. **TuduWidget.swift** - Your widget

## Step-by-Step Setup

### 1. Configure Target Membership

#### SharedModels.swift
1. Select `SharedModels.swift` in Project Navigator
2. Open File Inspector (⌘⌥1)
3. Under **Target Membership**, check:
   - ✅ Tudu (main app)
   - ✅ TuduWidget (widget extension)

#### TuduApp.swift  
1. Select `TuduApp.swift` in Project Navigator
2. Open File Inspector (⌘⌥1)
3. Under **Target Membership**, check:
   - ✅ Tudu (main app)
   - ⬜ TuduWidget (UNCHECK this - not needed)

#### TuduWidget.swift
1. Select `TuduWidget.swift` in Project Navigator
2. Open File Inspector (⌘⌥1)
3. Under **Target Membership**, check:
   - ⬜ Tudu (UNCHECK - not needed)
   - ✅ TuduWidget (widget extension only)

### 2. Configure App Groups

#### For Main App (Tudu target):
1. Select your project in Navigator
2. Select **Tudu** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** → Add **App Groups**
5. Click **+** button and add: `group.com.example.todowidget`
6. Make sure the checkbox next to it is CHECKED ✅

#### For Widget Extension (TuduWidget target):
1. Stay in the same project settings
2. Select **TuduWidget** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** → Add **App Groups**
5. Click **+** and add the SAME: `group.com.example.todowidget`
6. Make sure the checkbox next to it is CHECKED ✅

### 3. Clean and Rebuild

1. Clean Build Folder: **Product → Clean Build Folder** (⌘⇧K)
2. Close Xcode
3. Reopen Xcode
4. Build the **Tudu** scheme first (⌘B)
5. Then build the **TuduWidget** scheme

## Common Build Errors & Fixes

### Error: "Cannot find 'Todo' in scope"
**In TuduWidget.swift:**
- ✅ Make sure `SharedModels.swift` is checked for TuduWidget target

### Error: "Cannot find 'TodoDataManager' in scope"
**In TuduWidget.swift:**
- This is expected! The widget doesn't use TodoDataManager anymore
- It uses `SharedTodoData.loadTodos()` instead
- Make sure SharedModels.swift has both targets checked

### Error: "Value of type 'Todo' has no member 'isCompleted'"
**This means the widget is seeing the wrong Todo struct:**
- Make sure SharedModels.swift is checked for TuduWidget target
- Clean build folder and rebuild

### Error: "Cannot convert value of type 'NSApplicationDelegate' to expected type..."
**This is about the main app, not the widget:**
- This error is in TuduApp.swift
- Make sure TuduApp.swift is NOT checked for TuduWidget target

### Error: Something about "@main"
**You have two @main entry points:**
- TuduApp.swift has `@main struct TuduApp`
- TuduWidget.swift has `@main struct TuduWidget`
- This is correct! Each target needs its own @main
- But make sure they're in the right targets:
  - TuduApp.swift → Only Tudu target
  - TuduWidget.swift → Only TuduWidget target

### Error: "Unsupported platform"
**Your widget might be trying to build for the wrong platform:**
1. Select TuduWidget target
2. Go to **General** tab
3. Under **Supported Destinations**, make sure only **macOS** is checked

## Verify Everything

Run this checklist:

- [ ] SharedModels.swift exists and has both targets checked
- [ ] TuduApp.swift only has Tudu target checked
- [ ] TuduWidget.swift only has TuduWidget target checked
- [ ] Both targets have the same App Group: `group.com.example.todowidget`
- [ ] App Group is enabled (checkbox checked) in both targets
- [ ] Clean build completed (⌘⇧K)
- [ ] Main app builds successfully
- [ ] Widget builds successfully

## Test the Widget

Once it builds:

1. **Run the main app first:**
   - Select **Tudu** scheme
   - Click Run (⌘R)
   - Add some todos
   - Close the app

2. **Run the widget:**
   - Select **TuduWidget** scheme
   - Click Run (⌘R)
   - Choose a widget size
   - The widget should show your todos!

## Still Having Issues?

If you're still getting build errors, please copy and paste the **exact error message** from Xcode. Look in:
- The issue navigator (⌘5)
- The build log (⌘9, then click the build)

The error message will tell us exactly what's wrong!
