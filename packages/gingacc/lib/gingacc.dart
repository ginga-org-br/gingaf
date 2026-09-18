import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'ccws.dart';
import 'ginga_config.dart';

export 'ccws.dart';
export 'ginga_config.dart';
export 'users.dart';

const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');

bool isHttpUri(Object? source) {
  if (source is Uri) {
    return source.isScheme('http') || source.isScheme('https');
  }
  if (source is String) {
    return source.startsWith('http://') || source.startsWith('https://');
  }
  return false;
}

bool isXmlString(String? src) {
  if (src == null) return false;
  return src.trim().startsWith('<');
}

class GingaCC {
  final GingaConfig config;
  final CCWS ccws;
  final Map<String, String>? virtualFiles;

  GingaCC({
    GingaConfig? config,
    this.virtualFiles,
    CCWS? ccws,
  })  : config = config ?? GingaConfig(),
        ccws = ccws ?? CCWS();

  Uri resolveUri(String src, [String? baseDirSrc]) {
    final rawSrc = src.trim();
    final virtualUri = _lookupVirtualUri(rawSrc);
    if (virtualUri != null) return virtualUri;

    final srcUri = _parseUri(rawSrc);
    final effectiveBaseDir =
        (baseDirSrc != null && !isXmlString(baseDirSrc))
            ? baseDirSrc.trim()
            : null;
    if (effectiveBaseDir == null || effectiveBaseDir.isEmpty) {
      if (!_isWeb && !srcUri.hasScheme) {
        final decoded = Uri.decodeComponent(srcUri.path);
        return File(path.normalize(decoded)).absolute.uri;
      }
      return srcUri;
    }

    Uri baseUri = _parseUri(effectiveBaseDir);
    if (baseUri.isScheme('data')) {
      if (!_isWeb && !srcUri.hasScheme) {
        final decoded = Uri.decodeComponent(srcUri.path);
        return File(path.normalize(decoded)).absolute.uri;
      }
      return srcUri;
    }

    if (!_isWeb) {
      if (baseUri.isScheme('file')) {
        final filePath = baseUri.toFilePath();
        if (Directory(filePath).existsSync() && !baseUri.path.endsWith('/')) {
          baseUri = Uri.directory(filePath);
        }
      } else if (!baseUri.hasScheme) {
        final decodedBase = Uri.decodeComponent(baseUri.path);
        final isDir = decodedBase.endsWith('/') ||
            decodedBase.endsWith('\\') ||
            Directory(decodedBase).existsSync();
        if (isDir) {
          baseUri = Directory(decodedBase).absolute.uri;
        } else {
          baseUri = File(decodedBase).absolute.uri;
        }
      }
    }

    final resolved = baseUri.resolveUri(srcUri);
    final virtualResolved = _lookupVirtualUri(resolved.toString());
    if (virtualResolved != null) return virtualResolved;

    if (!_isWeb && !resolved.hasScheme) {
      final decoded = Uri.decodeComponent(resolved.path);
      return File(path.normalize(decoded)).absolute.uri;
    }
    return resolved;
  }

  Future<String?> loadContent(dynamic srcOrUri, [String? baseDirSrc]) async {
    final String rawInput =
        (srcOrUri is Uri ? srcOrUri.toString() : srcOrUri.toString()).trim();
    if (rawInput.isEmpty) return null;

    if (isXmlString(rawInput)) {
      return rawInput;
    }

    if (rawInput.startsWith('data:')) {
      return _decodeDataUri(rawInput);
    }

    final Uri uri =
        srcOrUri is Uri ? srcOrUri : resolveUri(rawInput, baseDirSrc);
    if (uri.isScheme('data')) {
      return _decodeDataUri(rawInput, uri);
    }

    if (virtualFiles != null) {
      final matched = _lookupVirtualFile(rawInput) ??
          (uri.isScheme('file') ? _lookupVirtualFile(uri.toFilePath()) : null);
      if (matched != null) {
        final parsedMatched = Uri.tryParse(matched);
        if (parsedMatched != null && isHttpUri(parsedMatched)) {
          return await _fetchHttp(parsedMatched);
        }
        return matched;
      }
    }

    if (isHttpUri(uri)) {
      return await _fetchHttp(uri);
    }

    if (uri.isScheme('file') || (!uri.hasScheme && !_isWeb)) {
      final filePath = uri.isScheme('file')
          ? uri.toFilePath()
          : Uri.decodeComponent(uri.path);
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          return file.readAsStringSync();
        }
      } catch (_) {}
    }

    return null;
  }

  String? loadContentSync(dynamic srcOrUri, [String? baseDirSrc]) {
    final String rawInput =
        (srcOrUri is Uri ? srcOrUri.toString() : srcOrUri.toString()).trim();
    if (rawInput.isEmpty) return null;

    if (isXmlString(rawInput)) {
      return rawInput;
    }

    if (rawInput.startsWith('data:')) {
      return _decodeDataUri(rawInput);
    }

    final Uri uri =
        srcOrUri is Uri ? srcOrUri : resolveUri(rawInput, baseDirSrc);
    if (uri.isScheme('data')) {
      return _decodeDataUri(rawInput, uri);
    }

    if (virtualFiles != null) {
      final matched = _lookupVirtualFile(rawInput) ??
          (uri.isScheme('file') ? _lookupVirtualFile(uri.toFilePath()) : null);
      if (matched != null) {
        return matched;
      }
    }

    if (uri.isScheme('file') || (!uri.hasScheme && !_isWeb)) {
      final filePath = uri.isScheme('file')
          ? uri.toFilePath()
          : Uri.decodeComponent(uri.path);
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          return file.readAsStringSync();
        }
      } catch (_) {}
    }

    return null;
  }


  Uri _parseUri(String raw) {
    if (raw.startsWith('data:')) {
      return Uri.tryParse(raw) ?? Uri.dataFromString(raw);
    }
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(raw)) {
      if (!_isWeb && Directory(raw).existsSync()) {
        return Uri.directory(raw);
      }
      return Uri.file(raw);
    }
    return Uri.tryParse(raw) ?? Uri(path: raw);
  }

  Uri? _lookupVirtualUri(String rawSrc) {
    if (virtualFiles == null) return null;
    final matched = _lookupVirtualFile(rawSrc);
    if (matched != null) {
      if (matched.startsWith('data:')) {
        return Uri.tryParse(matched) ?? Uri.dataFromString(matched);
      }
      final parsed = Uri.tryParse(matched);
      if (parsed != null &&
          (parsed.isScheme('http') ||
              parsed.isScheme('https') ||
              parsed.isScheme('blob') ||
              parsed.isScheme('data') ||
              parsed.isScheme('file'))) {
        return parsed;
      }
    }
    return null;
  }

  String? _decodeDataUri(String rawInput, [Uri? uri]) {
    if (uri?.data != null) {
      final content = uri!.data!.contentAsString();
      if (content.isNotEmpty) return content;
    }
    try {
      return UriData.parse(rawInput).contentAsString();
    } catch (_) {
      final commaIndex = rawInput.indexOf(',');
      if (commaIndex != -1) {
        final encodingPart = rawInput.substring(0, commaIndex);
        final dataPart = rawInput.substring(commaIndex + 1);
        if (encodingPart.contains(';base64')) {
          return utf8.decode(base64.decode(dataPart));
        }
        return Uri.decodeComponent(dataPart);
      }
    }
    return null;
  }

  Future<String?> _fetchHttp(Uri uri) async {
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (_) {}
    return null;
  }

  String? _lookupVirtualFile(String rawSrc) {
    if (virtualFiles == null) return null;
    final clean = rawSrc.trim().split('?')[0].split('#')[0];
    final normalized = clean.replaceAll('\\', '/');
    final decodedNormalized = Uri.decodeComponent(normalized);

    if (virtualFiles!.containsKey(rawSrc)) return virtualFiles![rawSrc];
    if (virtualFiles!.containsKey(clean)) return virtualFiles![clean];
    if (virtualFiles!.containsKey(normalized)) return virtualFiles![normalized];
    if (virtualFiles!.containsKey(decodedNormalized)) {
      return virtualFiles![decodedNormalized];
    }

    for (final entry in virtualFiles!.entries) {
      final k = entry.key.replaceAll('\\', '/');
      final decodedK = Uri.decodeComponent(k);
      if (k == normalized ||
          k == decodedNormalized ||
          decodedK == normalized ||
          decodedK == decodedNormalized ||
          normalized.endsWith('/$k') ||
          normalized.endsWith('/$decodedK') ||
          decodedNormalized.endsWith('/$k') ||
          decodedNormalized.endsWith('/$decodedK') ||
          k.endsWith('/$normalized') ||
          k.endsWith('/$decodedNormalized') ||
          decodedK.endsWith('/$normalized') ||
          decodedK.endsWith('/$decodedNormalized')) {
        return entry.value;
      }
    }

    final fileName = path.basename(normalized);
    final decodedFileName = path.basename(decodedNormalized);
    for (final entry in virtualFiles!.entries) {
      final k = entry.key.replaceAll('\\', '/');
      final entryBase = path.basename(k);
      final decodedEntryBase = path.basename(Uri.decodeComponent(k));
      if (entryBase == fileName ||
          entryBase == decodedFileName ||
          decodedEntryBase == fileName ||
          decodedEntryBase == decodedFileName) {
        return entry.value;
      }
    }

    return null;
  }

  Future<void> start() async {
    if (config.startWithCCWS) {
      await ccws.start();
    }
  }

  Future<void> stop() async {
    if (ccws.isRunning) {
      await ccws.stop();
    }
  }
}
