#!/bin/bash
set -e

echo "Building Google Music Release (Android APK)..."

# Export flutter to PATH
export PATH="$PATH:/Users/mkx/flutter/bin"

# Build Android Release APK
echo "Building Android APK..."
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk ./google_music.apk

echo "Release build completed successfully!"
echo "Output file:"
ls -lh ./google_music.apk
