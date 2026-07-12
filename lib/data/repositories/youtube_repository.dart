import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/format_option.dart';
import '../models/media_metadata.dart';

class YoutubeRepository {
  final _yt = YoutubeExplode();

  Future<MediaMetadata?> getMetadata(String url) async {
    try {
      final videoId = VideoId.parseVideoId(url);
      if (videoId == null) return null;

      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      final List<FormatOption> formats = [];

      // 1. Progressive streams (Video + Audio combined, max 720p)
      for (var stream in manifest.muxed) {
        final size = stream.size.totalMegaBytes.toStringAsFixed(1);
        formats.add(FormatOption(
          id: 'muxed_${stream.tag}',
          label: 'Video ${stream.videoQualityLabel} (MP4 - Fast)',
          ext: 'mp4',
          sizeLabel: '$size MB',
          qualityValue: _parseQuality(stream.videoQualityLabel),
          isAudioOnly: false,
          originalStreamInfo: stream,
        ));
      }

      // 2. Video-only streams (For HD 1080p, 1440p, 2160p)
      // Only keep mp4 container for easier merging, or webm if mp4 not present
      for (var stream in manifest.videoOnly) {
        final size = stream.size.totalMegaBytes.toStringAsFixed(1);
        final isMp4 = stream.container.toString().contains('mp4');
        
        formats.add(FormatOption(
          id: 'video_only_${stream.tag}',
          label: 'Video ${stream.videoQualityLabel} (HD - Needs Muxing)${isMp4 ? "" : " [WEBM]"}',
          ext: isMp4 ? 'mp4' : 'webm',
          sizeLabel: '$size MB + audio',
          qualityValue: _parseQuality(stream.videoQualityLabel),
          isAudioOnly: false,
          originalStreamInfo: stream,
        ));
      }

      // 3. Audio-only streams
      for (var stream in manifest.audioOnly) {
        final size = stream.size.totalMegaBytes.toStringAsFixed(1);
        final bitrate = stream.bitrate.kiloBitsPerSecond.round();
        final isM4a = stream.container.toString().contains('m4a');

        // Option 3a: Direct download in natural format (m4a or webm)
        formats.add(FormatOption(
          id: 'audio_raw_${stream.tag}',
          label: 'Audio ${bitrate}kbps (${isM4a ? "M4A" : "WEBM"})',
          ext: isM4a ? 'm4a' : 'webm',
          sizeLabel: '$size MB',
          qualityValue: bitrate,
          isAudioOnly: true,
          originalStreamInfo: stream,
        ));

        // Option 3b: Transcoded MP3 option
        formats.add(FormatOption(
          id: 'audio_mp3_${stream.tag}',
          label: 'Audio ${bitrate}kbps (MP3 Conversion)',
          ext: 'mp3',
          sizeLabel: '$size MB',
          qualityValue: bitrate,
          isAudioOnly: true,
          originalStreamInfo: stream,
        ));
      }

      // Sort: Videos first (highest resolution), then Audios (highest bitrate)
      formats.sort((a, b) {
        if (a.isAudioOnly != b.isAudioOnly) {
          // Videos first
          return a.isAudioOnly ? 1 : -1;
        }
        // Higher quality first
        return b.qualityValue.compareTo(a.qualityValue);
      });

      return MediaMetadata(
        url: url,
        title: video.title,
        author: video.author,
        duration: video.duration ?? Duration.zero,
        thumbnailUrl: video.thumbnails.highResUrl,
        sourceType: 'youtube',
        formats: formats,
      );
    } catch (e) {
      print('YouTube getMetadata error: $e');
      return null;
    }
  }

  int _parseQuality(String qualityLabel) {
    final numString = qualityLabel.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(numString) ?? 0;
  }

  void close() {
    _yt.close();
  }
}
