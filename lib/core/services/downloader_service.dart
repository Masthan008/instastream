import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import '../../data/models/download_task.dart';
import '../../data/models/format_option.dart';
import '../../data/models/media_metadata.dart';
import 'ffmpeg_service.dart';
import 'storage_service.dart';

class DownloaderService {
  final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    followRedirects: true,
    maxRedirects: 5,
  ));
  final FFmpegService _ffmpeg = FFmpegService();
  final StorageService _storage;

  // Active tasks map to manage cancellations
  final Map<String, CancelToken> _cancelTokens = {};

  // Queue for managing concurrent downloads
  final List<QueuedDownload> _queue = [];
  final Set<String> _activeTaskIds = {};

  static const _scannerChannel = MethodChannel('com.instastream.app/media_scanner');

  Future<void> _scanFile(String path) async {
    try {
      if (Platform.isAndroid) {
        await _scannerChannel.invokeMethod('scanFile', {'path': path});
      }
    } catch (e) {
      print('Media scanner failed to scan $path: $e');
    }
  }

  Future<void> _markTaskCompleted({
    required DownloadTask task,
    required String path,
    required Function(DownloadTask) onProgressUpdate,
  }) async {
    task.status = DownloadStatus.completed;
    task.filePath = path;
    task.progress = 1.0;
    task.speed = 'Done';
    await _storage.saveTask(task);
    onProgressUpdate(task);
    await _scanFile(path);
  }

  DownloaderService(this._storage);

  Future<void> download({
    required MediaMetadata metadata,
    required FormatOption format,
    required Function(DownloadTask) onProgressUpdate,
  }) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final type = format.isAudioOnly ? DownloadType.audio : DownloadType.video;
    
    final task = DownloadTask(
      id: taskId,
      url: metadata.url,
      title: metadata.title,
      thumbnail: metadata.thumbnailUrl,
      type: type,
      selectedFormat: format.label,
      status: DownloadStatus.pending,
      speed: 'Queued...',
      eta: '--:--',
    );

    await _storage.saveTask(task);
    onProgressUpdate(task);

    _queue.add(QueuedDownload(
      metadata: metadata,
      format: format,
      onProgressUpdate: onProgressUpdate,
      taskId: taskId,
    ));

    _processQueue();
  }

  void _processQueue() {
    final maxConcurrent = _storage.getMaxConcurrentDownloads();
    while (_activeTaskIds.length < maxConcurrent && _queue.isNotEmpty) {
      final queuedItem = _queue.removeAt(0);
      _activeTaskIds.add(queuedItem.taskId);
      _executeDownload(queuedItem);
    }
  }

  Future<void> _executeDownload(QueuedDownload item) async {
    final taskId = item.taskId;
    final metadata = item.metadata;
    final format = item.format;
    final onProgressUpdate = item.onProgressUpdate;

    final type = format.isAudioOnly ? DownloadType.audio : DownloadType.video;
    
    final task = DownloadTask(
      id: taskId,
      url: metadata.url,
      title: metadata.title,
      thumbnail: metadata.thumbnailUrl,
      type: type,
      selectedFormat: format.label,
      status: DownloadStatus.downloading,
    );

    await _storage.saveTask(task);
    onProgressUpdate(task);

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    try {
      Directory downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download/InstaStream');
        try {
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          final testFile = File('${downloadsDir.path}/.test_write_${DateTime.now().millisecondsSinceEpoch}');
          await testFile.writeAsString('test');
          await testFile.delete();
        } catch (_) {
          final baseDir = await getExternalStorageDirectory();
          if (baseDir != null) {
            downloadsDir = Directory('${baseDir.path}/InstaStream');
          } else {
            final docDir = await getApplicationDocumentsDirectory();
            downloadsDir = Directory('${docDir.path}/InstaStream');
          }
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
        }
      } else {
        final baseDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory('${baseDir.path}/InstaStream');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
      }

      // Safe filename (remove unsupported characters)
      final cleanTitle = metadata.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      if (metadata.sourceType == 'youtube') {
        dynamic ytStream = format.originalStreamInfo;

        if (format.id.startsWith('playlist_')) {
          task.status = DownloadStatus.downloading;
          task.speed = 'Fetching stream...';
          await _storage.saveTask(task);
          onProgressUpdate(task);

          final yt = yt_exp.YoutubeExplode();
          final videoUrl = format.originalStreamInfo as String;
          final videoId = yt_exp.VideoId.parseVideoId(videoUrl)!;
          final manifest = await yt.videos.streamsClient.getManifest(videoId);

          if (format.id.startsWith('playlist_audio_')) {
            ytStream = manifest.audioOnly.withHighestBitrate();
          } else {
            if (manifest.muxed.isNotEmpty) {
              final muxedList = List<yt_exp.MuxedStreamInfo>.from(manifest.muxed);
              muxedList.sort((a, b) => b.size.compareTo(a.size));
              ytStream = muxedList.first;
            } else {
              ytStream = null;
            }
          }
          yt.close();
        }

        if (format.id.startsWith('muxed_') || format.id.startsWith('playlist_video_')) {
          // Progressive stream - direct download
          final outputPath = '${downloadsDir.path}/$cleanTitle.${format.ext}';
          await _downloadYoutubeStream(
            streamInfo: ytStream as yt_exp.StreamInfo,
            savePath: outputPath,
            cancelToken: cancelToken,
            onProgress: (prog, speed, eta) async {
              task.progress = prog;
              task.speed = speed;
              task.eta = eta;
              await _storage.saveTask(task);
              onProgressUpdate(task);
            },
          );

          await _markTaskCompleted(
            task: task,
            path: outputPath,
            onProgressUpdate: onProgressUpdate,
          );

        } else if (format.id.startsWith('video_only_')) {
          // HD stream - requires video-only + audio-only + ffmpeg merging
          task.status = DownloadStatus.downloading;
          task.speed = 'Fetching audio track...';
          await _storage.saveTask(task);
          onProgressUpdate(task);

          final yt = yt_exp.YoutubeExplode();
          final videoId = yt_exp.VideoId.parseVideoId(metadata.url);
          if (videoId == null) {
            task.status = DownloadStatus.failed;
            task.error = 'Could not parse video ID from URL';
            await _storage.saveTask(task);
            onProgressUpdate(task);
            yt.close();
            return;
          }
          final manifest = await yt.videos.streamsClient.getManifest(videoId);
          final bestAudio = manifest.audioOnly.withHighestBitrate();
          yt.close();

          // Use correct extensions matching the actual stream container format
          final videoStreamInfo = ytStream as yt_exp.VideoStreamInfo;
          final audioStreamInfo = bestAudio;
          final videoContainer = videoStreamInfo.container.toString();
          final audioContainer = audioStreamInfo.container.toString();
          final videoExt = videoContainer.contains('webm') ? 'webm' : 'mp4';
          final audioExt = audioContainer.contains('webm') ? 'webm' : 'm4a';

          final tempVideoPath = '${downloadsDir.path}/${taskId}_temp_video.$videoExt';
          final tempAudioPath = '${downloadsDir.path}/${taskId}_temp_audio.$audioExt';
          final finalOutputPath = '${downloadsDir.path}/$cleanTitle.mp4';

          // 1. Download video track
          await _downloadYoutubeStream(
            streamInfo: videoStreamInfo,
            savePath: tempVideoPath,
            cancelToken: cancelToken,
            onProgress: (prog, speed, eta) async {
              task.progress = prog * 0.7;
              task.speed = 'Video: $speed';
              task.eta = eta;
              await _storage.saveTask(task);
              onProgressUpdate(task);
            },
          );

          // 2. Download audio track
          await _downloadYoutubeStream(
            streamInfo: audioStreamInfo,
            savePath: tempAudioPath,
            cancelToken: cancelToken,
            onProgress: (prog, speed, eta) async {
              task.progress = 0.7 + (prog * 0.2);
              task.speed = 'Audio: $speed';
              task.eta = eta;
              await _storage.saveTask(task);
              onProgressUpdate(task);
            },
          );

          // 3. Mux streams using FFmpeg
          task.status = DownloadStatus.processing;
          task.speed = 'Muxing streams...';
          task.progress = 0.95;
          await _storage.saveTask(task);
          onProgressUpdate(task);

          final bool success;
          if (videoExt == 'webm') {
            // VP9/webm video cannot be stream-copied into MP4; re-encode video
            success = await _ffmpeg.mergeVideoAndAudio(
              videoPath: tempVideoPath,
              audioPath: tempAudioPath,
              outputPath: finalOutputPath,
              reencodeVideo: true,
            );
          } else {
            success = await _ffmpeg.mergeVideoAndAudio(
              videoPath: tempVideoPath,
              audioPath: tempAudioPath,
              outputPath: finalOutputPath,
            );
          }

          try {
            await File(tempVideoPath).delete();
            await File(tempAudioPath).delete();
          } catch (_) {}

          if (success) {
            await _markTaskCompleted(
              task: task,
              path: finalOutputPath,
              onProgressUpdate: onProgressUpdate,
            );
          } else {
            task.status = DownloadStatus.failed;
            task.error = 'FFmpeg merging failed';
            await _storage.saveTask(task);
            onProgressUpdate(task);
          }

        } else if (format.id.startsWith('audio_raw_')) {
          // Direct raw audio download
          final outputPath = '${downloadsDir.path}/$cleanTitle.${format.ext}';
          await _downloadYoutubeStream(
            streamInfo: ytStream as yt_exp.StreamInfo,
            savePath: outputPath,
            cancelToken: cancelToken,
            onProgress: (prog, speed, eta) async {
              task.progress = prog;
              task.speed = speed;
              task.eta = eta;
              await _storage.saveTask(task);
              onProgressUpdate(task);
            },
          );

          await _markTaskCompleted(
            task: task,
            path: outputPath,
            onProgressUpdate: onProgressUpdate,
          );

        } else if (format.id.startsWith('audio_mp3_') || format.id.startsWith('playlist_audio_')) {
          // Audio download + MP3 conversion
          final tempAudioPath = '${downloadsDir.path}/${taskId}_temp_audio.m4a';
          final finalOutputPath = '${downloadsDir.path}/$cleanTitle.mp3';
          await _downloadYoutubeStream(
            streamInfo: ytStream as yt_exp.StreamInfo,
            savePath: tempAudioPath,
            cancelToken: cancelToken,
            onProgress: (prog, speed, eta) async {
              task.progress = prog * 0.8;
              task.speed = 'Downloading audio: $speed';
              task.eta = eta;
              await _storage.saveTask(task);
              onProgressUpdate(task);
            },
          );

          // Convert to MP3
          task.status = DownloadStatus.processing;
          task.speed = 'Converting to MP3...';
          task.progress = 0.9;
          await _storage.saveTask(task);
          onProgressUpdate(task);

          final success = await _ffmpeg.convertToMp3(
            inputPath: tempAudioPath,
            outputPath: finalOutputPath,
            bitrateKbps: format.qualityValue,
          );

          try {
            await File(tempAudioPath).delete();
          } catch (_) {}

          if (success) {
            await _markTaskCompleted(
              task: task,
              path: finalOutputPath,
              onProgressUpdate: onProgressUpdate,
            );
          } else {
            task.status = DownloadStatus.failed;
            task.error = 'MP3 transcoding failed';
            await _storage.saveTask(task);
            onProgressUpdate(task);
          }
        } else if (format.id.startsWith('subtitles_')) {
          // Download and parse YouTube Subtitles
          task.status = DownloadStatus.downloading;
          task.progress = 0.3;
          task.speed = 'Fetching subtitles...';
          await _storage.saveTask(task);
          onProgressUpdate(task);

          final yt = yt_exp.YoutubeExplode();
          final trackInfo = format.originalStreamInfo as yt_exp.ClosedCaptionTrackInfo;
          final closedCaptions = await yt.videos.closedCaptions.get(trackInfo);
          yt.close();

          final srtContent = _convertToSrt(closedCaptions.captions);

          final finalOutputPath = '${downloadsDir.path}/$cleanTitle.${trackInfo.language.code}.srt';
          final srtFile = File(finalOutputPath);
          await srtFile.writeAsString(srtContent);

          await _markTaskCompleted(
            task: task,
            path: finalOutputPath,
            onProgressUpdate: onProgressUpdate,
          );
        }

      } else if (metadata.sourceType == 'instagram') {
        final directLink = format.originalStreamInfo as String;
        final isVideoUrl = directLink.contains('.mp4') || format.ext == 'mp4';
        final Map<String, dynamic> igHeaders = {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': isVideoUrl ? 'video/mp4,*/*' : '*/*',
          'Accept-Encoding': 'gzip, deflate',
          'Referer': 'https://www.instagram.com/',
          'Origin': 'https://www.instagram.com',
          'Sec-Fetch-Dest': isVideoUrl ? 'video' : 'image',
          'Sec-Fetch-Mode': 'no-cors',
          'Sec-Fetch-Site': 'cross-site',
          'Connection': 'keep-alive',
        };
        // Use longer timeouts for Instagram (larger files, slower CDN)
        final igOptions = Options(
          headers: igHeaders,
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
        );

        if (format.id.contains('mp3')) {
          // Download video + convert to audio (MP3)
          final tempVideoPath = '${downloadsDir.path}/${taskId}_temp_video.mp4';
          final finalOutputPath = '${downloadsDir.path}/$cleanTitle.mp3';

          await _downloadFile(
            url: directLink,
            savePath: tempVideoPath,
            cancelToken: cancelToken,
            customOptions: igOptions,
            onProgress: (prog, speed, eta) async {
              task.progress = prog * 0.8;
              task.speed = 'Downloading video: $speed';
              task.eta = eta;
              await _storage.saveTask(task);
              onProgressUpdate(task);
            },
          );

          task.status = DownloadStatus.processing;
          task.speed = 'Extracting audio...';
          task.progress = 0.9;
          await _storage.saveTask(task);
          onProgressUpdate(task);

          final success = await _ffmpeg.convertToMp3(
            inputPath: tempVideoPath,
            outputPath: finalOutputPath,
            bitrateKbps: 256,
          );

          try {
            await File(tempVideoPath).delete();
          } catch (_) {}

          if (success) {
            await _markTaskCompleted(
              task: task,
              path: finalOutputPath,
              onProgressUpdate: onProgressUpdate,
            );
          } else {
            task.status = DownloadStatus.failed;
            task.error = 'Audio extraction failed';
            await _storage.saveTask(task);
            onProgressUpdate(task);
          }

        } else {
          // Direct download (video MP4 or image JPG)
          final outputPath = '${downloadsDir.path}/$cleanTitle.${format.ext}';
          
          await _downloadFile(
            url: directLink,
            savePath: outputPath,
            cancelToken: cancelToken,
            customOptions: igOptions,
            onProgress: (prog, speed, eta) async {
              task.progress = prog;
              task.speed = speed;
              task.eta = eta;
              await _storage.saveTask(task);
              onProgressUpdate(task);
            },
          );

          await _markTaskCompleted(
            task: task,
            path: outputPath,
            onProgressUpdate: onProgressUpdate,
          );
        }
      }
    } catch (e) {
      print('Download error: $e');
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      await _storage.saveTask(task);
      onProgressUpdate(task);
    } finally {
      _cancelTokens.remove(taskId);
      _activeTaskIds.remove(taskId);
      _processQueue();
    }
  }

  Future<void> _downloadFile({
    required String url,
    required String savePath,
    required CancelToken cancelToken,
    required Function(double progress, String speed, String eta) onProgress,
    Map<String, dynamic>? headers,
    Options? customOptions,
  }) async {
    final startTime = DateTime.now();
    
    final effectiveOptions = customOptions ?? Options(headers: headers);

    await _dio.download(
      url,
      savePath,
      cancelToken: cancelToken,
      options: effectiveOptions,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final elapsed = DateTime.now().difference(startTime).inMilliseconds;
          if (elapsed > 0) {
            final double speedBytesPerMs = received / elapsed;
            final double speedMbps = (speedBytesPerMs * 1000) / (1024 * 1024);
            final String speedLabel = '${speedMbps.toStringAsFixed(1)} MB/s';

            final double progress = (total > 0) ? (received / total).clamp(0.0, 1.0) : 0.0;
            final remainingBytes = total - received;
            final etaSeconds = speedBytesPerMs > 0 ? (remainingBytes / speedBytesPerMs / 1000).round() : 0;
            final String etaLabel = _formatDuration(Duration(seconds: etaSeconds));

            onProgress(progress, speedLabel, etaLabel);
          }
        }
      },
    );
  }

  Future<void> _downloadYoutubeStream({
    required yt_exp.StreamInfo streamInfo,
    required String savePath,
    required CancelToken cancelToken,
    required Function(double progress, String speed, String eta) onProgress,
  }) async {
    final yt = yt_exp.YoutubeExplode();
    final stream = yt.videos.streamsClient.get(streamInfo);
    
    final file = File(savePath);
    if (await file.exists()) {
      await file.delete();
    }
    
    final output = file.openWrite(mode: FileMode.writeOnlyAppend);
    final int totalBytes = streamInfo.size.totalBytes;
    int receivedBytes = 0;
    final startTime = DateTime.now();

    try {
      await for (final data in stream) {
        if (cancelToken.isCancelled) {
          await output.close();
          yt.close();
          return;
        }
        output.add(data);
        receivedBytes += data.length;

        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (elapsed > 0) {
          final double speedBytesPerMs = receivedBytes / elapsed;
          final double speedMbps = (speedBytesPerMs * 1000) / (1024 * 1024);
          final String speedLabel = '${speedMbps.toStringAsFixed(1)} MB/s';
          
          final double progress = (totalBytes > 0) ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
          final remainingBytes = totalBytes - receivedBytes;
          final etaSeconds = speedBytesPerMs > 0 ? (remainingBytes / speedBytesPerMs / 1000).round() : 0;
          final String etaLabel = _formatDuration(Duration(seconds: etaSeconds));

          onProgress(progress, speedLabel, etaLabel);
        }
      }
    } finally {
      await output.close();
      yt.close();
    }
  }

  void cancelDownload(String taskId) {
    _activeTaskIds.remove(taskId);
    _queue.removeWhere((item) => item.taskId == taskId);

    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]!.cancel();
      _cancelTokens.remove(taskId);
    }

    _processQueue();
  }

  String _formatDuration(Duration duration) {
    final mins = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _convertToSrt(List<yt_exp.ClosedCaption> captions) {
    final buffer = StringBuffer();
    for (int i = 0; i < captions.length; i++) {
      final caption = captions[i];
      final start = caption.offset;
      final end = caption.offset + caption.duration;

      buffer.writeln('${i + 1}');
      buffer.writeln('${_formatSrtTime(start)} --> ${_formatSrtTime(end)}');
      buffer.writeln(caption.text);
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _formatSrtTime(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }
}

class QueuedDownload {
  final MediaMetadata metadata;
  final FormatOption format;
  final Function(DownloadTask) onProgressUpdate;
  final String taskId;

  QueuedDownload({
    required this.metadata,
    required this.format,
    required this.onProgressUpdate,
    required this.taskId,
  });
}
