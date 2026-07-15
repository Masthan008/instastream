# InstaStream Downloader

A premium, cross-platform Flutter application for Android and iOS. InstaStream is an ad-free client-side media extraction and download utility that downloads high-definition videos (1080p, 2K, 4K) and audio (MP3) from **Instagram**, **YouTube**, and **WhatsApp Statuses** using direct URL inputs, a built-in search browser, or system-wide sharing intents.

---

## 🎨 Design System: Liquid Glass (Light Theme)
InstaStream is built with a premium **Liquid Glass** aesthetic featuring:
- **Translucent UI Panels**: Sigmas of 15+ backdrop blur with light border strokes.
- **Organic Fluid Shapes**: Droplet-inspired card corners and animated glowing highlights.
- **Vibrant Color Palette**: Emerald Green and Bright Teal gradients overlaid on a soft off-white background.
- **Premium Animations**: A multi-stage entrance sequence featuring `Curves.elasticOut`, continuous heartbeat pulsing action on the logo, and a shifting gradient shimmer progress indicator that mimics "liquid loading" on startup.

---

## 🚀 Core Features

### 1. Real-Time Download Picker UI & Flow
Tapping any format in the Bottom Sheet format picker launches a **Real-Time Download Progress System** directly inside that format tile.
- **No Background Obscurity**: Eliminates the "starting in background" message with direct feedback.
- **Live Progress Updates**: Displays percentage (%), download speed (MB/s), and Estimated Time of Arrival (ETA) with a clean progress bar.
- **Completion States**: Changes to a **"Downloaded • Saved to Gallery"** badge and checkmark when complete.

### 2. Android System Gallery Media Sync (Media Scanner)
Uses a custom native Kotlin **Android Platform Channel** that interfaces with `MediaScannerConnection`.
- Whenever a download completes (or a WhatsApp status is saved), the app notifies the Android MediaStore scanner.
- Files are immediately scanned and indexed, ensuring they show up in Google Photos, Samsung Gallery, and local file explorers.

### 3. Instagram CDN 403 Bypasser
Instagram CDN links throw a `HTTP 403 Forbidden` response when requested with standard HTTP clients.
- Direct downloads utilize browser-mimicking headers including a custom `Referer: https://www.instagram.com/` and mobile `User-Agent`.
- Ensures Instagram videos and reels download successfully on all devices.

### 4. Interactive Permissions Handler
- Runs active permissions checks prior to starting downloads.
- Prompts the user to grant storage permissions (or Manage All Files on Android 11+) on-the-fly, gracefully handling fallback sandbox options to prevent crashes.

### 5. System Share Sheet Integration
Integrates system-level share sheet listeners. Sharing any media URL directly from the official **YouTube** or **Instagram** app automatically opens InstaStream and launches the link analysis picker instantly.

### 6. YouTube Playlist Batch Downloader
Pasting a playlist URL analyzes and loads the entire video index.
- Includes **Select All / Deselect All** checkboxes.
- Provides a **Preferred Quality Dropdown** ("Best Video (HD)", "Fast Video (360p)", or "Audio Only (MP3)").
- Sequences all chosen items automatically into background download threads.

### 7. Dynamic Ad-Blocker (Domain Blocker)
The in-app WebView Browser includes a fully dynamic ad blocker.
- Intercepts and drops popups and redirect ads.
- Saves blocking rules inside a persistent Hive database box.
- Features a management dashboard in settings enabling users to dynamically add, delete, or reset blocked domains.

### 8. Local FFmpeg Muxing & Transcoding
Bundles native `ffmpeg_kit_flutter_new` binaries to perform complex processing locally on-device:
- **HD Muxing**: Downloads separate video-only tracks (e.g. 1080p, 1440p) and audio tracks, merging them into a single high-definition `.mp4` file.
- **MP3 Encoding**: Converts high-bitrate audio streams directly into standard `.mp3` format.

---

## 🛠️ Build & Verification Setup

Ensure your local Android development environment is configured with **minSdkVersion 24** and targets **compileSdk 36**.

### Run Application:
To build and execute on an Android emulator or physical device, run:
```powershell
# Stops background Java/Gradle caches to release file locks
Stop-Process -Name java -Force

# Performs clean wipe
flutter clean

# Get packages and build the debug app
flutter pub get
flutter run
```
