import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/downloader_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/download_task.dart';
import '../../data/models/format_option.dart';
import '../../data/models/media_metadata.dart';
import '../../data/repositories/instagram_repository.dart';
import '../../data/repositories/youtube_repository.dart';

class DownloadProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  late final DownloaderService _downloader;
  final YoutubeRepository _ytRepo = YoutubeRepository();
  final InstagramRepository _igRepo = InstagramRepository();

  List<DownloadTask> _tasks = [];
  bool _isAnalyzing = false;
  MediaMetadata? _analyzedMetadata;
  String? _errorMessage;
  bool _isDarkMode = false;
  int _maxConcurrentDownloads = 2;

  DownloadProvider() {
    _downloader = DownloaderService(_storage);
    _init();
  }

  List<DownloadTask> get tasks => _tasks;
  bool get isAnalyzing => _isAnalyzing;
  MediaMetadata? get analyzedMetadata => _analyzedMetadata;
  String? get errorMessage => _errorMessage;
  bool get isDarkMode => _isDarkMode;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  Future<void> _init() async {
    await _storage.init();
    _isDarkMode = _storage.getThemePreference();
    _maxConcurrentDownloads = _storage.getMaxConcurrentDownloads();
    _loadTasks();
    // Watch storage box and update tasks reactively
    _storage.watchTasks().listen((_) {
      _loadTasks();
    });
  }

  void _loadTasks() {
    _tasks = _storage.getAllTasks();
    notifyListeners();
  }

  void resetAnalysis() {
    _analyzedMetadata = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> analyzeLink(String url) async {
    if (url.trim().isEmpty) return;

    _isAnalyzing = true;
    _analyzedMetadata = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final cleanUrl = url.trim();
      if (cleanUrl.contains('youtube.com') || cleanUrl.contains('youtu.be')) {
        final meta = await _ytRepo.getMetadata(cleanUrl);
        if (meta != null) {
          _analyzedMetadata = meta;
        } else {
          _errorMessage = 'Could not retrieve YouTube metadata. Please check the link.';
        }
      } else if (cleanUrl.contains('instagram.com')) {
        final meta = await _igRepo.getMetadata(cleanUrl);
        if (meta != null) {
          _analyzedMetadata = meta;
        } else {
          // If public scraping fails, return metadata with blank format, alerting UI to fetch via WebView
          _analyzedMetadata = _igRepo.buildMetadataFromDirectLink(
            originalUrl: cleanUrl,
            directLink: '',
            isVideo: true,
            title: 'Instagram Post (Private or Requires Login)',
          );
        }
      } else {
        _errorMessage = 'Unsupported URL. We support YouTube and Instagram URLs.';
      }
    } catch (e) {
      _errorMessage = 'Error analyzing link: $e';
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  void applyDirectInstagramLink(String originalUrl, String directUrl, bool isVideo, {String? title}) {
    final meta = _igRepo.buildMetadataFromDirectLink(
      originalUrl: originalUrl,
      directLink: directUrl,
      isVideo: isVideo,
      title: title,
    );
    _analyzedMetadata = meta;
    notifyListeners();
  }

  void applyInstagramSlideshow(String originalUrl, List<Map<String, dynamic>> slides, String title) {
    final meta = _igRepo.buildMetadataFromSlides(
      originalUrl: originalUrl,
      slides: slides,
      title: title,
    );
    _analyzedMetadata = meta;
    notifyListeners();
  }

  Future<void> triggerDownload(FormatOption format) async {
    if (_analyzedMetadata == null) return;
    
    // Trigger download asynchronously so it doesn't block UI
    _downloader.download(
      metadata: _analyzedMetadata!,
      format: format,
      onProgressUpdate: (task) {
        _loadTasks();
      },
    );
    
    _analyzedMetadata = null;
    notifyListeners();
  }

  Future<void> triggerPlaylistDownload(MediaMetadata playlistMeta, String preferredQuality) async {
    // preferredQuality can be 'best_video', 'fast_video', or 'audio_mp3'
    for (var format in playlistMeta.formats) {
      if (format.id.startsWith('playlist_item_')) {
        final videoUrl = format.originalStreamInfo as String;
        try {
          final videoMeta = await _ytRepo.getMetadata(videoUrl);
          if (videoMeta == null || videoMeta.formats.isEmpty) continue;

          FormatOption? chosenFormat;
          if (preferredQuality == 'audio_mp3') {
            chosenFormat = videoMeta.formats.firstWhere(
              (f) => f.id.startsWith('audio_mp3_'),
              orElse: () => videoMeta.formats.firstWhere(
                (f) => f.isAudioOnly,
                orElse: () => videoMeta.formats.first,
              ),
            );
          } else if (preferredQuality == 'fast_video') {
            chosenFormat = videoMeta.formats.firstWhere(
              (f) => !f.isAudioOnly && f.id.startsWith('muxed_') && f.qualityValue <= 360,
              orElse: () => videoMeta.formats.firstWhere(
                (f) => !f.isAudioOnly,
                orElse: () => videoMeta.formats.first,
              ),
            );
          } else {
            chosenFormat = videoMeta.formats.firstWhere(
              (f) => !f.isAudioOnly,
              orElse: () => videoMeta.formats.first,
            );
          }

          _downloader.download(
            metadata: videoMeta,
            format: chosenFormat,
            onProgressUpdate: (task) {
              _loadTasks();
            },
          );
        } catch (e) {
          print('Failed to download playlist item $videoUrl: $e');
        }
      }
    }
  }

  void cancelTask(String id) {
    _downloader.cancelDownload(id);
    _storage.deleteTask(id);
    _loadTasks();
  }

  Future<void> deleteTask(String id) async {
    _storage.deleteTask(id);
    _loadTasks();
  }

  Future<void> clearAllHistory() async {
    await _storage.clearAll();
    _loadTasks();
  }

  Future<void> addCompletedTask(DownloadTask task) async {
    await _storage.saveTask(task);
    _loadTasks();
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    await _storage.saveThemePreference(value);
    notifyListeners();
  }

  List<String> get blockedDomains => _storage.getBlockedDomains();

  Future<void> addBlockedDomain(String domain) async {
    final list = _storage.getBlockedDomains();
    final cleanDomain = domain.trim().toLowerCase();
    if (cleanDomain.isNotEmpty && !list.contains(cleanDomain)) {
      list.add(cleanDomain);
      await _storage.saveBlockedDomains(list);
      notifyListeners();
    }
  }

  Future<void> removeBlockedDomain(String domain) async {
    final list = _storage.getBlockedDomains();
    if (list.contains(domain)) {
      list.remove(domain);
      await _storage.saveBlockedDomains(list);
      notifyListeners();
    }
  }

  Future<void> resetBlockedDomains() async {
    await _storage.saveBlockedDomains(List<String>.from(StorageService.defaultBlockedDomains));
    notifyListeners();
  }

  Future<void> setMaxConcurrentDownloads(int count) async {
    _maxConcurrentDownloads = count;
    await _storage.saveMaxConcurrentDownloads(count);
    notifyListeners();
  }

  Future<bool> checkAndRequestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.storage.isGranted) return true;
    if (await Permission.videos.isGranted && await Permission.audio.isGranted) return true;

    try {
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }
      
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;

      final videosStatus = await Permission.videos.request();
      final audioStatus = await Permission.audio.request();
      if (videosStatus.isGranted && audioStatus.isGranted) return true;
    } catch (e) {
      print('Permission request failed: $e');
    }
    
    return false;
  }

  @override
  void dispose() {
    _ytRepo.close();
    super.dispose();
  }
}
