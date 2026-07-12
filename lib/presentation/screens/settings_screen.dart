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
