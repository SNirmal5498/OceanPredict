// Default (non-web) implementation. Used automatically on Android/iOS/desktop
// builds via conditional export in csv_download.dart.
bool get canDownloadInBrowser => false;

void downloadCsv(String filename, String content) {
  throw UnsupportedError('File download is only supported on the web build right now.');
}