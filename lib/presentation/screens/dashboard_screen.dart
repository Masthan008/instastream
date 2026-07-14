import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;
import '../../core/constants/theme.dart';
import '../../data/models/download_task.dart';
import '../../data/models/format_option.dart';
import '../providers/download_provider.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/custom_video_player.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  String _lastClipboardUrl = '';
  bool _showClipboardPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        final text = data.text!.trim();
        if (text != _lastClipboardUrl && _isValidUrl(text)) {
          setState(() {
            _lastClipboardUrl = text;
            _showClipboardPrompt = true;
          });
        }
      }
    } catch (_) {}
  }

  bool _isValidUrl(String text) {
    return text.contains('youtube.com') ||
        text.contains('youtu.be') ||
        text.contains('instagram.com');
  }

  void _playPreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black,
                ),
                child: CustomVideoPlayer(filePath: url),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DownloadProvider>(context);

    // Active downloading tasks
    final activeTasks = provider.tasks
        .where((t) =>
            t.status == DownloadStatus.downloading ||
            t.status == DownloadStatus.pending ||
            t.status == DownloadStatus.processing)
        .toList();

    // Trigger metadata picker dialog when loaded
    if (provider.analyzedMetadata != null && !_isDialogActive) {
      _isDialogActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFormatPicker(context, provider);
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting / Title
          Text(
            'InstaStream',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 4),
          const Text(
            'Download YouTube and Instagram videos & audio instantly',
            style: TextStyle(color: LiquidGlassTheme.textLight, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Clipboard prompt alert
          if (_showClipboardPrompt)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: GlassmorphicCard(
                color: LiquidGlassTheme.primaryBlue.withOpacity(0.08),
                child: Row(
                  children: [
                    const Icon(Icons.paste_rounded, color: LiquidGlassTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Link detected in clipboard',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LiquidGlassTheme.textDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _lastClipboardUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: LiquidGlassTheme.textLight),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _showClipboardPrompt = false);
                      },
                      child: const Text('Dismiss', style: TextStyle(color: LiquidGlassTheme.textLight, fontSize: 12)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      onPressed: () {
                        setState(() => _showClipboardPrompt = false);
                        _urlController.text = _lastClipboardUrl;
                        provider.analyzeLink(_lastClipboardUrl);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LiquidGlassTheme.brandGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Fetch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            ),

          // Input field and analyzer button
          GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'Paste video or audio link here...',
                    hintStyle: const TextStyle(color: LiquidGlassTheme.textLight),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.04),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _urlController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: LiquidGlassTheme.textLight),
                            onPressed: () {
                              _urlController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(color: LiquidGlassTheme.textDark, fontSize: 14),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                
                // Fetch button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: provider.isAnalyzing || _urlController.text.trim().isEmpty
                        ? null
                        : () {
                            provider.analyzeLink(_urlController.text.trim());
                          },
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: _urlController.text.trim().isEmpty
                            ? null
                            : LiquidGlassTheme.brandGradient,
                        color: _urlController.text.trim().isEmpty
                            ? Colors.grey.withOpacity(0.15)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: provider.isAnalyzing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Analyze & Extract Link',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Error Message container
          if (provider.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            ),

          // Active Downloads list section
          if (activeTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Active Downloads',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: LiquidGlassTheme.textDark),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeTasks.length,
              itemBuilder: (context, index) {
                final task = activeTasks[index];
                return _buildActiveDownloadItem(task, provider);
              },
            ),
          ]
        ],
      ),
    );
  }

  bool _isDialogActive = false;

  void _showFormatPicker(BuildContext context, DownloadProvider provider) {
    final meta = provider.analyzedMetadata!;
    
    // Find preview URL
    String? previewUrl;
    for (var fmt in meta.formats) {
      if (meta.sourceType == 'youtube') {
        if (fmt.id.startsWith('muxed_') && fmt.originalStreamInfo != null) {
          previewUrl = (fmt.originalStreamInfo as yt_exp.MuxedStreamInfo).url.toString();
          break;
        }
      } else if (meta.sourceType == 'instagram') {
        if (fmt.originalStreamInfo is String) {
          previewUrl = fmt.originalStreamInfo as String;
          break;
        }
      }
    }
    if (previewUrl == null && meta.formats.isNotEmpty) {
      final firstFmt = meta.formats.first;
      if (meta.sourceType == 'youtube' && firstFmt.originalStreamInfo is yt_exp.VideoStreamInfo) {
        previewUrl = (firstFmt.originalStreamInfo as yt_exp.VideoStreamInfo).url.toString();
      } else if (meta.sourceType == 'instagram' && firstFmt.originalStreamInfo is String) {
        previewUrl = firstFmt.originalStreamInfo as String;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.75,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Content Title
                Text(
                  meta.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: LiquidGlassTheme.textDark),
                ),
                Text(
                  'By ${meta.author} • ${meta.durationString}',
                  style: const TextStyle(color: LiquidGlassTheme.textLight, fontSize: 12),
                ),
                const SizedBox(height: 16),
 
                // Formats Options List Header with Preview Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Choose Download Format',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LiquidGlassTheme.textDark),
                    ),
                    if (previewUrl != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: LiquidGlassTheme.primaryBlue.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, color: LiquidGlassTheme.primaryBlue, size: 18),
                        label: const Text('Play Preview', style: TextStyle(color: LiquidGlassTheme.primaryBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          _playPreview(context, previewUrl!);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: meta.formats.isEmpty
                      ? _buildWebViewLoginPrompt(meta.url, provider, ctx)
                      : ListView.builder(
                          itemCount: meta.formats.length,
                          itemBuilder: (c, idx) {
                            final fmt = meta.formats[idx];
                            return _buildFormatListTile(fmt, provider, ctx);
                          },
                        ),
                )
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isDialogActive = false;
      provider.resetAnalysis();
    });
  }

  Widget _buildWebViewLoginPrompt(String originalUrl, DownloadProvider provider, BuildContext bottomSheetContext) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 48, color: Colors.orangeAccent.withOpacity(0.8)),
        const SizedBox(height: 12),
        const Text(
          'Instagram Authentication Required',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LiquidGlassTheme.textDark),
        ),
        const SizedBox(height: 6),
        const Text(
          'We cannot access this post publicly. Please browse this post in the Browser Tab to download.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: LiquidGlassTheme.textLight),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LiquidGlassTheme.primaryBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(bottomSheetContext);
            // We notify our NavigationProvider (or layout index controller) to switch to the Browser Tab and search the link
            // For simplicity, we can do this via notification or instructions, but let's notify the user
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please paste this URL in the Browser tab to authenticate & extract!')),
            );
          },
          child: const Text('Go to Browser', style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }

  Widget _buildFormatListTile(FormatOption format, DownloadProvider provider, BuildContext bottomSheetContext) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.02)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(
          format.isAudioOnly ? Icons.music_note : Icons.videocam,
          color: format.isAudioOnly ? LiquidGlassTheme.primaryBlue : LiquidGlassTheme.primaryGreen,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                format.label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LiquidGlassTheme.textDark),
              ),
            ),
            if (provider.analyzedMetadata?.sourceType == 'instagram' && !format.isAudioOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: LiquidGlassTheme.primaryGreen, size: 10),
                    SizedBox(width: 4),
                    Text(
                      'No Watermark',
                      style: TextStyle(color: LiquidGlassTheme.primaryGreen, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(
          'Size: ${format.sizeLabel} • format: ${format.ext.toUpperCase()}',
          style: const TextStyle(fontSize: 11, color: LiquidGlassTheme.textLight),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: const Icon(Icons.download_rounded, color: LiquidGlassTheme.primaryGreen, size: 18),
        ),
        onTap: () {
          Navigator.pop(bottomSheetContext);
          if (format.id.startsWith('playlist_item_')) {
            final videoUrl = format.originalStreamInfo as String;
            provider.analyzeLink(videoUrl);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Extracting playlist video formats...')),
            );
          } else {
            provider.triggerDownload(format);
            _urlController.clear();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download started in background...')),
            );
          }
        },
      ),
    );
  }

  double _getSafeProgress(double val) {
    if (val.isNaN || val.isInfinite) return 0.0;
    return val.clamp(0.0, 1.0);
  }

  String _getProgressPercent(double val) {
    if (val.isNaN || val.isInfinite) return '0%';
    final pct = (val * 100).clamp(0.0, 100.0);
    return '${pct.toStringAsFixed(0)}%';
  }

  Widget _buildActiveDownloadItem(DownloadTask task, DownloadProvider provider) {
    final isProcessing = task.status == DownloadStatus.processing;

    return GlassmorphicCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LiquidGlassTheme.textDark),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.cancel_outlined, color: Colors.grey, size: 20),
                onPressed: () {
                  provider.cancelTask(task.id);
                },
              )
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.selectedFormat,
                      style: const TextStyle(fontSize: 11, color: LiquidGlassTheme.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.speed,
                      style: const TextStyle(fontSize: 10, color: LiquidGlassTheme.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isProcessing ? 'Processing...' : _getProgressPercent(task.progress),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isProcessing ? LiquidGlassTheme.primaryBlue : LiquidGlassTheme.primaryGreen,
                    ),
                  ),
                  if (!isProcessing) ...[
                    const SizedBox(height: 2),
                    Text(
                      'ETA: ${task.eta}',
                      style: const TextStyle(fontSize: 10, color: LiquidGlassTheme.textLight),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: isProcessing ? null : _getSafeProgress(task.progress),
              color: LiquidGlassTheme.primaryGreen,
              backgroundColor: Colors.black.withOpacity(0.04),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
