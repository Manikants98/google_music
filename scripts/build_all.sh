#!/bin/bash
set -e

# ==============================================================================
# 🎵 GOOGLE MUSIC - ALL-IN-ONE RELEASE BUILD PIPELINE
#
# Features:
#   1. Automatic Multi-File Version Bumping (pubspec, update service, Android)
#   2. Pre-flight Quality Gate (flutter analyze)
#   3. Release Android APK Compilation (google_music.apk)
#   4. Release macOS DMG Packaging (google_music.dmg)
#   5. Beautiful Colored Metrics & Summary Table
#
# Usage:
#   ./scripts/build_all.sh                 # Builds with current version
#   ./scripts/build_all.sh 1.0.7-beta.4    # Auto-bumps version & builds
#   ./scripts/build_all.sh v1.0.7-beta.4   # Supports leading 'v'
#   ./scripts/build_all.sh 1.0.7-beta.4+14 # Explicit build number
# ==============================================================================

# Ensure Flutter is in PATH
export PATH="$PATH:/Users/mkx/flutter/bin:/usr/local/bin:/opt/homebrew/bin"

# ANSI Color Codes
BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
MAGENTA="\033[35m"
RESET="\033[0m"

START_TIME=$(date +%s)

print_banner() {
  echo -e "${CYAN}${BOLD}"
  echo "╔═══════════════════════════════════════════════════════════════╗"
  echo "║                🎵 GOOGLE MUSIC RELEASE BUILD                  ║"
  echo "║                  Automated Release Pipeline                   ║"
  echo "╚═══════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

print_banner

# ------------------------------------------------------------------------------
# STEP 1: VERSION RESOLUTION & AUTO-UPDATE
# ------------------------------------------------------------------------------
INPUT_VERSION="$1"

if [ -n "$INPUT_VERSION" ]; then
  # Strip leading 'v'
  CLEAN_INPUT="${INPUT_VERSION#v}"

  if [[ "$CLEAN_INPUT" == *"+"* ]]; then
    VERSION_NAME="${CLEAN_INPUT%+*}"
    BUILD_NUMBER="${CLEAN_INPUT#*+}"
  else
    VERSION_NAME="$CLEAN_INPUT"
    # Auto-increment build number from pubspec.yaml
    CURRENT_VERSION=$(grep "^version:" pubspec.yaml | head -n 1 | awk '{print $2}')
    if [[ "$CURRENT_VERSION" == *"+"* ]]; then
      CURRENT_BUILD="${CURRENT_VERSION#*+}"
      BUILD_NUMBER=$((CURRENT_BUILD + 1))
    else
      BUILD_NUMBER=1
    fi
  fi

  FULL_VERSION="${VERSION_NAME}+${BUILD_NUMBER}"

  echo -e "${MAGENTA}${BOLD}⚙️  [1/4] Bumping Project Version to ${FULL_VERSION}...${RESET}"

  # 1. Update pubspec.yaml
  sed -i '' "s/^version: .*/version: ${FULL_VERSION}/" pubspec.yaml
  echo -e "   ${GREEN}✓${RESET} pubspec.yaml -> ${BOLD}${FULL_VERSION}${RESET}"

  # 2. Update lib/core/update/app_update_service.dart
  UPDATE_SERVICE="lib/core/update/app_update_service.dart"
  if [ -f "$UPDATE_SERVICE" ]; then
    sed -i '' "s/static const String currentAppVersion = '[^']*';/static const String currentAppVersion = '${VERSION_NAME}';/" "$UPDATE_SERVICE"
    echo -e "   ${GREEN}✓${RESET} AppUpdateService -> ${BOLD}${VERSION_NAME}${RESET}"
  fi

  # 3. Update android/app/src/main/kotlin/com/mkx/google_music/MainActivity.kt
  MAIN_ACTIVITY="android/app/src/main/kotlin/com/mkx/google_music/MainActivity.kt"
  if [ -f "$MAIN_ACTIVITY" ]; then
    sed -i '' "s/pInfo\.versionName ?: \"[^\"]*\"/pInfo.versionName ?: \"${VERSION_NAME}\"/" "$MAIN_ACTIVITY"
    sed -i '' "s/result\.success(\"[^\"]*\")/result.success(\"${VERSION_NAME}\")/" "$MAIN_ACTIVITY"
    echo -e "   ${GREEN}✓${RESET} MainActivity.kt -> ${BOLD}${VERSION_NAME}${RESET}"
  fi

  # 4. Update android/local.properties
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
    echo -e "   ${GREEN}✓${RESET} local.properties -> ${BOLD}v${VERSION_NAME} (${BUILD_NUMBER})${RESET}"
  fi
else
  FULL_VERSION=$(grep "^version:" pubspec.yaml | head -n 1 | awk '{print $2}')
  VERSION_NAME="${FULL_VERSION%+*}"
  BUILD_NUMBER="${FULL_VERSION#*+}"
  echo -e "${MAGENTA}${BOLD}ℹ️  [1/4] Using Current Version: ${FULL_VERSION}${RESET}"
  echo -e "   ${DIM}(Tip: Pass version argument to auto-bump, e.g. ./scripts/build_all.sh 1.0.7-beta.4)${RESET}"
fi

echo ""

# ------------------------------------------------------------------------------
# STEP 2: PRE-FLIGHT CODE QUALITY GATE
# ------------------------------------------------------------------------------
echo -e "${CYAN}${BOLD}🔍 [2/4] Running Code Analysis (flutter analyze)...${RESET}"
if flutter analyze; then
  echo -e "${GREEN}✓ Code analysis passed clean with 0 issues!${RESET}\n"
else
  echo -e "${RED}❌ Code analysis failed. Fix reported errors before building.${RESET}"
  exit 1
fi

# ------------------------------------------------------------------------------
# STEP 3: ANDROID RELEASE APK BUILD
# ------------------------------------------------------------------------------
RELEASE_TAG="v${VERSION_NAME}"
RELEASE_DIR="releases/${RELEASE_TAG}"
mkdir -p "$RELEASE_DIR"

APK_OUTPUT="${RELEASE_DIR}/google_music.apk"
DMG_OUTPUT="${RELEASE_DIR}/google_music.dmg"

echo -e "${YELLOW}${BOLD}🤖 [3/4] Building Android Release APK...${RESET}"
flutter build apk --release

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
  cp build/app/outputs/flutter-apk/app-release.apk "$APK_OUTPUT"
  rm -f ./google_music.apk
  APK_SIZE=$(ls -lh "$APK_OUTPUT" | awk '{print $5}')
  echo -e "${GREEN}✓ Android APK built successfully: ${BOLD}${APK_OUTPUT}${RESET} (${APK_SIZE})\n"
else
  echo -e "${RED}❌ Android build failed to produce APK output.${RESET}"
  exit 1
fi

# ------------------------------------------------------------------------------
# STEP 4: macOS RELEASE DMG BUILD
# ------------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}🍏 [4/4] Building macOS Release DMG...${RESET}"
flutter build macos --release

MACOS_APP_PATH="build/macos/Build/Products/Release/Google Music.app"
if [ -d "$MACOS_APP_PATH" ]; then
  rm -f "$DMG_OUTPUT" ./google_music.dmg
  hdiutil create -volname "Google Music" -srcfolder "$MACOS_APP_PATH" -ov -format UDZO "$DMG_OUTPUT" > /dev/null
  DMG_SIZE=$(ls -lh "$DMG_OUTPUT" | awk '{print $5}')
  echo -e "${GREEN}✓ macOS DMG packaged successfully: ${BOLD}${DMG_OUTPUT}${RESET} (${DMG_SIZE})\n"
else
  echo -e "${RED}❌ macOS build failed to produce .app bundle.${RESET}"
  exit 1
fi

# ------------------------------------------------------------------------------
# BUILD SUMMARY & GITHUB RELEASE INSTRUCTIONS
# ------------------------------------------------------------------------------
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo -e "${GREEN}${BOLD}"
echo "================================================================="
echo "🎉 RELEASE BUILD SUCCEEDED IN ${MINUTES}m ${SECONDS}s!"
echo "================================================================="
echo -e "${RESET}"

echo -e "${BOLD}Target Version :${RESET} ${CYAN}${VERSION_NAME} (Build ${BUILD_NUMBER})${RESET}"
echo -e "${BOLD}Release Folder :${RESET} ${CYAN}${RELEASE_DIR}/${RESET}"
echo -e "${BOLD}Git Branch     :${RESET} ${CYAN}$(git branch --show-current)${RESET}"
echo ""
echo -e "${BOLD}Generated Artifacts:${RESET}"
echo -e "  📦 Android APK : ${BOLD}${APK_OUTPUT}${RESET} (${APK_SIZE})"
echo -e "  💿 macOS DMG   : ${BOLD}${DMG_OUTPUT}${RESET} (${DMG_SIZE})"
echo ""

# Quick GitHub release tip
echo -e "${DIM}To publish this release on GitHub, run:${RESET}"
echo -e "${CYAN}git add . && git commit -m \"chore(release): bump to ${FULL_VERSION}\" && git push origin beta${RESET}"
echo -e "${CYAN}gh release create ${RELEASE_TAG} ${APK_OUTPUT} ${DMG_OUTPUT} --title \"${RELEASE_TAG}\" --prerelease${RESET}"
echo "================================================================="
