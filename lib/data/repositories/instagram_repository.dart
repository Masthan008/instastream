import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../models/format_option.dart';
import '../models/media_metadata.dart';

class InstagramRepository {
  Future<MediaMetadata?> getMetadata(String url) async {
    try {
      final cleanUrl = _cleanInstagramUrl(url);
      final response = await http.get(
        Uri.parse(cleanUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        final ogVideo = document.querySelector('meta[property="og:video"]')?.attributes['content'];
        final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'];
        final ogTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'] ?? 'Instagram Post';
        final ogAuthor = document.querySelector('meta[property="og:description"]')?.attributes['content'] ?? 'Instagram User';

        if (ogVideo != null && ogVideo.isNotEmpty) {
          return MediaMetadata(
            url: url,
            title: _truncateTitle(ogTitle),
            author: _extractUsername(ogAuthor),
            duration: Duration.zero,
            thumbnailUrl: ogImage ?? '',
            sourceType: 'instagram',
            formats: [
              FormatOption(
                id: 'ig_video_high',
                label: 'Video (HD MP4)',
                ext: 'mp4',
                sizeLabel: 'Unknown Size',
                qualityValue: 720,
                isAudioOnly: false,
                originalStreamInfo: ogVideo,
              ),
              FormatOption(
                id: 'ig_audio_mp3',
                label: 'Audio (MP3 Conversion)',
                ext: 'mp3',
                sizeLabel: 'Unknown Size',
                qualityValue: 256,
                isAudioOnly: true,
                originalStreamInfo: ogVideo,
              )
            ],
          );
        } else if (ogImage != null && ogImage.isNotEmpty) {
          return MediaMetadata(
            url: url,
            title: _truncateTitle(ogTitle),
            author: _extractUsername(ogAuthor),
            duration: Duration.zero,
            thumbnailUrl: ogImage,
            sourceType: 'instagram',
            formats: [
              FormatOption(
                id: 'ig_image_high',
                label: 'Image (JPEG)',
                ext: 'jpg',
                sizeLabel: 'Unknown Size',
                qualityValue: 1080,
                isAudioOnly: false,
                originalStreamInfo: ogImage,
              )
            ],
          );
        }
      }
    } catch (e) {
      print('Instagram public scraping failed: $e');
    }
    return null;
  }

  MediaMetadata buildMetadataFromDirectLink({
    required String originalUrl,
    required String directLink,
    required bool isVideo,
    String? title,
    String? username,
    String? thumbnailUrl,
  }) {
    final formats = isVideo
        ? [
            FormatOption(
              id: 'ig_video_direct',
              label: 'Video (HD MP4)',
              ext: 'mp4',
              sizeLabel: 'Unknown Size',
              qualityValue: 720,
              isAudioOnly: false,
              originalStreamInfo: directLink,
            ),
            FormatOption(
              id: 'ig_audio_mp3_direct',
              label: 'Audio (MP3 Conversion)',
              ext: 'mp3',
              sizeLabel: 'Unknown Size',
              qualityValue: 256,
              isAudioOnly: true,
              originalStreamInfo: directLink,
            )
          ]
        : [
            FormatOption(
              id: 'ig_image_direct',
              label: 'Image (JPEG)',
              ext: 'jpg',
              sizeLabel: 'Unknown Size',
              qualityValue: 1080,
              isAudioOnly: false,
              originalStreamInfo: directLink,
            )
          ];

    return MediaMetadata(
      url: originalUrl,
      title: title != null && title.isNotEmpty ? _truncateTitle(title) : 'Instagram Media',
      author: username != null && username.isNotEmpty ? username : 'instagram_user',
      duration: Duration.zero,
      thumbnailUrl: thumbnailUrl ?? (isVideo ? '' : directLink),
      sourceType: 'instagram',
      formats: formats,
    );
  }

  MediaMetadata buildMetadataFromSlides({
    required String originalUrl,
    required List<Map<String, dynamic>> slides,
    required String title,
  }) {
    final List<FormatOption> formats = [];
    for (int i = 0; i < slides.length; i++) {
      final slide = slides[i];
      final url = slide['url'] as String;
      final isVideo = slide['type'] == 'video';

      if (isVideo) {
        formats.add(
          FormatOption(
            id: 'ig_slide_${i}_video',
            label: 'Slide ${i + 1} - Video (HD MP4)',
            ext: 'mp4',
            sizeLabel: 'Unknown Size',
            qualityValue: 720,
            isAudioOnly: false,
            originalStreamInfo: url,
          ),
        );
        formats.add(
          FormatOption(
            id: 'ig_slide_${i}_audio',
            label: 'Slide ${i + 1} - Audio (MP3)',
            ext: 'mp3',
            sizeLabel: 'Unknown Size',
            qualityValue: 256,
            isAudioOnly: true,
            originalStreamInfo: url,
          ),
        );
      } else {
        formats.add(
          FormatOption(
            id: 'ig_slide_${i}_image',
            label: 'Slide ${i + 1} - Image (JPEG)',
            ext: 'jpg',
            sizeLabel: 'Unknown Size',
            qualityValue: 1080,
            isAudioOnly: false,
            originalStreamInfo: url,
          ),
        );
      }
    }

    return MediaMetadata(
      url: originalUrl,
      title: title.isNotEmpty ? _truncateTitle(title) : 'Instagram Slideshow',
      author: 'instagram_user',
      duration: Duration.zero,
      thumbnailUrl: formats.isNotEmpty ? (formats.first.originalStreamInfo as String) : '',
      sourceType: 'instagram',
      formats: formats,
    );
  }

  String _cleanInstagramUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return 'https://${uri.host}${uri.path}';
    } catch (_) {
      return url;
    }
  }

  String _truncateTitle(String title) {
    if (title.length > 50) {
      return '${title.substring(0, 47)}...';
    }
    return title;
  }

  String _extractUsername(String desc) {
    final reg = RegExp(r'@([a-zA-Z0-9_\.]+)');
    final match = reg.firstMatch(desc);
    if (match != null) {
      return match.group(0) ?? 'instagram_user';
    }
    return 'instagram_user';
  }
}
