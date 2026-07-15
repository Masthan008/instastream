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

### 1. System Share Sheet Integration
Integrates system-level share sheet listeners. Sharing any media URL directly from the official **YouTube** or **Instagram** app automatically opens InstaStream and launches the link analysis picker instantly.

### 2. YouTube Playlist Batch Downloader
Pasting a playlist URL analyzes and loads the entire video index.
- Includes **Select All / Deselect All** checkboxes.
- Provides a **Preferred Quality Dropdown** ("Best Video (HD)", "Fast Video (360p)", or "Audio Only (MP3)").
- Sequences all chosen items automatically into background download threads.

### 3. Dynamic Ad-Blocker (Domain Blocker)
The in-app WebView Browser includes a fully dynamic ad blocker.
- Intercepts and drops popups and redirect ads.
- Saves blocking rules inside a persistent Hive database box.
- Features a management dashboard in settings enabling users to dynamically add, delete, or reset blocked domains.

### 4. Watermark-Free Extraction & Play Preview
- All Instagram Reels, Posts, and Carousel media are parsed directly from Instagram CDNs, downloading clean, high-definition videos **without any watermarks**.
- Tap **"Play Preview"** to stream and watch the video directly inside the app before downloading.

### 5. Local FFmpeg Muxing & Transcoding
Bundles native `ffmpeg_kit_flutter_new` binaries to perform complex processing locally on-device:
- **HD Muxing**: Downloads separate video-only tracks (e.g. 1080p, 1440p) and audio tracks, merging them into a single high-definition `.mp4` file.
- **MP3 Encoding**: Converts high-bitrate audio streams directly into standard `.mp3` format.

### 6. Storage Permissions & Sandboxed Fallbacks
- **Public Directory Access**: Saves downloads directly to public shared folders (`/storage/emulated/0/Download/InstaStream`), making them instantly indexable by standard system galleries on Android 11-16.
- **Sandbox Fallback**: Performs real-time test-writes on startup. If public directory access is denied, it automatically fallbacks to sandboxed app-specific storage directories, preventing app crashes.

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
