import 'dart:io';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/constants/theme.dart';

class CustomAudioPlayer extends StatefulWidget {
  final String filePath;
  final String title;
  final VoidCallback? onCompleted;

  const CustomAudioPlayer({
    Key? key,
    required this.filePath,
    required this.title,
    this.onCompleted,
  }) : super(key: key);

  @override
  State<CustomAudioPlayer> createState() => _CustomAudioPlayerState();
}

class _CustomAudioPlayerState extends State<CustomAudioPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _audioPlayer = AudioPlayer();
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _hasError = true;
        });
        return;
      }
      await _audioPlayer.setFilePath(widget.filePath);
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
          if (state.processingState == ProcessingState.completed && widget.onCompleted != null) {
            widget.onCompleted!();
          }
        }
      });
    } catch (e) {
      print('Audio player init error: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: LiquidGlassTheme.glassDecoration(),
        child: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Unsupported audio or file not found.',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: LiquidGlassTheme.glassDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          StreamBuilder<Duration?>(
            stream: _audioPlayer.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final total = _audioPlayer.duration ?? Duration.zero;
              
              return ProgressBar(
                progress: position,
                total: total,
                progressBarColor: LiquidGlassTheme.primaryGreen,
                baseBarColor: Colors.grey.withOpacity(0.2),
                thumbColor: LiquidGlassTheme.primaryBlue,
                thumbRadius: 8.0,
                timeLabelTextStyle: const TextStyle(color: LiquidGlassTheme.textLight, fontSize: 12),
                onSeek: (duration) {
                  _audioPlayer.seek(duration);
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: LiquidGlassTheme.primaryBlue, size: 28),
                onPressed: () {
                  final newPos = _audioPlayer.position - const Duration(seconds: 10);
                  _audioPlayer.seek(newPos < Duration.zero ? Duration.zero : newPos);
                },
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () {
                  if (_isPlaying) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.play();
                  }
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LiquidGlassTheme.brandGradient,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.forward_10, color: LiquidGlassTheme.primaryBlue, size: 28),
                onPressed: () {
                  final newPos = _audioPlayer.position + const Duration(seconds: 10);
                  final maxPos = _audioPlayer.duration ?? Duration.zero;
                  _audioPlayer.seek(newPos > maxPos ? maxPos : newPos);
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
