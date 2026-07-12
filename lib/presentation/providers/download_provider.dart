import 'package:flutter/material.dart';
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

  DownloadProvider() {
    _downloader = DownloaderService(_storage);
    _init();
  }

  List<DownloadTask> get tasks => _tasks;
  bool get isAnalyzing => _isAnalyzing;
  MediaMetadata? get analyzedMetadata => _analyzedMetadata;
  String? get errorMessage => _errorMessage;

  Future<void> _init() async {
    await _storage.init();
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

  @override
  void dispose() {
    _ytRepo.close();
    super.dispose();
  }
}
