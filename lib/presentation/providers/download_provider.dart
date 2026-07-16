import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/downloader_service.dart';
import '../../core/services/notification_service.dart';
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
  final NotificationService _notif = NotificationService();
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
    await _notif.init();
    _storage.watchTasks().listen((_) {
      _loadTasks();
    });
  }

  void _onProgress(DownloadTask task) {
    _loadTasks();
    final notifId = task.id.hashCode;
    if (task.status == DownloadStatus.completed) {
      _notif.showCompletionNotification(
        id: notifId,
        title: task.title,
        filePath: task.filePath ?? '',
      );
    } else if (task.status == DownloadStatus.failed) {
      _notif.showProgressNotification(
        id: notifId,
        title: 'Download Failed',
        message: task.error ?? 'Unknown error',
        progress: 100,
      );
    } else if (task.status == DownloadStatus.processing) {
      _notif.showProgressNotification(
        id: notifId,
        title: task.title,
        message: 'Processing...',
        progress: 100,
        indeterminate: true,
      );
    } else {
      _notif.showProgressNotification(
        id: notifId,
        title: task.title,
        message: task.speed,
        progress: (task.progress * 100).round(),
      );
    }
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

  void applyDirectInstagramLink(String originalUrl, String directUrl, bool isVideo, {String? title, String? thumbnailUrl, String? username}) {
    final meta = _igRepo.buildMetadataFromDirectLink(
      originalUrl: originalUrl,
      directLink: directUrl,
      isVideo: isVideo,
      title: title,
      username: username,
      thumbnailUrl: thumbnailUrl,
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
    
    if (smartModeEnabled) {
      await savePreferredFormat(_analyzedMetadata!.sourceType, format.id);
    }
    
    // Trigger download asynchronously so it doesn't block UI
    _downloader.download(
      metadata: _analyzedMetadata!,
      format: format,
      onProgressUpdate: _onProgress,
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
            onProgressUpdate: _onProgress,
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
    _notif.cancelNotification(id.hashCode);
    _loadTasks();
  }

  Future<void> deleteTask(String id) async {
    _storage.deleteTask(id);
    _notif.cancelNotification(id.hashCode);
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

  Future<void> retryTask(String taskId) async {
    final taskIdx = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIdx == -1) return;
    final task = _tasks[taskIdx];
    if (task.status != DownloadStatus.failed) return;

    task.status = DownloadStatus.pending;
    task.progress = 0.0;
    task.speed = 'Retrying...';
    task.error = null;
    await _storage.saveTask(task);
    _loadTasks();

    final meta = MediaMetadata(
      url: task.url,
      title: task.title,
      author: '',
      duration: Duration.zero,
      thumbnailUrl: task.thumbnail,
      sourceType: task.url.contains('youtube') || task.url.contains('youtu.be') ? 'youtube' : 'instagram',
      formats: [
        FormatOption(
          id: task.selectedFormat,
          label: task.selectedFormat,
          ext: task.filePath?.split('.').last ?? 'mp4',
          sizeLabel: 'Unknown',
          qualityValue: 0,
          isAudioOnly: task.type == DownloadType.audio,
          originalStreamInfo: task.url,
        ),
      ],
    );

    _analyzedMetadata = meta;
    notifyListeners();
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

  bool get smartModeEnabled => _storage.getSmartModeEnabled();

  Future<void> setSmartModeEnabled(bool enabled) async {
    await _storage.saveSmartModeEnabled(enabled);
    notifyListeners();
  }

  String? getPreferredFormat(String sourceType) {
    return _storage.getPreferredFormat(sourceType);
  }

  Future<void> savePreferredFormat(String sourceType, String formatId) async {
    await _storage.savePreferredFormat(sourceType, formatId);
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
