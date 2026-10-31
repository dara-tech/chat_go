import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> prepareRecordPathImpl() async {
  final tempDir = await getTemporaryDirectory();
  return '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
}

Future<Uint8List> readFileBytesImpl(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (_) {}
  return Uint8List(0);
}

String getVoiceFileExtensionImpl() => '.m4a';
