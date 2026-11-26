#!/bin/bash
set -e

echo "🚀 Building Google Music Release (Android + iOS)..."

# Export flutter to PATH
export PATH="$PATH:/Users/mkx/flutter/bin"

# 1. Build Android Release APK
echo "📦 1/2 Building Android APK..."
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ./google_music.apk

# 2. Build iOS Release App and Package IPA
echo "🍎 2/2 Building iOS IPA..."
flutter build ios --release
rm -rf build/ios/ipa
mkdir -p build/ios/ipa/Payload
cp -R build/ios/iphoneos/Runner.app build/ios/ipa/Payload/
cd build/ios/ipa
zip -rq google_music.ipa Payload
cd ../../..
cp build/ios/ipa/google_music.ipa ./google_music.ipa

echo "✅ All Release builds completed successfully!"
echo "📁 Output files:"
ls -lh ./google_music.apk ./google_music.ipa
