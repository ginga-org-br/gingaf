import 'dart:async';
import 'dart:io';

abstract class SrcResolver {
  const SrcResolver();

  bool exists(String src, [String? baseDirSrc]);
  Future<String?> load(String src, [String? baseDirSrc]);
}

class FileSrcResolver extends SrcResolver {
  const FileSrcResolver();

  File? _resolveFile(String src, [String? baseDirSrc]) {
    final rawSrc = src.trim();
    if (rawSrc.isEmpty || rawSrc.startsWith('<')) return null;

    final srcUri = Uri.tryParse(rawSrc) ?? Uri(path: rawSrc);
    final baseUri = baseDirSrc != null ? Uri.tryParse(baseDirSrc) : null;
    final resolvedUri = baseUri != null ? baseUri.resolveUri(srcUri) : srcUri;

    final path = resolvedUri.isScheme('file')
        ? resolvedUri.toFilePath()
        : (resolvedUri.hasScheme ? resolvedUri.path : Uri.decodeComponent(resolvedUri.toString()));

    if (path.isEmpty) return null;

    final file = File(path);
    if (file.existsSync()) return file;

    if (path != rawSrc) {
      final rawFile = File(rawSrc);
      if (rawFile.existsSync()) return rawFile;
    }

    final normalizedPath = path.replaceAll('\\', '/');
    final fileName = normalizedPath.split('/').last;
    if (fileName.isNotEmpty) {
      final baseNameFile = File(fileName);
      if (baseNameFile.existsSync()) return baseNameFile;
    }

    return null;
  }

  @override
  bool exists(String src, [String? baseDirSrc]) {
    return _resolveFile(src, baseDirSrc) != null;
  }

  @override
  Future<String?> load(String src, [String? baseDirSrc]) async {
    final rawSrc = src.trim();
    if (rawSrc.isEmpty) return null;

    final file = _resolveFile(src, baseDirSrc);
    if (file != null) {
      return await file.readAsString();
    }
    throw FileSystemException('Cannot read file for src: $src', src);
  }
}
