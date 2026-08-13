import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:ncldoc/src_resolver.dart';

import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';

export 'package:ncldoc/src_resolver.dart' show BaseSrcResolver, SrcResolver;

final _logger = Logger('ginga');

class AssetsSrcResolver extends BaseSrcResolver {
  BuildContext? _context;

  AssetsSrcResolver();

  void setBuildContext(BuildContext context) {
    _context = context;
  }

  @override
  Uri resolveUri(String src, [String? baseDirSrc]) {
    var uri = super.resolveUri(src, baseDirSrc);
    if (kIsWeb && !uri.hasScheme && src.startsWith('/')) {
      uri = Uri.base.resolveUri(uri);
    }
    if (kIsWeb) {
      try {
        final mockFiles = getGingaAppFiles();
        if (mockFiles != null) {
          final fileName =
              uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.path;
          final rawSrc = uri.toString().trim();
          String? matchedValue;
          if (mockFiles.containsKey(fileName)) {
            matchedValue = mockFiles[fileName]?.toString();
          } else if (mockFiles.containsKey(uri.path)) {
            matchedValue = mockFiles[uri.path]?.toString();
          } else if (mockFiles.containsKey(rawSrc)) {
            matchedValue = mockFiles[rawSrc]?.toString();
          }

          if (matchedValue != null &&
              (matchedValue.startsWith('http://') ||
                  matchedValue.startsWith('https://') ||
                  matchedValue.startsWith('data:'))) {
            return Uri.tryParse(matchedValue) ?? uri;
          }
        }
      } catch (e) {
        _logger.warning('Failed to resolve mock uri: $e');
      }
    }
    return uri;
  }

  @override
  bool exists(Uri uri) {
    final rawSrc = uri.toString().trim();
    if (rawSrc.isEmpty || rawSrc.startsWith('<')) return false;

    if (kIsWeb) {
      try {
        final mockFiles = getGingaAppFiles();
        if (mockFiles != null) {
          final fileName =
              uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.path;
          if (mockFiles.containsKey(fileName) ||
              mockFiles.containsKey(uri.path) ||
              mockFiles.containsKey(rawSrc)) {
            return true;
          }
        }
      } catch (e) {
        _logger.warning('Failed to read files in exists: $e');
      }
    }

    if (super.exists(uri)) {
      return true;
    }

    return !uri.isScheme('file') && uri.path.isNotEmpty;
  }

  @override
  Future<String?> load(Uri uri) async {
    final rawSrc = uri.toString().trim();
    if (rawSrc.isEmpty) return null;

    if (kIsWeb) {
      try {
        final mockFiles = getGingaAppFiles();
        if (mockFiles != null) {
          final fileName =
              uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.path;
          if (mockFiles.containsKey(fileName)) {
            return mockFiles[fileName];
          }
          if (mockFiles.containsKey(uri.path)) {
            return mockFiles[uri.path];
          }
          if (mockFiles.containsKey(rawSrc)) {
            return mockFiles[rawSrc];
          }
        }
      } catch (e) {
        _logger.warning('Failed to read files: $e');
      }
    }

    try {
      final superContent = await super.load(uri);
      if (superContent != null) {
        return superContent;
      }
    } catch (_) {
      return null;
    }

    if (_context != null) {
      final path = uri.path;
      final candidateKeys = <String>[
        path,
        rawSrc,
        if (uri.pathSegments.length >= 2)
          '${uri.pathSegments[uri.pathSegments.length - 2]}/${uri.pathSegments.last}',
        if (uri.pathSegments.isNotEmpty) uri.pathSegments.last,
      ];
      for (final key in candidateKeys) {
        if (key.isEmpty) continue;
        if (key.startsWith('http://') || key.startsWith('https://')) continue;
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
