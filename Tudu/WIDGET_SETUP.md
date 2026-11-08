# Tudu Widget Setup & Testing Guide

## 📋 Setup Instructions

### Step 1: Create Widget Extension Target

1. In Xcode, go to **File → New → Target**
2. Select **Widget Extension**
3. Name it: `TuduWidget`
4. Uncheck "Include Configuration Intent"
5. Click **Finish**
6. When prompted about activating the scheme, click **Activate**

### Step 2: Add Widget File

1. The `TuduWidget.swift` file has been created for you
2. Make sure it's added to your **TuduWidget** target (not the main app target)
3. Check the target membership in the File Inspector (right panel)

### Step 3: Configure App Groups (IMPORTANT!)

This allows the widget and main app to share data.

#### For Main App Target:
1. Select your project in the navigator
2. Select the **Tudu** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **App Groups**
6. Click **+** and create: `group.com.Tudu`
   - Or use your own bundle ID pattern like `group.com.yourcompany.tudu`
7. Make sure it's checked

#### For Widget Target:
1. Select the **TuduWidget** target
2. Repeat steps 3-7 above
3. Use the **exact same** App Group name

### Step 4: Share Todo Model with Widget

1. Select `TuduApp.swift` in the Project Navigator
2. Open the **File Inspector** (⌘⌥1)
3. Under **Target Membership**, check both:
   - ✅ Tudu
   - ✅ TuduWidget

This makes the `Todo` struct and `TodoDataManager` available to the widget.

### Step 5: Update Bundle Identifier

Make sure your widget extension has a proper bundle ID:
1. Select **TuduWidget** target
2. Go to **General** tab
3. Bundle Identifier should be: `com.example.Tudu.TuduWidget`
   - Replace `com.example` with your actual bundle prefix

---

## 🧪 Testing the Widget

### Method 1: Run Widget in Xcode (Recommended for Development)

1. In Xcode's scheme selector (top-left), select **TuduWidget** scheme
2. Choose your device/simulator
3. Click **Run** (⌘R)
4. Xcode will prompt you to choose a widget configuration:
   - Select **Small**, **Medium**, or **Large**
   - Click **Run**
5. The widget will appear on your home screen/notification center

### Method 2: Add Widget Manually (Real-World Testing)

1. First, run your **main app** (Tudu scheme) to create some test data
2. Add a few todos
3. Stop the app
4. On macOS:
   - Open **Notification Center** (click time in menu bar)
   - Scroll to bottom and click **Edit Widgets**
   - Search for "Tudu"
   - Drag your widget to the notification center
5. On iOS (if you port this):
   - Long-press on home screen
   - Tap **+** button
   - Search "Tudu"
   - Select widget size and add

### Method 3: Xcode Previews (Fastest for UI Iteration)

1. Open `TuduWidget.swift`
2. Click **Resume** in the preview canvas (⌘⌥↩)
3. You'll see all three widget sizes with sample data
4. Make UI changes and see them update in real-time

---

## 🐛 Troubleshooting

### Widget Shows "Unable to Load"

**Cause:** App Groups not configured correctly

**Fix:**
1. Verify both targets have the same App Group name
2. Make sure the group is **checked** in both targets
3. Clean build folder (⌘⇧K)
4. Rebuild (⌘B)

### Widget Shows Old Data

**Cause:** Widget not refreshing

**Fix:**
1. Make sure `WidgetKit` is imported in `TuduApp.swift`
2. Check that `WidgetCenter.shared.reloadAllTimelines()` is in `saveTodos()`
3. Force refresh: Long-press widget → **Refresh**

### "Todo not found" or Build Errors

**Cause:** `Todo` struct not available to widget target

**Fix:**
1. Select `TuduApp.swift`
2. File Inspector → Target Membership
3. Check both **Tudu** and **TuduWidget**

### Widget Doesn't Appear in Widget Gallery

**Cause:** Bundle ID or Info.plist issue

**Fix:**
1. Check TuduWidget target's Bundle ID ends with `.TuduWidget`
2. Clean build folder (⌘⇧K)
3. Delete derived data: Xcode → Preferences → Locations → Derived Data → Delete
4. Rebuild

---

## 📱 Widget Features

### Small Widget
- Shows pending task count and progress
- Displays next task to do, with a checkbox

### Medium Widget
- Shows pending count and progress
- Shows up to 4 tasks with checkboxes

### Large Widget
- Shows up to 8 tasks with checkboxes
- Shows stats (To do, Overdue, Done)

### Extra Large Widget
- Shows up to 18 tasks in two columns
- Shows stats (To do, Overdue, Done)

Right-click a widget and choose **Edit "Tudu"** to pick All Tasks, Today, or High Priority, and whether completed tasks appear.

---

## 🔄 Widget Updates

The widget automatically refreshes:
- **Every 15 minutes** (system timeline)
- **When you add/edit/delete** a todo in the main app
- **On-demand** when you long-press and select "Refresh"

---

## 🎨 Customization Tips

### Change Update Frequency

In `TuduWidget.swift`, find this line in `getTimeline`:
```swift
let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
```

Change `15` to your desired minutes (note: iOS may limit how often widgets update to save battery).

### Add Deep Links

To open your app when tapping the widget, wrap views in:
```swift
Link(destination: URL(string: "tudu://open")!) {
    // Your widget content
}
```

Then add URL scheme handling in your app.

### Change Colors

Modify the color schemes in each widget view:
- `.blue` - Change to your brand color
- `.orange` - Pending task color
- `.green` - Completed task color

---

## ✅ Testing Checklist

- [ ] Widget extension target created
- [ ] App Groups configured for both targets
- [ ] Same App Group name used in both
- [ ] TuduApp.swift added to both target memberships
- [ ] Widget builds without errors
- [ ] Widget appears in Xcode preview
- [ ] Widget runs in simulator/device
- [ ] Adding todo in main app updates widget
- [ ] All three widget sizes work (small, medium, large)
- [ ] Widget shows correct data

---

## 📝 Next Steps

Once your widget is working:

1. **Add Interactive Elements** (iOS 17+)
   - Use `Button` and `Toggle` in widgets
   - Mark todos as complete directly from widget

2. **Add Configuration**
   - Let users choose which list to display
   - Filter by completed/pending

3. **Improve Design**
   - Add gradients
   - Use SF Symbols Pro icons
   - Add animations

4. **Test on Real Device**
   - Battery impact
   - Update reliability
   - User experience

Happy coding! 🚀
