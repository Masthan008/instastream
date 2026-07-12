import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class FFmpegService {
  /// Mux (merge) a video-only file and an audio-only file into a single MP4 file.
  Future<bool> mergeVideoAndAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    // If the output file already exists, delete it first to avoid prompt blocks
    final file = File(outputPath);
    if (await file.exists()) {
      await file.delete();
    }

    // Command: merge video and audio, copy video stream, convert/encode audio to aac
    // -map 0:v:0 maps the video stream of the 1st input
    // -map 1:a:0 maps the audio stream of the 2nd input
    final cleanVideoPath = videoPath.replaceAll('\\', '/');
    final cleanAudioPath = audioPath.replaceAll('\\', '/');
    final cleanOutputPath = outputPath.replaceAll('\\', '/');
    final cmd = '-i "$cleanVideoPath" -i "$cleanAudioPath" -c:v copy -c:a aac -map 0:v:0 -map 1:a:0 -y "$cleanOutputPath"';
    
    print('FFmpeg starting merge: $cmd');
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print('FFmpeg merge success');
      return true;
    } else {
      final failStackTrace = await session.getFailStackTrace();
      final logs = await session.getLogs();
      print('FFmpeg merge failed. Return code: $returnCode. Error: $failStackTrace');
      for (var log in logs) {
        print('FFmpeg log: ${log.getMessage()}');
      }
      return false;
    }
  }

  /// Convert/transcode any audio track to standard MP3 at selected bitrate.
  Future<bool> convertToMp3({
    required String inputPath,
    required String outputPath,
    int bitrateKbps = 256,
  }) async {
    final file = File(outputPath);
    if (await file.exists()) {
      await file.delete();
    }

    // Command: convert to mp3 using libmp3lame encoder with specified bitrate
    final cleanInputPath = inputPath.replaceAll('\\', '/');
    final cleanOutputPath = outputPath.replaceAll('\\', '/');
    final cmd = '-i "$cleanInputPath" -codec:a libmp3lame -b:a ${bitrateKbps}k -y "$cleanOutputPath"';

    print('FFmpeg starting mp3 conversion: $cmd');
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print('FFmpeg mp3 conversion success');
      return true;
    } else {
      final failStackTrace = await session.getFailStackTrace();
      final logs = await session.getLogs();
      print('FFmpeg conversion failed. Return code: $returnCode. Error: $failStackTrace');
      for (var log in logs) {
        print('FFmpeg log: ${log.getMessage()}');
      }
      return false;
    }
  }
}
