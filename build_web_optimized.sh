#!/bin/bash
# Optimized web build script for better performance

echo "🚀 Building optimized web version..."

# Clean previous builds
flutter clean
flutter pub get

# Build with optimizations
flutter build web \
  --release \
  --pwa-strategy offline-first \
  --tree-shake-icons

# Remove unnecessary CanvasKit files if they exist (saves ~20MB)
if [ -d "build/web/canvaskit" ]; then
  echo "🧹 Removing CanvasKit files (not needed for HTML renderer)..."
  rm -rf build/web/canvaskit
fi

echo "✅ Build complete! Output: build/web/"
echo "📦 Bundle size:"
du -sh build/web
echo ""
echo "📊 Largest files:"
find build/web -type f -size +100k -exec ls -lh {} \; | awk '{print $5, $9}' | sort -rh | head -10
