import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/theme.dart';
import '../../data/models/download_task.dart';
import '../../core/services/ffmpeg_service.dart';
import '../providers/download_provider.dart';
import '../widgets/custom_audio_player.dart';
import '../widgets/custom_video_player.dart';
import '../widgets/glassmorphic_card.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({Key? key}) : super(key: key);

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _showVideos = true;
  String? _currentlyPlayingAudioPath;
  String? _currentlyPlayingAudioTitle;
  final FFmpegService _ffmpeg = FFmpegService();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DownloadProvider>(context);
    
    final completedTasks = provider.tasks
        .where((t) => t.status == DownloadStatus.completed && t.filePath != null)
        .toList();
        
    final filteredTasks = completedTasks.where((t) {
      if (_showVideos) {
        return t.type == DownloadType.video;
      } else {
        return t.type == DownloadType.audio;
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Gallery',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildToggleBtn('Videos', _showVideos, () {
                      setState(() {
                        _showVideos = true;
                        _currentlyPlayingAudioPath = null;
                      });
                    }),
                    _buildToggleBtn('Audio', !_showVideos, () {
                      setState(() {
                        _showVideos = false;
                      });
                    }),
                  ],
                ),
              )
            ],
          ),
        ),

        if (!_showVideos && _currentlyPlayingAudioPath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: CustomAudioPlayer(
              key: ValueKey(_currentlyPlayingAudioPath),
              filePath: _currentlyPlayingAudioPath!,
              title: _currentlyPlayingAudioTitle ?? 'Audio Playback',
            ),
          ),

        Expanded(
          child: filteredTasks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    return _buildGalleryItem(task, provider);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? LiquidGlassTheme.brandGradient : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : LiquidGlassTheme.textLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showVideos ? Icons.video_library_outlined : Icons.audio_file_outlined,
            size: 64,
            color: LiquidGlassTheme.textLight.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            _showVideos ? 'No videos downloaded yet' : 'No audio files downloaded yet',
            style: const TextStyle(fontWeight: FontWeight.bold, color: LiquidGlassTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryItem(DownloadTask task, DownloadProvider provider) {
    final fileExists = File(task.filePath!).existsSync();
    final isYouTube = task.url.contains('youtube') || task.url.contains('youtu.be');

    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 80,
              color: Colors.black.withOpacity(0.04),
              child: task.thumbnail.isNotEmpty
                  ? Image.network(
                      task.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        task.type == DownloadType.video ? Icons.movie_creation : Icons.music_note,
                        color: LiquidGlassTheme.primaryBlue,
                      ),
                    )
                  : Icon(
                      task.type == DownloadType.video ? Icons.movie_creation : Icons.music_note,
                      color: LiquidGlassTheme.primaryBlue,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isYouTube ? Colors.red.withOpacity(0.1) : Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isYouTube ? 'YouTube' : 'Instagram',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isYouTube ? Colors.red : Colors.purple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.selectedFormat,
                        style: const TextStyle(fontSize: 11, color: LiquidGlassTheme.textLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LiquidGlassTheme.textDark),
                ),
                const SizedBox(height: 8),
                if (fileExists)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share_outlined, color: LiquidGlassTheme.primaryBlue, size: 20),
                        onPressed: () {
                          Share.shareXFiles([XFile(task.filePath!)], text: task.title);
                        },
                      ),
                      if (task.type == DownloadType.video)
                        IconButton(
                          icon: const Icon(Icons.music_note_outlined, color: LiquidGlassTheme.primaryGreen, size: 20),
                          tooltip: 'Convert to Audio',
                          onPressed: () {
                            _convertToAudio(task, provider);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          _showDeleteConfirm(context, task, provider);
                        },
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          if (task.type == DownloadType.video) {
                            _playVideo(task.filePath!, task.title);
                          } else {
                            setState(() {
                              _currentlyPlayingAudioPath = task.filePath;
                              _currentlyPlayingAudioTitle = task.title;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LiquidGlassTheme.brandGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Play', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'File not found or deleted physically.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  void _playVideo(String path, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Expanded(
                child: Center(
                  child: CustomVideoPlayer(filePath: path),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, DownloadTask task, DownloadProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete "${task.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: LiquidGlassTheme.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final file = File(task.filePath!);
                if (await file.exists()) {
                  await file.delete();
                }
              } catch (e) {
                print('Error deleting file physically: $e');
              }
              provider.deleteTask(task.id);
              if (_currentlyPlayingAudioPath == task.filePath) {
                setState(() {
                  _currentlyPlayingAudioPath = null;
                });
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _convertToAudio(DownloadTask task, DownloadProvider provider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: const Row(
              children: [
                CircularProgressIndicator(color: LiquidGlassTheme.primaryBlue),
                SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'Extracting Audio with FFmpeg...',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LiquidGlassTheme.textDark),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final inputPath = task.filePath!;
      final parentDir = File(inputPath).parent.path;
      final originalName = File(inputPath).path.split(Platform.isWindows ? '\\' : '/').last;
      final nameWithoutExt = originalName.contains('.')
          ? originalName.substring(0, originalName.lastIndexOf('.'))
          : originalName;
      final outputPath = '$parentDir/${nameWithoutExt}_extracted.mp3';

      final success = await _ffmpeg.convertToMp3(
        inputPath: inputPath,
        outputPath: outputPath,
        bitrateKbps: 256,
      );

      Navigator.pop(context); // Close loading dialog

      if (success) {
        // Register converted audio task in DB
        final newTask = DownloadTask(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          url: task.url,
          title: '${task.title} (Extracted Audio)',
          thumbnail: task.thumbnail,
          type: DownloadType.audio,
          selectedFormat: 'MP3 (Extracted)',
          status: DownloadStatus.completed,
          filePath: outputPath,
          progress: 1.0,
          speed: 'Converted',
        );

        await provider.addCompletedTask(newTask);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio successfully extracted and saved to Gallery!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to extract audio from video.')),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if crashed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error converting video: $e')),
      );
    }
  }
}
