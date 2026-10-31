import 'dart:typed_data';

import 'voice_file_web.dart'
    if (dart.library.io) 'voice_file_io.dart';

class VoiceFileHelper {
  static Future<String> prepareRecordPath() => prepareRecordPathImpl();
  static Future<Uint8List> readFileBytes(String path) => readFileBytesImpl(path);
  static String getVoiceFileExtension() => getVoiceFileExtensionImpl();
}
