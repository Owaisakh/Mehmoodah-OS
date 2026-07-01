/// Stub download file helper for non-web environments (mobile/desktop stubs)
void downloadFile(String content, String fileName, String mimeType) {
  // Safe fallback when not running on web
  print('Download requested: $fileName ($mimeType)');
}
