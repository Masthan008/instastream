import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import '../../data/models/download_task.dart';
import '../../data/models/format_option.dart';
import '../../data/models/media_metadata.dart';
import 'ffmpeg_service.dart';
import 'storage_service.dart';

class DownloaderService {
  final Dio _dio = Dio();
  final FFmpegService _ffmpeg = FFmpegService();
  final StorageService _storage;

  // Active tasks map to manage cancellations
  final Map<String, CancelToken> _cancelTokens = {};

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
      status: DownloadStatus.downloading,
    );

    await _storage.saveTask(task);
    onProgressUpdate(task);

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    try {
      // Save directly to public Downloads folder on Android, sandboxed on iOS
      Directory downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download/InstaStream');
      } else {
        final baseDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory('${baseDir.path}/InstaStream');
      }
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Safe filename (remove unsupported characters)
      final cleanTitle = metadata.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      if (metadata.sourceType == 'youtube') {
        final ytStream = format.originalStreamInfo;
        
        if (format.id.startsWith('muxed_')) {
          // Progressive stream - direct download
          final outputPath = '${downloadsDir.path}/$cleanTitle.${format.ext}';
          final streamUrl = (ytStream as yt_exp.MuxedStreamInfo).url.toString();
          
          await _downloadFile(
            url: streamUrl,
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

          task.status = DownloadStatus.completed;
          task.filePath = outputPath;
          task.progress = 1.0;
          task.speed = 'Done';
          await _storage.saveTask(task);
          onProgressUpdate(task);

        } else if (format.id.startsWith('video_only_')) {
          // HD stream - requires video-only + audio-only + ffmpeg merging
          task.status = DownloadStatus.downloading;
          task.speed = 'Fetching audio track...';
          await _storage.saveTask(task);
          onProgressUpdate(task);

          final yt = yt_exp.YoutubeExplode();
          final videoId = yt_exp.VideoId.parseVideoId(metadata.url)!;
          final manifest = await yt.videos.streamsClient.getManifest(videoId);
          final bestAudio = manifest.audioOnly.withHighestBitrate();
          yt.close();

          final tempVideoPath = '${downloadsDir.path}/${taskId}_temp_video.mp4';
          final tempAudioPath = '${downloadsDir.path}/${taskId}_temp_audio.m4a';
          final finalOutputPath = '${downloadsDir.path}/$cleanTitle.mp4';

          // 1. Download video track
          final videoStreamUrl = (ytStream as yt_exp.VideoStreamInfo).url.toString();
          await _downloadFile(
            url: videoStreamUrl,
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
          final audioStreamUrl = bestAudio.url.toString();
          await _downloadFile(
            url: audioStreamUrl,
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

          final success = await _ffmpeg.mergeVideoAndAudio(
            videoPath: tempVideoPath,
            audioPath: tempAudioPath,
            outputPath: finalOutputPath,
          );

          try {
            await File(tempVideoPath).delete();
            await File(tempAudioPath).delete();
          } catch (_) {}

          if (success) {
            task.status = DownloadStatus.completed;
            task.filePath = finalOutputPath;
            task.progress = 1.0;
            task.speed = 'Done';
          } else {
            task.status = DownloadStatus.failed;
            task.error = 'FFmpeg merging failed';
          }
          await _storage.saveTask(task);
          onProgressUpdate(task);

        } else if (format.id.startsWith('audio_raw_')) {
          // Direct raw audio download
          final outputPath = '${downloadsDir.path}/$cleanTitle.${format.ext}';
          final streamUrl = (ytStream as yt_exp.AudioStreamInfo).url.toString();
          
          await _downloadFile(
            url: streamUrl,
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

          task.status = DownloadStatus.completed;
          task.filePath = outputPath;
          task.progress = 1.0;
          task.speed = 'Done';
          await _storage.saveTask(task);
          onProgressUpdate(task);

        } else if (format.id.startsWith('audio_mp3_')) {
          // Audio download + MP3 conversion
          final tempAudioPath = '${downloadsDir.path}/${taskId}_temp_audio.m4a';
          final finalOutputPath = '${downloadsDir.path}/$cleanTitle.mp3';
          final streamUrl = (ytStream as yt_exp.AudioStreamInfo).url.toString();

          await _downloadFile(
            url: streamUrl,
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
            task.status = DownloadStatus.completed;
            task.filePath = finalOutputPath;
            task.progress = 1.0;
            task.speed = 'Done';
          } else {
            task.status = DownloadStatus.failed;
            task.error = 'MP3 transcoding failed';
          }
          await _storage.saveTask(task);
          onProgressUpdate(task);
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

          task.status = DownloadStatus.completed;
          task.filePath = finalOutputPath;
          task.progress = 1.0;
          task.speed = 'Done';
          await _storage.saveTask(task);
          onProgressUpdate(task);
        }

      } else if (metadata.sourceType == 'instagram') {
        final directLink = format.originalStreamInfo as String;

        if (format.id.contains('mp3')) {
          // Download video + convert to audio (MP3)
          final tempVideoPath = '${downloadsDir.path}/${taskId}_temp_video.mp4';
          final finalOutputPath = '${downloadsDir.path}/$cleanTitle.mp3';

          await _downloadFile(
            url: directLink,
            savePath: tempVideoPath,
            cancelToken: cancelToken,
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
            task.status = DownloadStatus.completed;
            task.filePath = finalOutputPath;
            task.progress = 1.0;
            task.speed = 'Done';
          } else {
            task.status = DownloadStatus.failed;
            task.error = 'Audio extraction failed';
          }
          await _storage.saveTask(task);
          onProgressUpdate(task);

        } else {
          // Direct download (video MP4 or image JPG)
          final outputPath = '${downloadsDir.path}/$cleanTitle.${format.ext}';
          
          await _downloadFile(
            url: directLink,
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

          task.status = DownloadStatus.completed;
          task.filePath = outputPath;
          task.progress = 1.0;
          task.speed = 'Done';
          await _storage.saveTask(task);
          onProgressUpdate(task);
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
    }
  }

  Future<void> _downloadFile({
    required String url,
    required String savePath,
    required CancelToken cancelToken,
    required Function(double progress, String speed, String eta) onProgress,
  }) async {
    final startTime = DateTime.now();
    
    await _dio.download(
      url,
      savePath,
      cancelToken: cancelToken,
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

  void cancelDownload(String taskId) {
    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]!.cancel();
      _cancelTokens.remove(taskId);
    }
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
