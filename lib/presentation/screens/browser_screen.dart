import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme.dart';
import '../providers/download_provider.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({Key? key}) : super(key: key);

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final TextEditingController _searchController = TextEditingController();
  InAppWebViewController? _webViewController;
  String _currentUrl = 'https://www.google.com';
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _showDownloadBtn = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToUrl(String input) {
    if (input.trim().isEmpty) return;

    String url = input.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }

    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void _detectMedia(String url) {
    final bool hasMedia = url.contains('youtube.com/watch') ||
        url.contains('youtu.be/') ||
        url.contains('youtube.com/shorts/') ||
        url.contains('instagram.com/reel/') ||
        url.contains('instagram.com/p/') ||
        url.contains('instagram.com/stories/') ||
        url.contains('instagram.com/highlights/') ||
        url.contains('instagram.com/s/');
    setState(() {
      _showDownloadBtn = hasMedia;
    });
  }

  Future<void> _triggerExtraction(BuildContext context, DownloadProvider provider) async {
    if (_webViewController == null) return;
    
    final currentUrl = (await _webViewController!.getUrl())?.toString() ?? '';
    if (currentUrl.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: LiquidGlassTheme.primaryGreen),
            SizedBox(width: 16),
            Expanded(child: Text('Extracting media contents...')),
          ],
        ),
      ),
    );

    try {
      if (currentUrl.contains('youtube.com') || currentUrl.contains('youtu.be')) {
        Navigator.pop(context); // Close loading dialog
        // Trigger standard analytical extractor on the URL
        await provider.analyzeLink(currentUrl);
        // This will trigger the picker bottom sheet in the layout screen
        _showDashboardRedirectToast();
      } else if (currentUrl.contains('instagram.com')) {
        // Run Javascript to scrape DOM video or image elements
        final result = await _webViewController!.evaluateJavascript(source: """
          (function() {
            function extractThumbnail(videoEl) {
              return videoEl.poster || '';
            }
            
            function extractOgImage() {
              var ogImg = document.querySelector('meta[property=\\"og:image\\"]');
              return ogImg ? ogImg.content : '';
            }
            
            // 1. Try to find active video (stories, reels, posts)
            var video = document.querySelector('video');
            if (video && video.src && !video.src.startsWith('blob:')) {
              var thumb = extractThumbnail(video) || extractOgImage();
              return { 'url': video.src, 'type': 'video', 'title': document.title || 'Instagram Video', 'thumbnail': thumb };
            }
            
            // 2. Try to find carousel/slides
            var post = document.querySelector('article') || document;
            var slides = [];
            var seenUrls = [];
            
            var videos = post.querySelectorAll('video');
            videos.forEach(function(v) {
              if (v.src && !v.src.startsWith('blob:') && seenUrls.indexOf(v.src) === -1) {
                seenUrls.push(v.src);
                slides.push({ 'url': v.src, 'type': 'video', 'thumbnail': extractThumbnail(v) });
              }
            });
            
            var images = post.querySelectorAll('ul li img');
            if (images.length === 0) {
              images = post.querySelectorAll('img[style*=\\"object-fit: cover\\"]');
            }
            images.forEach(function(img) {
              if (img.src && seenUrls.indexOf(img.src) === -1) {
                seenUrls.push(img.src);
                slides.push({ 'url': img.src, 'type': 'image', 'thumbnail': img.src });
              }
            });
            
            if (slides.length > 0) {
              return { 'slides': slides, 'title': document.title || 'Instagram Slideshow' };
            }
            
            // 3. Fallback for single image (posts or stories/highlights)
            var storyImg = document.querySelector('img[decoding=\\"sync\\"]') || 
                           document.querySelector('section img') || 
                           document.querySelector('article img') || 
                           document.querySelector('img[srcset]');
            if (storyImg && storyImg.src) {
              return { 'url': storyImg.src, 'type': 'image', 'title': document.title || 'Instagram Image', 'thumbnail': storyImg.src };
            }
            return null;
          })()
        """);

        Navigator.pop(context); // Close loading dialog

        if (result != null) {
          final String title = result['title'] ?? 'Instagram Post';
          if (result['slides'] != null) {
            // It is a slideshow/carousel!
            final List<dynamic> rawSlides = result['slides'];
            final List<Map<String, dynamic>> slides = rawSlides.map((s) => Map<String, dynamic>.from(s as Map)).toList();
            provider.applyInstagramSlideshow(currentUrl, slides, title);
            _showDashboardRedirectToast();
          } else if (result['url'] != null) {
            // It is a single media item
            final String directUrl = result['url'];
            final String type = result['type'];
            final String thumbnail = result['thumbnail'] ?? '';
            provider.applyDirectInstagramLink(
              currentUrl, 
              directUrl, 
              type == 'video',
              title: title,
              thumbnailUrl: thumbnail.isNotEmpty ? thumbnail : null,
            );
            _showDashboardRedirectToast();
          } else {
            _showErrorDialog('Could not find media content in the page.');
          }
        } else {
          _showErrorDialog('Could not find media content in the page. Please ensure the post has loaded.');
        }
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog('Extraction failed: $e');
    }
  }

  void _showDashboardRedirectToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Media extracted! Go to the Dashboard tab to select format & download.'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dashboard',
          textColor: Colors.white,
          onPressed: () {
            // Layout handles tabs navigation.
          },
        ),
      ),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extraction Error'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: LiquidGlassTheme.primaryGreen)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Browser control bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: Colors.white.withOpacity(0.8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, size: 18, color: _canGoBack ? LiquidGlassTheme.textDark : Colors.grey),
                      onPressed: _canGoBack
                          ? () => _webViewController?.goBack()
                          : null,
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_forward_ios, size: 18, color: _canGoForward ? LiquidGlassTheme.textDark : Colors.grey),
                      onPressed: _canGoForward
                          ? () => _webViewController?.goForward()
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13, color: LiquidGlassTheme.textDark),
                          decoration: InputDecoration(
                            hintText: 'Search or enter address...',
                            hintStyle: const TextStyle(color: LiquidGlassTheme.textLight, fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: InputBorder.none,
                            suffixIcon: _isLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2, color: LiquidGlassTheme.primaryGreen),
                                    ),
                                  )
                                : IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.refresh, size: 16, color: LiquidGlassTheme.textLight),
                                    onPressed: () => _webViewController?.reload(),
                                  ),
                          ),
                          onSubmitted: _navigateToUrl,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_currentUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    allowsBackForwardNavigationGestures: true,
                    supportMultipleWindows: false,
                    javaScriptCanOpenWindowsAutomatically: false,
                    userAgent: 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                    contentBlockers: downloadProvider.blockedDomains.map((domain) {
                      return ContentBlocker(
                        trigger: ContentBlockerTrigger(urlFilter: ".*$domain.*"),
                        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
                      );
                    }).toList(),
                  ),
                  onCreateWindow: (controller, createWindowAction) async {
                    return false; // Blocks popups dynamically
                  },
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      _currentUrl = url?.toString() ?? '';
                      _searchController.text = _currentUrl;
                    });
                  },
                  onLoadStop: (controller, url) async {
                    final canBack = await controller.canGoBack();
                    final canForward = await controller.canGoForward();
                    final currentUrlStr = url?.toString() ?? '';
                    setState(() {
                      _isLoading = false;
                      _canGoBack = canBack;
                      _canGoForward = canForward;
                      _currentUrl = currentUrlStr;
                      _searchController.text = _currentUrl;
                    });
                    _detectMedia(currentUrlStr);
                  },
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    final currentUrlStr = url?.toString() ?? '';
                    _detectMedia(currentUrlStr);
                  },
                ),
              ),
            ],
          ),

          // Glowing Floating "Liquid Download" button
          if (_showDownloadBtn)
            Positioned(
              bottom: 24,
              right: 24,
              child: GestureDetector(
                onTap: () => _triggerExtraction(context, downloadProvider),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LiquidGlassTheme.brandGradient,
                    boxShadow: [
                      BoxShadow(
                        color: LiquidGlassTheme.primaryGreen.withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.offline_share_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
