final Map<String, List<String>> _extensionMap = {
  'lua': ['application/x-ginga-NCLua'],
  'html': ['text/html'],
  'ssml': ['application/ssml+xml'],
  'txt': ['text/plain'],
  'png': ['image/png'],
  'bmp': ['image/bmp'],
  'webp': ['image/webp'],
  'gif': ['image/gif'],
  'jpeg': ['image/jpeg'],
  'jpg': ['image/jpeg'],
  'heic': ['image/heic'],
  'heif': ['image/heic'],
  'mp4': ['video/mp4'],
  'mp3': ['audio/mpeg'],
  'mpeg': ['video/mpeg'],
  'avi': ['video/avi'],
  'wav': ['audio/wav'],
  'aac': ['audio/aac'],
  'ogg': ['audio/ogg'],
  'webm': ['video/webm'],
  'svg': ['image/svg+xml'],
  'm4a': ['audio/mp4'],
  'flac': ['audio/flac'],
};

String getMimeTypeFromExtension(String fileName) {
  if (fileName.isEmpty) return 'application/x-ginga-time';
  final ext = fileName.split('.').last.toLowerCase();
  for (var entry in _extensionMap.entries) {
    if (entry.key == ext) return entry.value.first;
  }
  return 'application/x-ginga-time';
}
