import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:ncldoc/src_resolver.dart';
export 'package:ncldoc/src_resolver.dart' show FileSrcResolver, SrcResolver;

import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';

final _logger = Logger('ginga');

class GingaSrcResolver extends FileSrcResolver {
  BuildContext? _context;

  GingaSrcResolver();

  void setBuildContext(BuildContext context) {
    _context = context;
  }

  static String resolveUri(String src, [String? baseDirSrc]) {
    var resolvedSrc = src;
    if (kIsWeb) {
      try {
        final mockJson = getSessionStorageItem('GINGA_PLAYGROUND_FILES');
        if (mockJson != null) {
          final mockFiles = jsonDecode(mockJson);
          final fileName = Uri.parse(resolvedSrc).pathSegments.isNotEmpty
              ? Uri.parse(resolvedSrc).pathSegments.last
              : resolvedSrc;
          if (mockFiles.containsKey(resolvedSrc)) {
            resolvedSrc = mockFiles[resolvedSrc];
          } else if (mockFiles.containsKey(fileName)) {
            resolvedSrc = mockFiles[fileName];
          }
        }
      } catch (_) {}
    } else {
      final file = const FileSrcResolver().resolveFile(src, baseDirSrc);
      if (file != null) {
        return file.absolute.path;
      }
    }
    return resolvedSrc;
  }

  @override
  bool exists(String src, [String? baseDirSrc]) {
    if (!kIsWeb && super.exists(src, baseDirSrc)) {
      return true;
    }

    final rawSrc = src.trim();
    if (rawSrc.isEmpty || rawSrc.startsWith('<')) return false;

    final uri = Uri.tryParse(rawSrc) ?? Uri(path: rawSrc);
    final baseUri = baseDirSrc != null ? Uri.tryParse(baseDirSrc) : null;
    final resolvedUri = baseUri != null ? baseUri.resolveUri(uri) : uri;
    if (resolvedUri.scheme == 'data') return true;
    final rawPath = Uri.decodeComponent(resolvedUri.toString()).trim();
    if (rawPath.isEmpty || rawPath.startsWith('<')) return false;

    final path = resolvedUri.isScheme('file')
        ? resolvedUri.toFilePath()
        : (resolvedUri.hasScheme ? resolvedUri.path : rawPath);

    if (kIsWeb) {
      try {
        final mockJson = getSessionStorageItem('GINGA_PLAYGROUND_FILES');
        if (mockJson != null) {
          final mockFiles = jsonDecode(mockJson);
          final fileName = resolvedUri.pathSegments.isNotEmpty
              ? resolvedUri.pathSegments.last
              : path;
          if (mockFiles.containsKey(fileName) || mockFiles.containsKey(path)) {
            return true;
          }
        }
      } catch (e) {
        _logger.warning(
            'Failed to read playground files from session storage in exists: $e');
      }
    }

    if (!resolvedUri.isScheme('file') && path.isNotEmpty) {
      return true;
    }

    return false;
  }

  @override
  Future<String?> load(String src, [String? baseDirSrc]) async {
    if (!kIsWeb) {
      try {
        final fileContent = await super.load(src, baseDirSrc);
        if (fileContent != null) {
          return fileContent;
        }
      } catch (_) {}
    }

    final uri = Uri.tryParse(src) ?? Uri(path: src);
    final baseUri = baseDirSrc != null ? Uri.tryParse(baseDirSrc) : null;
    final resolvedUri = baseUri != null ? baseUri.resolveUri(uri) : uri;
    if (resolvedUri.scheme == 'data') {
      return resolvedUri.data?.contentAsString();
    }
    final rawPath = Uri.decodeComponent(resolvedUri.toString()).trim();
    if (rawPath.isEmpty) return null;

    final path = resolvedUri.isScheme('file')
        ? resolvedUri.toFilePath()
        : (resolvedUri.hasScheme ? resolvedUri.path : rawPath);

    if (kIsWeb) {
      try {
        final mockJson = getSessionStorageItem('GINGA_PLAYGROUND_FILES');
        if (mockJson != null) {
          final mockFiles = jsonDecode(mockJson);
          final fileName = resolvedUri.pathSegments.isNotEmpty
              ? resolvedUri.pathSegments.last
              : path;
          if (mockFiles.containsKey(fileName)) {
            return mockFiles[fileName];
          }
          if (mockFiles.containsKey(path)) {
            return mockFiles[path];
          }
        }
      } catch (e) {
        _logger.warning('Failed to read playground files from session storage: $e');
      }
    }

    final candidateKeys = <String>[
      path,
      rawPath,
      if (resolvedUri.pathSegments.length >= 2)
        '${resolvedUri.pathSegments[resolvedUri.pathSegments.length - 2]}/${resolvedUri.pathSegments.last}',
      if (resolvedUri.pathSegments.isNotEmpty) resolvedUri.pathSegments.last,
    ];
    if (_context != null) {
      for (final key in candidateKeys) {
        if (key.isEmpty) continue;
        try {
          final assetContent =
              await DefaultAssetBundle.of(_context!).loadString(key);
          if (assetContent.isNotEmpty) return assetContent;
        } catch (e) {
          _logger.fine('Asset loading skipped for $key: $e');
        }
      }
    }

    return null;
  }
}
