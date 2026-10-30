import 'dart:convert';
import 'dart:js_interop';

@JS('downloadBlobFile')
external void _jsDownloadBlobFile(JSString name, JSString mime, JSString b64);

Future<void> saveAndShareFile({
  required List<int> bytes,
  required String filename,
  required String mimeType,
  String? shareText,
}) async {
  try {
    final b64 = base64Encode(bytes);
    _jsDownloadBlobFile(filename.toJS, mimeType.toJS, b64.toJS);
  } catch (e) {
    // Fallback if JS function is missing
  }
}

