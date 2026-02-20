import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

abstract class FileDownloadHelper {
  static Future<void> downloadFile(String fileName, String content) async {
    if (kIsWeb) {
      await _downloadWeb(fileName, content);
    } else {
      await _downloadDesktop(fileName, content);
    }
  }

  static Future<void> _downloadWeb(String fileName, String content) async {
    // For web, we'll use a different approach
    // This is a placeholder - web download requires dart:html
    throw UnsupportedError('Web download not implemented');
  }

  static Future<void> _downloadDesktop(String fileName, String content) async {
    // For desktop, save to current directory
    final file = File('./$fileName');
    await file.writeAsString(content);
  }
}
