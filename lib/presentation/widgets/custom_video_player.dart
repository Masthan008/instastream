import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/theme.dart';

class CustomVideoPlayer extends StatefulWidget {
  final String filePath;

  const CustomVideoPlayer({Key? key, required this.filePath}) : super(key: key);

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final isNetwork = widget.filePath.startsWith('http://') || widget.filePath.startsWith('https://');
      if (isNetwork) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.filePath));
      } else {
        final file = File(widget.filePath);
        if (!await file.exists()) {
          setState(() {
            _hasError = true;
          });
          return;
        }
        _videoPlayerController = VideoPlayerController.file(file);
      }
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: LiquidGlassTheme.primaryGreen,
          handleColor: LiquidGlassTheme.primaryBlue,
          bufferedColor: Colors.grey.withOpacity(0.3),
          backgroundColor: Colors.grey.withOpacity(0.1),
        ),
      );
      setState(() {});
    } catch (e) {
      print('Video player init error: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: LiquidGlassTheme.glassDecoration(),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16.0),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            SizedBox(height: 8),
            Text(
              'Unsupported file format or corrupted video file.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (_chewieController == null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
            color: LiquidGlassTheme.primaryGreen,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoPlayerController.value.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Chewie(
          controller: _chewieController!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
}
