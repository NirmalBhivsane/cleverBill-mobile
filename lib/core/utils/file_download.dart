import 'file_download_web.dart' if (dart.library.io) 'file_download_io.dart';

class FileDownloader {
  static Future<void> download({
    required List<int> bytes,
    required String filename,
    required String mimeType,
    String? shareText,
  }) => saveAndShareFile(
    bytes: bytes,
    filename: filename,
    mimeType: mimeType,
    shareText: shareText,
  );
}

