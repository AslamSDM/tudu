#!/bin/bash
set -e

echo "🚀 Building Tudu Release..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get version from argument or default to 1.0.0
VERSION=${1:-1.0.0}

echo -e "${BLUE}Version: ${VERSION}${NC}"
echo ""

# Build directory
BUILD_DIR="./build"
RELEASE_DIR="./Release"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Build the app
echo -e "${YELLOW}Building Tudu app...${NC}"
xcodebuild -project Tudu.xcodeproj \
  -scheme Tudu \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  clean build

# Find the built app
APP_PATH=$(find "$BUILD_DIR/Build/Products/Release" -name "Tudu.app" -maxdepth 1 | head -n 1)

if [ -z "$APP_PATH" ]; then
  echo -e "${RED}❌ Error: Could not find built app${NC}"
  exit 1
fi

echo -e "${GREEN}✓ App built successfully${NC}"
echo -e "  Location: $APP_PATH"
echo ""

# Copy to Release folder
echo -e "${YELLOW}Copying to Release folder...${NC}"
cp -R "$APP_PATH" "$RELEASE_DIR/"
echo -e "${GREEN}✓ Copied${NC}"
echo ""

# Create ZIP
echo -e "${YELLOW}Creating ZIP archive...${NC}"
cd "$RELEASE_DIR"
ditto -c -k --sequesterRsrc --keepParent Tudu.app Tudu-${VERSION}.zip
cd ..

echo -e "${GREEN}✓ ZIP created${NC}"
echo -e "  File: $RELEASE_DIR/Tudu-${VERSION}.zip"
echo ""

# Calculate SHA256
echo -e "${YELLOW}Calculating SHA256...${NC}"
SHA256=$(shasum -a 256 "$RELEASE_DIR/Tudu-${VERSION}.zip" | awk '{print $1}')
echo -e "${GREEN}✓ SHA256: ${SHA256}${NC}"
echo ""

# Get file size
SIZE=$(du -h "$RELEASE_DIR/Tudu-${VERSION}.zip" | awk '{print $1}')
echo -e "${BLUE}File size: ${SIZE}${NC}"
echo ""

# Summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Build Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Version: ${BLUE}${VERSION}${NC}"
echo -e "App:     ${BLUE}$RELEASE_DIR/Tudu.app${NC}"
echo -e "ZIP:     ${BLUE}$RELEASE_DIR/Tudu-${VERSION}.zip${NC}"
echo -e "SHA256:  ${BLUE}${SHA256}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the app:"
echo -e "   ${BLUE}open $RELEASE_DIR/Tudu.app${NC}"
echo ""
echo "2. Create a GitHub release:"
echo -e "   ${BLUE}git tag -a v${VERSION} -m 'Version ${VERSION}'${NC}"
echo -e "   ${BLUE}git push origin v${VERSION}${NC}"
echo -e "   ${BLUE}gh release create v${VERSION} --title 'Tudu v${VERSION}' $RELEASE_DIR/Tudu-${VERSION}.zip${NC}"
echo ""
echo "3. Update your Homebrew cask with:"
echo -e "   ${BLUE}version \"${VERSION}\"${NC}"
echo -e "   ${BLUE}sha256 \"${SHA256}\"${NC}"
echo ""
