# Google Music Flutter App Icons (Light & Dark)

All icons are high-resolution **1024×1024 PNG** assets ready for Flutter (`flutter_launcher_icons`), Android, iOS, Web, and Desktop.

## Folder Structure
- `light/` — Light theme icons in **Square**, **Rounded Square**, **Circle**, **Squircle**, **Teardrop**, and **Hexagon** shapes.
- `dark/` — Dark theme icons in **Square**, **Rounded Square**, **Circle**, **Squircle**, **Teardrop**, and **Hexagon** shapes.
- `adaptive/` — Transparent foreground layer + solid Light/Dark backgrounds for Android Adaptive Icons.

## Quick Flutter Setup (`flutter_launcher_icons`)
Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/google_music_light_square_1024x1024.png"
  adaptive_icon_background: "#F8F9FB" # Or "#18191C" for Dark mode
  adaptive_icon_foreground: "assets/icon/foreground_transparent_1024x1024.png"
```
