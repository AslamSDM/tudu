# Publishing Tudu to Homebrew

This guide will help you publish your Tudu app to Homebrew so users can install it with `brew install tudu`.

---

## Prerequisites

1. **GitHub Account**: You need a GitHub account to host your app
2. **Release Build**: A signed, release version of your app
3. **Homebrew Installed**: Install if needed: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

---

## Step 1: Prepare Your App for Release

### 1.1 Build Release Version

```bash
cd /Users/aslam/tempy/todo-widget/Tudu

# Build release version
xcodebuild -project Tudu.xcodeproj \
  -scheme Tudu \
  -configuration Release \
  -derivedDataPath ./build \
  clean build

# Find the built app
find ./build/Build/Products/Release -name "Tudu.app"
```

### 1.2 Archive and Export

**Option A: Using Xcode (Recommended)**

1. Open Xcode: `open Tudu.xcodeproj`
2. Select **Tudu** scheme
3. Product → Archive
4. Click **Distribute App**
5. Choose **Copy App**
6. Save to a location (e.g., `~/Desktop/Tudu.app`)

**Option B: Command Line**

```bash
# Archive
xcodebuild -project Tudu.xcodeproj \
  -scheme Tudu \
  -configuration Release \
  -archivePath ./Tudu.xcarchive \
  archive

# Export
xcodebuild -exportArchive \
  -archivePath ./Tudu.xcarchive \
  -exportPath ./Release \
  -exportOptionsPlist exportOptions.plist
```

### 1.3 Create Distribution Package

Create a ZIP file for distribution:

```bash
# Navigate to where your Tudu.app is
cd /path/to/your/Tudu.app/parent/directory

# Create ZIP
ditto -c -k --sequesterRsrc --keepParent Tudu.app Tudu.zip

# Get SHA256 (you'll need this later)
shasum -a 256 Tudu.zip
```

---

## Step 2: Host Your App on GitHub

### 2.1 Create a GitHub Repository

```bash
cd /Users/aslam/tempy/todo-widget/Tudu

# Initialize git if not already done
git init
git add .
git commit -m "Initial commit of Tudu app"

# Create repo on GitHub (use gh CLI or web interface)
gh repo create tudu --public --source=. --remote=origin --push
```

Or manually:
1. Go to https://github.com/new
2. Create a new repository called `tudu`
3. Follow the instructions to push your code

### 2.2 Create a GitHub Release

```bash
# Tag your release
git tag -a v1.0.0 -m "Version 1.0.0 - Initial release"
git push origin v1.0.0

# Create release and upload ZIP (using gh CLI)
gh release create v1.0.0 \
  --title "Tudu v1.0.0" \
  --notes "Initial release of Tudu - A beautiful todo app with widget support for macOS" \
  Tudu.zip
```

Or manually:
1. Go to your repo on GitHub
2. Click **Releases** → **Create a new release**
3. Tag: `v1.0.0`
4. Title: `Tudu v1.0.0`
5. Description: Write release notes
6. Attach `Tudu.zip`
7. Click **Publish release**

### 2.3 Get the Download URL

After creating the release:
```bash
# Get the download URL (it will be something like):
# https://github.com/YOUR_USERNAME/tudu/releases/download/v1.0.0/Tudu.zip

# Calculate SHA256 of the uploaded file
curl -L https://github.com/YOUR_USERNAME/tudu/releases/download/v1.0.0/Tudu.zip | shasum -a 256
```

---

## Step 3: Create Homebrew Cask Formula

### 3.1 Create Your Homebrew Tap (Recommended for First-Time Publishers)

A "tap" is your own Homebrew repository:

```bash
# Create a new repo on GitHub called homebrew-tudu
gh repo create homebrew-tudu --public

# Clone it locally
cd ~/
git clone https://github.com/YOUR_USERNAME/homebrew-tudu.git
cd homebrew-tudu

# Create Casks directory
mkdir -p Casks
```

### 3.2 Create the Cask Formula

Create a file: `Casks/tudu.rb`

```ruby
cask "tudu" do
  version "1.0.0"
  sha256 "YOUR_SHA256_HASH_HERE"  # From step 2.3

  url "https://github.com/YOUR_USERNAME/tudu/releases/download/v#{version}/Tudu.zip"
  name "Tudu"
  desc "Beautiful todo app with widget support for macOS"
  homepage "https://github.com/YOUR_USERNAME/tudu"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Tudu.app"

  zap trash: [
    "~/Library/Preferences/com.yourname.Tudu.plist",
    "~/Library/Application Support/Tudu",
    "~/Library/Caches/com.yourname.Tudu",
  ]
end
```

### 3.3 Test Your Formula Locally

```bash
# Install from your tap
brew install --cask YOUR_USERNAME/tudu/tudu

# Or test without installing
brew audit --cask Casks/tudu.rb
brew style --cask Casks/tudu.rb
```

### 3.4 Push Your Tap

```bash
git add Casks/tudu.rb
git commit -m "Add Tudu cask"
git push origin main
```

---

## Step 4: Publish (Two Options)

### Option A: Use Your Own Tap (Easier for Beginners)

Users install with:
```bash
brew tap YOUR_USERNAME/tudu
brew install --cask tudu
```

**Pros:**
- Full control over your formula
- No approval process
- Can update anytime

**Cons:**
- Users need to tap your repo first
- Less discoverable

### Option B: Submit to Homebrew Cask (Official)

Submit to the official Homebrew Cask repository:

1. **Fork homebrew-cask**:
   ```bash
   # Fork on GitHub: https://github.com/Homebrew/homebrew-cask/fork

   git clone https://github.com/YOUR_USERNAME/homebrew-cask.git
   cd homebrew-cask
   ```

2. **Create your cask**:
   ```bash
   # Create branch
   git checkout -b tudu

   # Create cask file
   cp ~/homebrew-tudu/Casks/tudu.rb Casks/t/tudu.rb

   # Test it
   brew audit --cask --new Casks/t/tudu.rb
   brew style --cask Casks/t/tudu.rb
   ```

3. **Submit Pull Request**:
   ```bash
   git add Casks/t/tudu.rb
   git commit -m "Add Tudu cask"
   git push origin tudu

   # Create PR on GitHub
   gh pr create --repo Homebrew/homebrew-cask \
     --title "Add Tudu cask" \
     --body "New cask for Tudu - A beautiful todo app with widget support for macOS"
   ```

**Pros:**
- Users can install with just `brew install --cask tudu`
- More discoverable
- Listed on official Homebrew site

**Cons:**
- Requires approval from Homebrew maintainers
- Must follow strict guidelines
- Takes time for review

---

## Step 5: Update Your App

When you release a new version:

### 5.1 Create New Release

```bash
# Update version in Xcode
# Build new release
# Create new ZIP

# Tag and release
git tag -a v1.1.0 -m "Version 1.1.0"
git push origin v1.1.0

gh release create v1.1.0 \
  --title "Tudu v1.1.0" \
  --notes "What's new..." \
  Tudu.zip
```

### 5.2 Update Cask Formula

```bash
cd ~/homebrew-tudu

# Update Casks/tudu.rb
# - Change version to "1.1.0"
# - Update sha256 with new hash

git add Casks/tudu.rb
git commit -m "Update Tudu to v1.1.0"
git push
```

Users can then update with:
```bash
brew update
brew upgrade --cask tudu
```

---

## Quick Start Script

Save this as `release.sh`:

```bash
#!/bin/bash
set -e

VERSION=$1
if [ -z "$VERSION" ]; then
  echo "Usage: ./release.sh VERSION"
  echo "Example: ./release.sh 1.0.0"
  exit 1
fi

echo "Building Tudu v$VERSION..."

# Build
xcodebuild -project Tudu.xcodeproj \
  -scheme Tudu \
  -configuration Release \
  -derivedDataPath ./build \
  clean build

# Copy app
APP_PATH="./build/Build/Products/Release/Tudu.app"
cp -R "$APP_PATH" ./Release/

# Create ZIP
cd Release
ditto -c -k --sequesterRsrc --keepParent Tudu.app Tudu.zip

# Calculate SHA256
SHA256=$(shasum -a 256 Tudu.zip | awk '{print $1}')
echo "SHA256: $SHA256"

# Tag
cd ..
git tag -a "v$VERSION" -m "Version $VERSION"
git push origin "v$VERSION"

# Create GitHub release
gh release create "v$VERSION" \
  --title "Tudu v$VERSION" \
  --notes "Release notes here" \
  Release/Tudu.zip

echo "Done! Update your Homebrew cask with:"
echo "  version \"$VERSION\""
echo "  sha256 \"$SHA256\""
```

Make it executable:
```bash
chmod +x release.sh
```

Use it:
```bash
./release.sh 1.0.0
```

---

## Testing Checklist

Before publishing:

- [ ] App builds successfully in Release configuration
- [ ] App icon appears correctly
- [ ] Widget works and loads todos
- [ ] App Groups are configured correctly
- [ ] Code signing is set up (for distribution)
- [ ] ZIP file is created correctly
- [ ] SHA256 hash matches
- [ ] Cask formula passes `brew audit`
- [ ] Cask formula passes `brew style`
- [ ] App installs correctly via Homebrew
- [ ] App launches after Homebrew install
- [ ] Widget appears in widget gallery

---

## Useful Commands

```bash
# Test install locally
brew install --cask /path/to/your/tudu.rb

# Uninstall
brew uninstall --cask tudu

# Reinstall (for testing updates)
brew reinstall --cask tudu

# Check formula
brew audit --cask tudu
brew style --cask tudu

# Debug
brew install --cask --verbose --debug tudu
```

---

## Resources

- [Homebrew Cask Documentation](https://docs.brew.sh/Cask-Cookbook)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [How to Create a Homebrew Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [GitHub Releases Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)

---

## Example: Complete Workflow

```bash
# 1. Build and create ZIP
cd /Users/aslam/tempy/todo-widget/Tudu
./release.sh 1.0.0

# 2. Create tap (first time only)
cd ~/
gh repo create homebrew-tudu --public
git clone https://github.com/YOUR_USERNAME/homebrew-tudu.git
cd homebrew-tudu
mkdir -p Casks

# 3. Create formula
cat > Casks/tudu.rb << 'EOF'
cask "tudu" do
  version "1.0.0"
  sha256 "PASTE_YOUR_SHA256_HERE"

  url "https://github.com/YOUR_USERNAME/tudu/releases/download/v#{version}/Tudu.zip"
  name "Tudu"
  desc "Beautiful todo app with widget support"
  homepage "https://github.com/YOUR_USERNAME/tudu"

  app "Tudu.app"
end
EOF

# 4. Test
brew audit --cask Casks/tudu.rb
brew install --cask YOUR_USERNAME/tudu/tudu

# 5. Publish
git add Casks/tudu.rb
git commit -m "Add Tudu v1.0.0"
git push origin main

# 6. Tell users to install with:
# brew tap YOUR_USERNAME/tudu
# brew install --cask tudu
```

Good luck with your release! 🚀
