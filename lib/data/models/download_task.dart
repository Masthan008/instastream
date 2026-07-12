import 'dart:convert';

enum DownloadType { video, audio, image }
enum DownloadStatus { pending, downloading, processing, completed, failed, paused }

class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String thumbnail;
  final DownloadType type;
  final String selectedFormat; // e.g., '1080p', '720p', '320kbps MP3', 'M4A'
  DownloadStatus status;
  double progress; // 0.0 to 1.0
  String speed;    // e.g. '2.4 MB/s'
  String eta;      // e.g. '00:15'
  String? filePath;
  String? error;
  final DateTime createdAt;

  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.thumbnail,
    required this.type,
    required this.selectedFormat,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.speed = '0 KB/s',
    this.eta = '--:--',
    this.filePath,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'thumbnail': thumbnail,
      'type': type.index,
      'selectedFormat': selectedFormat,
      'status': status.index,
      'progress': progress,
      'speed': speed,
      'eta': eta,
      'filePath': filePath,
      'error': error,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DownloadTask.fromMap(Map<dynamic, dynamic> map) {
    return DownloadTask(
      id: map['id'] as String,
      url: map['url'] as String,
      title: map['title'] as String,
      thumbnail: map['thumbnail'] as String,
      type: DownloadType.values[map['type'] as int],
      selectedFormat: map['selectedFormat'] as String,
      status: DownloadStatus.values[map['status'] as int],
      progress: (map['progress'] as num).toDouble(),
      speed: map['speed'] as String,
      eta: map['eta'] as String,
      filePath: map['filePath'] as String?,
      error: map['error'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory DownloadTask.fromJson(String source) =>
      DownloadTask.fromMap(json.decode(source) as Map<String, dynamic>);
}
