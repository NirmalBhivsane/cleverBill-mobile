import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndShareFile({
  required List<int> bytes,
  required String filename,
  required String mimeType,
  String? shareText,
}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$filename');
  await f.writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(f.path, mimeType: mimeType)],
    text: shareText,
  );
}

