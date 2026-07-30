import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:ncldoc/file_content.dart';
export 'package:ncldoc/file_content.dart' show ContentLoader, FileContentLoader;

import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';

final _logger = Logger('ginga');

class GingaContentLoader extends ContentLoader {
  BuildContext? _context;

  GingaContentLoader();

  void setBuildContext(BuildContext context) {
    _context = context;
  }

  @override
  bool exists(Uri uri) {
    if (uri.scheme == 'data') return true;
    final rawPath = Uri.decodeComponent(uri.toString()).trim();
    if (rawPath.isEmpty) return false;
    if (rawPath.startsWith('<')) return true;

    final path = uri.isScheme('file') ? uri.toFilePath() : (uri.hasScheme ? uri.path : rawPath);

    if (kIsWeb) {
      try {
        final mockJson = getSessionStorageItem('GINGA_PLAYGROUND_FILES');
        if (mockJson != null) {
          final mockFiles = jsonDecode(mockJson);
          final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : path;
          if (mockFiles.containsKey(fileName)) {
            return true;
          }
        }
      } catch (e) {
        _logger.warning('Failed to read playground files from session storage in exists: $e');
      }
    }

    if (uri.isScheme('file')) {
      try {
        final file = File(uri.toFilePath());
        return file.existsSync();
      } catch (e, stackTrace) {
        _logger.severe('Failed to check file existence for ${uri.toFilePath()}: $e', e, stackTrace);
        rethrow;
      }
    }

    if (!uri.isScheme('file') && path.isNotEmpty) {
      if (!uri.hasScheme) {
        try {
          final file = File(path);
          if (file.existsSync()) return true;
        } catch (_) {}
      }
      return true;
    }

    return false;
  }

  @override
  Future<String?> load(Uri uri) async {
    if (uri.scheme == 'data') {
      return uri.data?.contentAsString();
    }
    final rawPath = Uri.decodeComponent(uri.toString()).trim();
    if (rawPath.isEmpty) return null;
    if (rawPath.startsWith('<')) return rawPath;

    final path = uri.isScheme('file') ? uri.toFilePath() : (uri.hasScheme ? uri.path : rawPath);

    if (uri.isScheme('file')) {
      final filePath = uri.toFilePath();
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          return await file.readAsString();
        }
      } catch (e, stackTrace) {
        _logger.severe('Failed to load file content from $filePath: $e', e, stackTrace);
        rethrow;
      }
      return null;
    }

    if (!uri.hasScheme) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return await file.readAsString();
        }
      } catch (e, stackTrace) {
        _logger.severe('Failed to load file content from $path: $e', e, stackTrace);
        rethrow;
      }
    }

    final candidateKeys = <String>[
      if (uri.pathSegments.length >= 2)
        '${uri.pathSegments[uri.pathSegments.length - 2]}/${uri.pathSegments.last}',
      if (uri.pathSegments.isNotEmpty) uri.pathSegments.last,
      path,
      rawPath,
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

    if (kIsWeb) {
      try {
        final mockJson = getSessionStorageItem('GINGA_PLAYGROUND_FILES');
        if (mockJson != null) {
          final mockFiles = jsonDecode(mockJson);
          final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : path;
          if (mockFiles.containsKey(fileName)) {
            return mockFiles[fileName];
          }
        }
      } catch (e) {
        _logger.warning('Failed to read playground files from session storage: $e');
      }
    }

    return null;
  }
}
