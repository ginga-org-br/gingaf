import 'dart:async';
import 'dart:io';

abstract class SrcResolver {
  const SrcResolver();

  bool exists(String src, [String? baseDirSrc]);
  Future<String?> load(String src, [String? baseDirSrc]);
}

class FileSrcResolver extends SrcResolver {
  const FileSrcResolver();

  File? resolveFile(String src, [String? baseDirSrc]) {
    final rawSrc = src.trim();
    if (rawSrc.isEmpty || rawSrc.startsWith('<')) return null;

    final srcUri = Uri.tryParse(rawSrc) ?? Uri(path: rawSrc);
    final baseUri = baseDirSrc != null ? Uri.tryParse(baseDirSrc) : null;
    final resolvedUri = baseUri != null ? baseUri.resolveUri(srcUri) : srcUri;

    final path = resolvedUri.isScheme('file')
        ? resolvedUri.toFilePath()
        : (resolvedUri.hasScheme ? resolvedUri.path : Uri.decodeComponent(resolvedUri.toString()));

    if (path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) return file.absolute;
    }

    if (path != rawSrc && rawSrc.isNotEmpty) {
      final rawFile = File(rawSrc);
      if (rawFile.existsSync()) return rawFile.absolute;
    }

    final normalizedPath = (path.isNotEmpty ? path : rawSrc).replaceAll('\\', '/');
    final fileName = normalizedPath.split('/').last;
    if (fileName.isNotEmpty) {
      final baseNameFile = File(fileName);
      if (baseNameFile.existsSync()) return baseNameFile.absolute;
    }

    return null;
  }

  @override
  bool exists(String src, [String? baseDirSrc]) {
    return resolveFile(src, baseDirSrc) != null;
  }

  @override
  Future<String?> load(String src, [String? baseDirSrc]) async {
    final rawSrc = src.trim();
    if (rawSrc.isEmpty) return null;

    final file = resolveFile(src, baseDirSrc);
    if (file != null) {
      return await file.readAsString();
    }
    throw FileSystemException('Cannot read file for src: $src', src);
  }
}
