import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme.dart';
import '../../data/models/download_task.dart';
import '../providers/download_provider.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/custom_video_player.dart';

class StatusSaverScreen extends StatefulWidget {
  const StatusSaverScreen({Key? key}) : super(key: key);

  @override
  State<StatusSaverScreen> createState() => _StatusSaverScreenState();
}

class _StatusSaverScreenState extends State<StatusSaverScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAndroid = false;
  bool _permissionGranted = false;
  bool _isLoading = false;
  List<File> _statuses = [];
  String? _errorMessage;

  final List<String> _statusPaths = [
    // Standard WhatsApp Status Folder (Android 11+)
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    // WhatsApp Business Status Folder (Android 11+)
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
    // Legacy Standard WhatsApp Status Folder (Android 10 & below)
    '/storage/emulated/0/WhatsApp/Media/.Statuses',
    // Legacy WhatsApp Business Status Folder (Android 10 & below)
    '/storage/emulated/0/WhatsApp Business/Media/.Statuses',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isAndroid = Platform.isAndroid;
    if (_isAndroid) {
      _checkPermissions();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    // Check if manageExternalStorage is granted (Android 11+)
    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) {
      setState(() {
        _permissionGranted = true;
      });
      _scanStatuses();
      return;
    }

    // Check if legacy storage is granted
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) {
      setState(() {
        _permissionGranted = true;
      });
      _scanStatuses();
      return;
    }

    // For Android 13+ check photos/videos permissions
    final photosStatus = await Permission.photos.status;
    final videosStatus = await Permission.videos.status;
    if (photosStatus.isGranted && videosStatus.isGranted) {
      setState(() {
        _permissionGranted = true;
      });
      _scanStatuses();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request manageExternalStorage first (Android 11+)
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) {
        setState(() {
          _permissionGranted = true;
          _errorMessage = null;
        });
        _scanStatuses();
        return;
      }

      // Try standard storage request
      final status = await Permission.storage.request();
      if (status.isGranted) {
        setState(() {
          _permissionGranted = true;
          _errorMessage = null;
        });
        _scanStatuses();
        return;
      }

      // Fallback for Android 13+
      final photos = await Permission.photos.request();
      final videos = await Permission.videos.request();
      if (photos.isGranted && videos.isGranted) {
        setState(() {
          _permissionGranted = true;
          _errorMessage = null;
        });
        _scanStatuses();
      } else {
        setState(() {
          _errorMessage = 'All Files Access / Storage permission is required to fetch local WhatsApp statuses.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Permission request failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanStatuses() async {
    setState(() {
      _isLoading = true;
      _statuses.clear();
      _errorMessage = null;
    });

    try {
      bool folderFound = false;
      for (final path in _statusPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          folderFound = true;
          final files = dir.listSync();
          for (final entity in files) {
            if (entity is File) {
              final filename = entity.path.toLowerCase();
              if (filename.endsWith('.jpg') ||
                  filename.endsWith('.jpeg') ||
                  filename.endsWith('.png') ||
                  filename.endsWith('.mp4')) {
                _statuses.add(entity);
              }
            }
          }
        }
      }

      if (!folderFound) {
        setState(() {
          _errorMessage = 'No WhatsApp status folder found. Please view some statuses in WhatsApp first.';
        });
      } else {
        // Sort files by last modified date (newest first)
        _statuses.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error scanning statuses: $e. Try opening WhatsApp, view some statuses, then return here.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToGallery(File file, DownloadProvider provider) async {
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

      final originalName = file.path.split('/').last;
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_$originalName';
      final newPath = '${downloadsDir.path}/$uniqueName';

      // Copy status file
      await file.copy(newPath);

      // Notify Android Media Store Scanner
      try {
        if (Platform.isAndroid) {
          await const MethodChannel('com.instastream.app/media_scanner')
              .invokeMethod('scanFile', {'path': newPath});
        }
      } catch (e) {
        print('WhatsApp Status Scanner failed: $e');
      }

      final isVideo = file.path.toLowerCase().endsWith('.mp4');

      // Save to local Hive database so it shows up in Gallery Tab!
      final task = DownloadTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: 'WhatsApp Status',
        title: 'WhatsApp Status (${isVideo ? 'Video' : 'Photo'})',
        thumbnail: isVideo ? '' : newPath,
        type: isVideo ? DownloadType.video : DownloadType.image,
        selectedFormat: 'WhatsApp Saved',
        status: DownloadStatus.completed,
        filePath: newPath,
        progress: 1.0,
        speed: 'Local Copy',
      );

      await provider.addCompletedTask(task);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status saved to Gallery successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DownloadProvider>(context);

    if (!_isAndroid) {
      return _buildiOSFallback();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status Saver',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
              ),
              if (_permissionGranted && !_isLoading)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: LiquidGlassTheme.primaryBlue),
                  onPressed: _scanStatuses,
                ),
            ],
          ),
        ),
        
        if (!_permissionGranted)
          Expanded(child: _buildPermissionPrompt())
        else if (_isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: LiquidGlassTheme.primaryBlue),
            ),
          )
        else if (_errorMessage != null)
          Expanded(child: _buildErrorState())
        else
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        gradient: LiquidGlassTheme.brandGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: LiquidGlassTheme.textLight,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [
                        Tab(text: 'Photos'),
                        Tab(text: 'Videos'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGridFilter(isVideo: false, provider: provider),
                      _buildGridFilter(isVideo: true, provider: provider),
                    ],
                  ),
                )
              ],
            ),
          )
      ],
    );
  }

  Widget _buildGridFilter({required bool isVideo, required DownloadProvider provider}) {
    final filtered = _statuses.where((f) {
      final ext = f.path.toLowerCase();
      if (isVideo) {
        return ext.endsWith('.mp4');
      } else {
        return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png');
      }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.videocam_off_outlined : Icons.no_photography_outlined,
              size: 56,
              color: LiquidGlassTheme.textLight.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'No media files found',
              style: TextStyle(fontWeight: FontWeight.bold, color: LiquidGlassTheme.textLight),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final file = filtered[index];
        return _buildStatusCard(file, isVideo, provider);
      },
    );
  }

  Widget _buildStatusCard(File file, bool isVideo, DownloadProvider provider) {
    return GlassmorphicCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _previewStatus(file, isVideo, provider),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Container(
                  color: Colors.black.withOpacity(0.03),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isVideo)
                        const Icon(Icons.video_library_rounded, size: 48, color: LiquidGlassTheme.primaryBlue)
                      else
                        Image.file(
                          file,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      if (isVideo)
                        Positioned(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: LiquidGlassTheme.textLight),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: Text(
                        file.path.split('/').last,
                        style: const TextStyle(fontSize: 10, color: LiquidGlassTheme.textLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.download_rounded, color: LiquidGlassTheme.primaryGreen, size: 18),
                    onPressed: () => _saveToGallery(file, provider),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _previewStatus(File file, bool isVideo, DownloadProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: GlassmorphicCard(
            padding: const EdgeInsets.all(16),
            radius: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        file.path.split('/').last,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : LiquidGlassTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isVideo
                        ? CustomVideoPlayer(filePath: file.path)
                        : Image.file(file, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LiquidGlassTheme.primaryBlue.withOpacity(0.1),
                        foregroundColor: LiquidGlassTheme.primaryBlue,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Share.shareXFiles([XFile(file.path)]);
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.download, color: Colors.white, size: 18),
                      label: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LiquidGlassTheme.brandGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Save to Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _saveToGallery(file, provider);
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassmorphicCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_shared_outlined,
                size: 64,
                color: LiquidGlassTheme.primaryBlue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Permission Required',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              const Text(
                'InstaStream needs storage access to scan and display viewed WhatsApp status media.',
                textAlign: TextAlign.center,
                style: TextStyle(color: LiquidGlassTheme.textLight, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _requestPermissions,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LiquidGlassTheme.brandGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Grant Permission',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 56,
              color: Colors.amber.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: LiquidGlassTheme.textLight, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _scanStatuses,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildiOSFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassmorphicCard(
          padding: const EdgeInsets.all(24),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block_flipped,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Unsupported Platform',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                'WhatsApp status saving is only supported on Android devices due to iOS application sandboxing policies.',
                textAlign: TextAlign.center,
                style: TextStyle(color: LiquidGlassTheme.textLight, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
