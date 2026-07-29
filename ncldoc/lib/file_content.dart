import 'dart:async';
import 'dart:io';

abstract class ContentLoader {
  const ContentLoader();

  bool exists(Uri uri);
  Future<String?> load(Uri uri);
}

class FileContentLoader extends ContentLoader {
  const FileContentLoader();

  @override
  bool exists(Uri uri) {
    if (uri.isScheme('file') || !uri.hasScheme) {
      final file = File(uri.toFilePath());
      return file.existsSync();
    }
    return false;
  }

  @override
  Future<String?> load(Uri uri) async {
    if (exists(uri)) {
      final file = File(uri.toFilePath());
      return await file.readAsString();
    }
    return null;
  }
}
