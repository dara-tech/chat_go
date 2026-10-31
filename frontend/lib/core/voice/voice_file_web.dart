import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<String> prepareRecordPathImpl() async {
  // Web does not need a filesystem path; record_web generates a blob: URL
  return '';
}

Future<Uint8List> readFileBytesImpl(String path) async {
  try {
    if (path.startsWith('blob:') || path.startsWith('http://') || path.startsWith('https://')) {
      final res = await http.get(Uri.parse(path));
      return res.bodyBytes;
    }
  } catch (_) {}
  return Uint8List(0);
}

String getVoiceFileExtensionImpl() => '.webm';
