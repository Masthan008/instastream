import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../core/constants/theme.dart';
import '../providers/download_provider.dart';
import '../widgets/liquid_background.dart';
import 'browser_screen.dart';
import 'dashboard_screen.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';
import 'status_saver_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({Key? key}) : super(key: key);

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  late StreamSubscription _intentDataStreamSubscription;

  final List<Widget> _screens = const [
    DashboardScreen(),
    BrowserScreen(),
    StatusSaverScreen(),
    GalleryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Listen for text/links shared while app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> media) {
      if (media.isNotEmpty) {
        final text = media.first.path;
        _handleSharedText(text);
      }
    }, onError: (err) {
      print("Shared text stream error: $err");
    });

    // Listen for text/links shared while app was closed
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> media) {
      if (media.isNotEmpty) {
        final text = media.first.path;
        _handleSharedText(text);
      }
    });
  }

  void _handleSharedText(String text) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    if (cleanText.contains('youtube.com') ||
        cleanText.contains('youtu.be') ||
        cleanText.contains('instagram.com')) {
      final provider = Provider.of<DownloadProvider>(context, listen: false);
      provider.analyzeLink(cleanText);

      // Navigate to Dashboard tab to view extraction bottom sheet
      setState(() {
        _currentIndex = 0;
      });
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }
  Widget build(BuildContext context) {
    return Scaffold(
      // Allow WebView to draw full height, or let gradient display behind Scaffold
      resizeToAvoidBottomInset: _currentIndex == 1 ? false : true,
      body: LiquidBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          border: Border(
            top: BorderSide(color: Colors.black.withOpacity(0.04), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: LiquidGlassTheme.primaryGreen,
          unselectedItemColor: LiquidGlassTheme.textLight,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.language_outlined),
              activeIcon: Icon(Icons.language_rounded),
              label: 'Browser',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_border_rounded),
              activeIcon: Icon(Icons.star_rounded),
              label: 'Statuses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_library_outlined),
              activeIcon: Icon(Icons.photo_library_rounded),
              label: 'Gallery',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
