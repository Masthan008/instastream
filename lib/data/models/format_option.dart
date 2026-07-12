class FormatOption {
  final String id;
  final String label;
  final String ext;          // e.g. 'mp4', 'mp3', 'm4a'
  final String sizeLabel;    // e.g. '24.5 MB', 'Unknown'
  final int qualityValue;    // e.g. 1080, 720, 320 (bitrate), 128 (bitrate)
  final bool isAudioOnly;
  final dynamic originalStreamInfo; // Holds the YouTube MuxedStreamInfo, VideoStreamInfo, or AudioStreamInfo if applicable

  FormatOption({
    required this.id,
    required this.label,
    required this.ext,
    required this.sizeLabel,
    required this.qualityValue,
    required this.isAudioOnly,
    this.originalStreamInfo,
  });
}
