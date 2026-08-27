// lib/services/file_download_web.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class FileDownloadHelper {
  /// Triggers a native browser file download in Flutter Web Chrome.
  static void downloadFile({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    if (kIsWeb) {
      final base64Data = base64Encode(bytes);
      final anchor = html.AnchorElement(
        href: 'data:$mimeType;base64,$base64Data',
      )
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
    } else {
      debugPrint("Download triggered for native platform: $fileName (${bytes.length} bytes)");
    }
  }
}