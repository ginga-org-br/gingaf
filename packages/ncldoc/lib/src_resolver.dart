import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _logger = Logger('ncldoc');

Uri resolveUri(String src, [String? baseDirSrc]) {
  final rawSrc = src.trim();
  final srcUri = Uri.tryParse(rawSrc) ?? Uri(path: rawSrc);
  final baseUri = baseDirSrc != null ? Uri.tryParse(baseDirSrc) : null;
  return baseUri != null ? baseUri.resolveUri(srcUri) : srcUri;
}

File? resolveFile(Uri uri) {
  if (kIsWeb) return null;

  final rawSrc = uri.toString().trim();
  if (rawSrc.isEmpty || rawSrc.startsWith('<')) return null;

  final path = uri.isScheme('file')
      ? uri.toFilePath()
      : (uri.hasScheme ? uri.path : Uri.decodeComponent(uri.toString()));

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

bool exists(Uri uri) {
  final scheme = uri.scheme.toLowerCase();

  if (scheme == 'data' || scheme == 'http' || scheme == 'https') {
    return true;
  }

  if (kIsWeb) {
    return !uri.isScheme('file') && uri.path.isNotEmpty;
  }

  if (uri.isScheme('file')) {
    return resolveFile(uri) != null;
  }

  if (resolveFile(uri) != null) {
    return true;
  }

  return uri.path.isNotEmpty;
}

Future<String?> loadContent(dynamic srcOrUri) async {
  final Uri uri = srcOrUri is Uri ? srcOrUri : resolveUri(srcOrUri.toString());
  final rawSrc = uri.toString().trim();
  if (rawSrc.isEmpty) return null;

  final scheme = uri.scheme.toLowerCase();

  if (scheme == 'data') {
    return uri.data?.contentAsString();
  }

  if (scheme == 'http' || scheme == 'https') {
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return response.body;
      } else {
        _logger.warning(
            'HTTP request for $uri failed with status: ${response.statusCode}');
      }
    } catch (e) {
      _logger.warning('Failed to load remote HTTP URL ($uri): $e');
    }
    return null;
  }

  if (!kIsWeb) {
    final file = resolveFile(uri);
    if (file != null) {
      return await file.readAsString();
    }
  }

  return null;
}
