import 'dart:io';
import 'dart:math';
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
import 'package:audiotags/audiotags.dart' as at;

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
  bool _isShuffle = false;
  bool _isRepeat = false;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomAudioPlayer(
                  key: ValueKey(_currentlyPlayingAudioPath),
                  filePath: _currentlyPlayingAudioPath!,
                  title: _currentlyPlayingAudioTitle ?? 'Audio Playback',
                  onCompleted: () {
                    _playNextAudio(filteredTasks);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            color: _isShuffle ? LiquidGlassTheme.primaryGreen : Colors.grey,
                          ),
                          tooltip: 'Shuffle Play',
                          onPressed: () {
                            setState(() {
                              _isShuffle = !_isShuffle;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.repeat,
                            color: _isRepeat ? LiquidGlassTheme.primaryGreen : Colors.grey,
                          ),
                          tooltip: 'Repeat Playlist',
                          onPressed: () {
                            setState(() {
                              _isRepeat = !_isRepeat;
                            });
                          },
                        ),
                      ],
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: const Text('Next Track', style: TextStyle(fontSize: 12)),
                      onPressed: () => _playNextAudio(filteredTasks),
                    ),
                  ],
                ),
              ],
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
    final bool isYouTube = task.url.contains('youtube') || task.url.contains('youtu.be');
    final bool isWhatsApp = task.url.contains('whatsapp') || task.url == 'WhatsApp Status';
    
    final String platformLabel = isYouTube 
        ? 'YouTube' 
        : isWhatsApp 
            ? 'WhatsApp' 
            : 'Instagram';
            
    final Color platformColor = isYouTube 
        ? Colors.red 
        : isWhatsApp 
            ? Colors.green 
            : Colors.purple;

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
                  ? (task.thumbnail.startsWith('/') || task.thumbnail.startsWith('file://'))
                      ? Image.file(
                          File(task.thumbnail.replaceAll('file://', '')),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            task.type == DownloadType.video ? Icons.movie_creation : Icons.music_note,
                            color: LiquidGlassTheme.primaryBlue,
                          ),
                        )
                      : Image.network(
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
                        color: platformColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        platformLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: platformColor,
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
                      if (task.type == DownloadType.audio)
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: LiquidGlassTheme.primaryGreen, size: 22),
                          tooltip: 'Edit Tags',
                          onPressed: () {
                            _showTagEditor(context, task, provider);
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

  void _showTagEditor(BuildContext context, DownloadTask task, DownloadProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => _TagEditorDialog(task: task, provider: provider),
    );
  }

  void _playNextAudio(List<DownloadTask> playlist) {
    if (playlist.isEmpty) return;

    final currentIndex = playlist.indexWhere((t) => t.filePath == _currentlyPlayingAudioPath);
    if (currentIndex == -1) return;

    int nextIndex;
    if (_isShuffle && playlist.length > 1) {
      nextIndex = Random().nextInt(playlist.length);
      // Try to avoid playing the same track immediately
      if (nextIndex == currentIndex) {
        nextIndex = (nextIndex + 1) % playlist.length;
      }
    } else {
      nextIndex = currentIndex + 1;
    }

    if (nextIndex < playlist.length) {
      setState(() {
        _currentlyPlayingAudioPath = playlist[nextIndex].filePath;
        _currentlyPlayingAudioTitle = playlist[nextIndex].title;
      });
    } else {
      if (_isRepeat) {
        setState(() {
          _currentlyPlayingAudioPath = playlist[0].filePath;
          _currentlyPlayingAudioTitle = playlist[0].title;
        });
      } else {
        setState(() {
          _currentlyPlayingAudioPath = null;
        });
      }
    }
  }
}

class _TagEditorDialog extends StatefulWidget {
  final DownloadTask task;
  final DownloadProvider provider;

  const _TagEditorDialog({
    Key? key,
    required this.task,
    required this.provider,
  }) : super(key: key);

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _genreController;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _artistController = TextEditingController();
    _albumController = TextEditingController();
    _genreController = TextEditingController();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final tag = await at.AudioTags.read(widget.task.filePath!);
      if (tag != null) {
        setState(() {
          if (tag.title != null && tag.title!.isNotEmpty) {
            _titleController.text = tag.title!;
          }
          _artistController.text = tag.trackArtist ?? '';
          _albumController.text = tag.album ?? '';
          _genreController.text = tag.genre ?? '';
        });
      }
    } catch (e) {
      // Ignore reading errors, fallback to default title
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTags() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final tag = at.Tag(
        title: _titleController.text,
        trackArtist: _artistController.text,
        album: _albumController.text,
        genre: _genreController.text,
        pictures: const [],
      );
      await at.AudioTags.write(widget.task.filePath!, tag);

      // Update in Hive DB
      final updatedTask = DownloadTask(
        id: widget.task.id,
        url: widget.task.url,
        title: _titleController.text,
        thumbnail: widget.task.thumbnail,
        type: widget.task.type,
        selectedFormat: widget.task.selectedFormat,
        status: widget.task.status,
        progress: widget.task.progress,
        speed: widget.task.speed,
        eta: widget.task.eta,
        filePath: widget.task.filePath,
        error: widget.task.error,
        createdAt: widget.task.createdAt,
      );
      await widget.provider.addCompletedTask(updatedTask);

      Navigator.pop(context); // Close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID3 tags saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save ID3 tags: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: GlassmorphicCard(
        padding: const EdgeInsets.all(20),
        radius: 24,
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: LiquidGlassTheme.primaryBlue),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit MP3 Metadata',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : LiquidGlassTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Title', _titleController, isDark),
                  const SizedBox(height: 12),
                  _buildTextField('Artist', _artistController, isDark),
                  const SizedBox(height: 12),
                  _buildTextField('Album', _albumController, isDark),
                  const SizedBox(height: 12),
                  _buildTextField('Genre', _genreController, isDark),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: LiquidGlassTheme.textLight),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveTags,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LiquidGlassTheme.brandGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Save Tags',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDark) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: LiquidGlassTheme.textLight),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LiquidGlassTheme.primaryBlue, width: 1.5),
        ),
      ),
    );
  }
}

