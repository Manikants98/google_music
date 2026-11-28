#!/bin/bash
set -e

# Usage:
#   ./scripts/bump_version.sh 1.0.7-beta.3
#   ./scripts/bump_version.sh v1.0.7-beta.3
#   ./scripts/bump_version.sh 1.0.7-beta.3+13

INPUT="$1"

if [ -z "$INPUT" ]; then
  echo "❌ Error: Please provide a version number."
  echo "Usage: ./scripts/bump_version.sh <version> (e.g. ./scripts/bump_version.sh 1.0.7-beta.3)"
  exit 1
fi

# Strip leading 'v' if present
CLEAN_INPUT="${INPUT#v}"

# Extract version name and optional build number
if [[ "$CLEAN_INPUT" == *"+"* ]]; then
  VERSION_NAME="${CLEAN_INPUT%+*}"
  BUILD_NUMBER="${CLEAN_INPUT#*+}"
else
  VERSION_NAME="$CLEAN_INPUT"
  # Read current build number from pubspec.yaml and increment by 1
  CURRENT_VERSION=$(grep "^version:" pubspec.yaml | head -n 1 | awk '{print $2}')
  if [[ "$CURRENT_VERSION" == *"+"* ]]; then
    CURRENT_BUILD="${CURRENT_VERSION#*+}"
    BUILD_NUMBER=$((CURRENT_BUILD + 1))
  else
    BUILD_NUMBER=1
  fi
fi

FULL_VERSION="${VERSION_NAME}+${BUILD_NUMBER}"

echo "=========================================="
echo "🚀 Bumping Google Music Version"
echo "   Version Name : $VERSION_NAME"
echo "   Build Number : $BUILD_NUMBER"
echo "   Full Version : $FULL_VERSION"
echo "=========================================="

# 1. Update pubspec.yaml
if [ -f "pubspec.yaml" ]; then
  sed -i '' "s/^version: .*/version: ${FULL_VERSION}/" pubspec.yaml
  echo "✅ Updated pubspec.yaml -> version: ${FULL_VERSION}"
else
  echo "⚠️ Warning: pubspec.yaml not found"
fi

# 2. Update lib/core/update/app_update_service.dart
UPDATE_SERVICE="lib/core/update/app_update_service.dart"
if [ -f "$UPDATE_SERVICE" ]; then
  sed -i '' "s/static const String currentAppVersion = '[^']*';/static const String currentAppVersion = '${VERSION_NAME}';/" "$UPDATE_SERVICE"
  echo "✅ Updated $UPDATE_SERVICE -> currentAppVersion = '${VERSION_NAME}'"
else
  echo "⚠️ Warning: $UPDATE_SERVICE not found"
fi

# 3. Update android/app/src/main/kotlin/com/mkx/google_music/MainActivity.kt
MAIN_ACTIVITY="android/app/src/main/kotlin/com/mkx/google_music/MainActivity.kt"
if [ -f "$MAIN_ACTIVITY" ]; then
  sed -i '' "s/pInfo\.versionName ?: \"[^\"]*\"/pInfo.versionName ?: \"${VERSION_NAME}\"/" "$MAIN_ACTIVITY"
  sed -i '' "s/result\.success(\"[^\"]*\")/result.success(\"${VERSION_NAME}\")/" "$MAIN_ACTIVITY"
  echo "✅ Updated $MAIN_ACTIVITY -> fallback version = \"${VERSION_NAME}\""
else
  echo "⚠️ Warning: $MAIN_ACTIVITY not found"
fi

# 4. Update android/local.properties if exists
LOCAL_PROPERTIES="android/local.properties"
if [ -f "$LOCAL_PROPERTIES" ]; then
  if grep -q "^flutter.versionName=" "$LOCAL_PROPERTIES"; then
    sed -i '' "s/^flutter\.versionName=.*/flutter.versionName=${VERSION_NAME}/" "$LOCAL_PROPERTIES"
  else
    echo "flutter.versionName=${VERSION_NAME}" >> "$LOCAL_PROPERTIES"
  fi

  if grep -q "^flutter.versionCode=" "$LOCAL_PROPERTIES"; then
    sed -i '' "s/^flutter\.versionCode=.*/flutter.versionCode=${BUILD_NUMBER}/" "$LOCAL_PROPERTIES"
  else
    echo "flutter.versionCode=${BUILD_NUMBER}" >> "$LOCAL_PROPERTIES"
  fi
  echo "✅ Updated $LOCAL_PROPERTIES -> versionName: ${VERSION_NAME}, versionCode: ${BUILD_NUMBER}"
fi

echo "=========================================="
echo "🎉 Version successfully bumped to $FULL_VERSION across all files!"
echo "=========================================="
