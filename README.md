# InstaStream Downloader

A premium, cross-platform Flutter application for Android and iOS. InstaStream is an ad-free client-side media extraction and download utility that downloads high-definition videos (1080p, 2K, 4K) and audio (MP3) from **Instagram** and **YouTube** using direct URL inputs or a built-in search browser.

---

## 🎨 Design System: Liquid Glass (Light Theme)
InstaStream is built with a premium **Liquid Glass** aesthetic featuring:
- **Translucent UI Panels**: Sigmas of 15+ backdrop blur with light border strokes.
- **Organic Fluid Shapes**: Droplet-inspired card corners and animated glowing highlights.
- **Vibrant Color Palette**: Emerald Green and Bright Teal gradients overlaid on a soft off-white background.
- **Micro-Animations**: Elastic spring transitions, pulsing action bubbles, and a water-wave initialization loading screen.

---

## 🚀 Core Features

### 1. Watermark-Free Extraction
All Instagram Reels, Posts, and Carousel media are parsed directly from Instagram CDNs, downloading clean, high-definition videos **without any watermarks** or overlays.

### 2. Play Preview Streaming
Before starting a download, you can tap **"Play Preview"** to stream and watch the video directly inside the app, ensuring you are fetching the correct video.

### 3. Video-to-Audio (MP3) Converter
Features a local conversion engine inside the Gallery. Any downloaded video file can be converted directly into a standalone `.mp3` audio track with a single tap, processed fully on-device.

### 4. Local FFmpeg Muxing & Transcoding
Bundles native `ffmpeg_kit_flutter_new` binaries to perform complex processing locally:
- **HD Muxing**: Downloads separate video-only tracks (e.g. 1080p, 1440p) and audio tracks, merging them into a single high-definition `.mp4` file.
- **MP3 Encoding**: Converts high-bitrate audio streams directly into standard `.mp3` format.
- **Timestamp Slicing**: FFmpeg crop filters for cutting media ranges before transcoding.

### 5. Smart Clipboard & WebView Browser
- Clipboard sniffing automatically detects links when you copy them outside the app.
- An in-app Browser Tab with a floating action button allows searching and browsing YouTube and Instagram directly, with support for Instagram login sessions to extract private media.

---

## 🛠️ Build & Verification Setup

Ensure your local Android development environment is configured with **minSdkVersion 24** and uses the custom plugin settings.

### Launch Application:
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
