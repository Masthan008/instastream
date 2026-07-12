import 'format_option.dart';

class MediaMetadata {
  final String url;
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;
  final String sourceType; // 'youtube' or 'instagram'
  final List<FormatOption> formats;

  MediaMetadata({
    required this.url,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.sourceType,
    required this.formats,
  });

  String get durationString {
    if (duration == Duration.zero) return '--:--';
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
