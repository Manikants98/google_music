<div align="center">

# 🎵 Google Music

**A Next-Gen, High-Performance Music Streaming & Offline Audio Player for Android**  
*Built with Flutter, Material 3 Expressive, and YouTube Music (InnerTube) Engine.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Material 3 Expressive](https://img.shields.io/badge/UI-Material_3_Expressive-6750A4?style=for-the-badge&logo=material-design&logoColor=white)](https://m3.material.io)
[![Android](https://img.shields.io/badge/Android-5.0+-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)
[![Version](https://img.shields.io/badge/Version-v1.0.6-brightgreen?style=for-the-badge)](https://github.com/Manikants98/google_music/releases)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

</div>

---

## 🌟 Overview

**Google Music** is a music player crafted for Android. Designed around Google's **Material 3 Expressive (M3E)** design system, it delivers dynamic visual palettes extracted in real time from album art, fluid soundwave sliders, background playback, offline caching, and synchronized karaoke lyrics.

Under the hood, it features a low-latency audio pipeline with proactive stream prefetching, fine-grained UI rebuild isolation for 60/120 FPS animations, and an in-app auto-update engine powered directly by GitHub Releases.

---

## ✨ Features at a Glance

### 🎨 Material 3 Expressive Design & Dynamic Theming
- **Dynamic Palette Grading**: Seamlessly seeds Light and Dark color schemes from the active song's album art.
- **Google Pixel Wavy Slider**: Custom interactive soundwave playback slider with smooth sinusoidal wave animations during playback.
- **Floating Mini Player Pill**: Docked gesture-enabled pill with horizontal swipe-to-skip, vertical swipe-to-expand, and real-time progress indicators.
- **Custom Typography**: Styled with `Plus Jakarta Sans` via Google Fonts.

### 🎧 High-Fidelity Audio Engine
- **Background Playback & Lockscreen**: Powered by `just_audio` and `audio_service` with full Android MediaSession notification controls, artwork rendering, and seek support.
- **Instant Track Switching**: Proactive stream resolution and upcoming track prefetching ensure playback with low buffering even on slow networks.
- **Smart Queue & Strict Playlist Modes**: Endless smart autoplay queue for discovering similar songs, alongside an isolated **Strict Playlist Mode** where Up Next contains only the songs in that playlist.
- **Smart Shuffle & Behavior Tracker**: Learns user listening habits, tracks skip behavior, and personalizes feeds (Quick Picks & Speed Dials).

### 🎤 Synchronized Karaoke Lyrics
- **Real-Time Synchronized Scrolling**: Highlights active lines in real time and automatically auto-scrolls with the song.
- **Tap-to-Seek**: Tap any lyric line to jump the playback directly to that timestamp.
- **Plain Text Fallback**: Displays official YouTube Music lyrics when synchronized timestamps are unavailable.

### 📥 Offline Downloads Manager
- **Direct Audio Downloads**: Download songs locally for offline playback without an internet connection.
- **Persistent System Notifications**: Download progress channel and dedicated completion channel with system audio alert.
- **In-App Notification Snackbars**: Expressive dark-themed floating notifications when downloads finish.

### 🔄 In-App Auto-Updates via GitHub Releases
- **One-Tap Updates**: Checks for new versions against GitHub Releases, parses markdown changelogs into styled cards, downloads release APKs in the background, and prompts native Android package installation.

---

## 🚀 Performance Architecture

To maintain high responsiveness and prevent frame drops during long listening sessions:

| Optimization | Description |
| :--- | :--- |
| **Decoupled Position Streams** | Audio playback position updates (`100ms-200ms`) are decoupled from `ChangeNotifier.notifyListeners()` using fine-grained `ValueNotifier<Duration>` seekbars. |
| **MaterialApp Isolation** | Root `MaterialApp` and theme generation are scoped via `Selector`—eliminating 5–10 root rebuilds per second during playback. |
| **Selective Widget Rebuilding** | `TrackTile` instances and shell screens observe state via `context.select()`, ensuring only active items update. |
| **Persistent Tab Caching** | Screen navigation tabs in `IndexedStack` are cached in state to prevent unnecessary widget allocations on navigation. |

---

## 🛠️ Tech Stack & Libraries

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
- **UI & Animation**: `material_3_expressive`, `palette_generator`, `google_fonts`, `animations`
- **Audio & Media Session**: `just_audio`, `audio_service`
- **Backend & Streaming**: `youtube_explode_dart`, `http`
- **Networking & Caching**: `cached_network_image`, `path_provider`
- **State Management**: `provider`

---

## 📂 Project Structure

```text
lib/
├── core/
│   ├── audio/          # Music player controller & background audio handler
│   ├── network/        # Stream extractor & InnerTube YouTube client
│   ├── offline/        # Offline download manager & notification service
│   ├── update/         # In-app GitHub release updater & changelog dialog
│   └── widgets/        # Wavy soundwave slider, M3E widgets, track tiles
├── features/
│   ├── home/           # Home screen, dynamic language sections, smart carousels
│   ├── library/        # Liked tracks, playlists, history, and downloads tab
│   ├── player/         # Floating mini player pill, Now Playing modal, lyrics & queue
│   ├── playlist/       # Playlist management, detail view & custom track addition
│   ├── search/         # Debounced discovery screen with language exploration
│   └── settings/       # Theme mode toggle, cache clearing, app version info
├── models/             # Song, Playlist, PlaybackState, and Lyrics models
└── main.dart           # App entry point, M3E theme configuration, root navigation
```

---

## ⚙️ Installation & Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.13.4 or higher)
- Android Studio / VS Code with Flutter extension
- Android Device or Emulator running Android 5.0 (API 21) or higher

### Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Manikants98/google_music.git
   cd google_music
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on connected device / emulator:**
   ```bash
   flutter run
   ```

4. **Build release APK:**
   ```bash
   flutter build apk --release
   ```
   *The release APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.*

---

## 👨‍💻 Author & Developer

**Mani Kant Sharma**  
*Software Developer specializing in Flutter, React, and Node.*  
- **GitHub**: [@Manikants98](https://github.com/Manikants98)
- **Repository**: [google_music](https://github.com/Manikants98/google_music)

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
