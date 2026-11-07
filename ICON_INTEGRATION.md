# Icon Integration Guide

## Method 1: Using Icon Composer File (.icns)

If you have an `.icns` file from Icon Composer:

### Step 1: Add Icon to Xcode

1. **Open your project in Xcode**:
   ```bash
   open /Users/aslam/tempy/todo-widget/Tudu/Tudu.xcodeproj
   ```

2. **Add the icon file**:
   - Drag your `.icns` file into the `Tudu/Tudu/Assets.xcassets/AppIcon.appiconset` folder in Finder
   - Or in Xcode:
     - Click on `Assets.xcassets` in Project Navigator
     - Click on `AppIcon`
     - Drag your `.icns` file into the well labeled "Mac 512pt" or "1024pt"
     - Xcode will automatically extract all sizes

### Step 2: Verify Icon in Xcode

1. In Project Navigator, click on `Assets.xcassets`
2. Select `AppIcon`
3. You should see your icon in various sizes
4. If using a single `.icns` file, just drag it to the largest size slot

### Step 3: Build and Test

```bash
xcodebuild -project /Users/aslam/tempy/todo-widget/Tudu/Tudu.xcodeproj \
  -scheme Tudu \
  -configuration Release \
  clean build
```

The app should now have your custom icon!

---

## Method 2: Manual Icon Integration (Individual PNG files)

If you have individual PNG files at different sizes:

### Required Sizes for macOS App Icons:

- 16x16 (@1x and @2x = 32x32)
- 32x32 (@1x and @2x = 64x64)
- 128x128 (@1x and @2x = 256x256)
- 256x256 (@1x and @2x = 512x512)
- 512x512 (@1x and @2x = 1024x1024)

### Steps:

1. Open Xcode
2. Navigate to `Assets.xcassets` → `AppIcon`
3. Drag each PNG file to its corresponding size slot
4. Or replace the entire folder:
   - Delete the existing `AppIcon.appiconset` folder
   - Create an `.iconset` folder with your PNGs
   - Convert to `.icns`:
     ```bash
     iconutil -c icns YourIcon.iconset
     ```
   - Add the `.icns` file as described in Method 1

---

## Method 3: Quick Command Line Method

If you have an `.icns` file, you can copy it directly:

```bash
# Copy your icon file
cp /path/to/your/icon.icns /Users/aslam/tempy/todo-widget/Tudu/Tudu/Assets.xcassets/AppIcon.appiconset/AppIcon.icns

# Update the Contents.json
cat > /Users/aslam/tempy/todo-widget/Tudu/Tudu/Assets.xcassets/AppIcon.appiconset/Contents.json << 'EOF'
{
  "images" : [
    {
      "filename" : "AppIcon.icns",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
```

---

## Verify Icon Installation

After adding your icon:

1. **In Finder**:
   - Build your app
   - Navigate to the built `.app` file
   - You should see your custom icon

2. **Test the app**:
   ```bash
   # Build and run
   xcodebuild -project /Users/aslam/tempy/todo-widget/Tudu/Tudu.xcodeproj \
     -scheme Tudu \
     -configuration Release

   # Open the built app
   open /Users/aslam/Library/Developer/Xcode/DerivedData/Tudu-*/Build/Products/Release/Tudu.app
   ```

3. **Check the Dock**: When the app runs, it should show your custom icon in the Dock

---

## Troubleshooting

### Icon doesn't appear:

1. **Clean build folder**:
   - In Xcode: Product → Clean Build Folder (⌘⇧K)
   - Or delete derived data:
     ```bash
     rm -rf ~/Library/Developer/Xcode/DerivedData/Tudu-*
     ```

2. **Rebuild**:
   ```bash
   xcodebuild -project /Users/aslam/tempy/todo-widget/Tudu/Tudu.xcodeproj \
     -scheme Tudu \
     -configuration Release \
     clean build
   ```

3. **Reset icon cache** (macOS):
   ```bash
   sudo rm -rf /Library/Caches/com.apple.iconservices.store
   sudo find /private/var/folders/ -name com.apple.iconservices -exec rm -rf {} \;
   killall Dock
   killall Finder
   ```

### Icon looks blurry:

- Make sure you're providing high-resolution versions
- The 1024x1024 (@2x of 512x512) is especially important for Retina displays
- Use PNG files with transparency, not JPEG

### Icon has white background:

- Use PNG files with alpha channel (transparency)
- Icon Composer should preserve transparency
- If using command line tools, ensure alpha channel is preserved

---

## Next Steps

After integrating your icon:
1. Build a release version
2. Archive and export the app
3. Create a DMG or ZIP for distribution
4. Publish to Homebrew (see HOMEBREW_PUBLISHING.md)
