// Web-only implementation, selected automatically by csv_download.dart when
// compiling for web (dart.library.html). Never imported by mobile/desktop
// builds, so it cannot break Android/iOS compilation.
import 'dart:html' as html;

bool get canDownloadInBrowser => true;

void downloadCsv(String filename, String content) {
  final bytes = html.Blob([content], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}