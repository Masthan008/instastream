import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme.dart';
import '../providers/download_provider.dart';
import '../widgets/glassmorphic_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final downloadProvider = Provider.of<DownloadProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 24),
          
          // Storage configuration card
          GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: LiquidGlassTheme.primaryGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.folder_open, color: LiquidGlassTheme.primaryGreen),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Storage Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Media files are saved locally to your device\'s standard storage directory under the folder:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Downloads/InstaStream (Android)\nDocument Sandbox (iOS)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Theme selection card
          GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: LiquidGlassTheme.primaryBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        downloadProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: LiquidGlassTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'App Theme',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: LiquidGlassTheme.primaryGreen,
                  title: const Text('Obsidian Dark Mode', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Toggle between Light and premium Dark mode styles', style: TextStyle(fontSize: 12)),
                  value: downloadProvider.isDarkMode,
                  onChanged: (value) {
                    downloadProvider.toggleTheme(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Download Queue concurrency settings card
          GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: LiquidGlassTheme.primaryGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_suggest_rounded,
                        color: LiquidGlassTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Download Queue Settings',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Set the maximum number of downloads that can run concurrently. Subsequent requests will be queued automatically:',
                  style: TextStyle(fontSize: 12, color: LiquidGlassTheme.textLight),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Max Concurrent Downloads: ${downloadProvider.maxConcurrentDownloads}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Slider(
                  value: downloadProvider.maxConcurrentDownloads.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: LiquidGlassTheme.primaryGreen,
                  inactiveColor: Colors.black.withOpacity(0.05),
                  label: downloadProvider.maxConcurrentDownloads.toString(),
                  onChanged: (val) {
                    downloadProvider.setMaxConcurrentDownloads(val.toInt());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dynamic Ad Blocker domains card
          GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.block, color: Colors.redAccent),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Ad Blocker',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        downloadProvider.resetBlockedDomains();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ad blocker list reset to defaults')),
                        );
                      },
                      child: const Text('Reset Defaults', style: TextStyle(fontSize: 12, color: LiquidGlassTheme.primaryBlue)),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Manage dynamic domains blocked in the browser tab to suppress popups and redirect ads:',
                  style: TextStyle(fontSize: 13, color: LiquidGlassTheme.textLight),
                ),
                const SizedBox(height: 12),
                
                // Add domain input field
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Enter domain (e.g. example.com)...',
                            hintStyle: TextStyle(fontSize: 12, color: LiquidGlassTheme.textLight),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              downloadProvider.addBlockedDomain(val.trim());
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Domains list
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: downloadProvider.blockedDomains.length,
                    itemBuilder: (context, index) {
                      final domain = downloadProvider.blockedDomains[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(domain, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                            GestureDetector(
                              onTap: () {
                                downloadProvider.removeBlockedDomain(domain);
                              },
                              child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions Card
          GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: LiquidGlassTheme.primaryBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.settings_suggest, color: LiquidGlassTheme.primaryBlue),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Data Management',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  title: const Text('Clear Download History', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Deletes history list. Downloaded files remain on device.', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    _showClearConfirmation(context, downloadProvider);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // About Card
          GlassmorphicCard(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About InstaStream',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 12),
                Text(
                  'InstaStream Downloader is a premium, client-side utility built using Flutter. It extracts streams locally to deliver an ad-free experience without server-side tracking.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Version'),
                    Text('1.0.0 (FFmpeg enabled)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, DownloadProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('Are you sure you want to clear your download history? Downloaded video and audio files will not be deleted from storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: LiquidGlassTheme.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              provider.clearAllHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download history cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
