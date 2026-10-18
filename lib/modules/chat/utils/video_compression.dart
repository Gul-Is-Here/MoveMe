import 'package:video_compress/video_compress.dart';

import '../../../app/utils/app_logger.dart';

/// Shrinks a camera video before upload. Falls back to the original file
/// when compression fails, so a video is never lost over it.
Future<String> compressVideo(String path) async {
  try {
    final info = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );
    return info?.path ?? path;
  } catch (e, s) {
    AppLogger.error('VideoCompress', e, s);
    return path;
  }
}
