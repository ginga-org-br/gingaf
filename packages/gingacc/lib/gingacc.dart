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
    if (baseDirSrc == null || baseDirSrc.trim().isEmpty) {
      return srcUri;
    }

    final baseUri = _parseUri(baseDirSrc.trim());
    if (baseUri.isScheme('data')) {
      return srcUri;
    }

    final resolved = baseUri.resolveUri(srcUri);
    return _lookupVirtualUri(resolved.toString()) ?? resolved;
  }

  Future<String?> loadContent(dynamic srcOrUri) async {
    final String rawInput =
        (srcOrUri is Uri ? srcOrUri.toString() : srcOrUri.toString()).trim();
    if (rawInput.isEmpty) return null;

    if (rawInput.startsWith('<')) {
      return rawInput;
    }

    if (rawInput.startsWith('data:')) {
      return _decodeDataUri(rawInput);
    }

    final Uri uri = srcOrUri is Uri ? srcOrUri : resolveUri(rawInput);
    if (uri.isScheme('data')) {
      return _decodeDataUri(rawInput, uri);
    }

    if (virtualFiles != null) {
      final matched = _lookupVirtualFile(rawInput) ??
          (uri.isScheme('file') ? _lookupVirtualFile(uri.toFilePath()) : null);
      if (matched != null) {
        final parsedMatched = Uri.tryParse(matched);
        if (parsedMatched != null &&
            (parsedMatched.isScheme('http') ||
                parsedMatched.isScheme('https'))) {
          return await _fetchHttp(parsedMatched);
        }
        return matched;
      }
    }

    if (uri.isScheme('http') || uri.isScheme('https')) {
      return await _fetchHttp(uri);
    }

    if (uri.isScheme('file') || (!uri.hasScheme && !_isWeb)) {
      try {
        final filePath = uri.hasScheme ? uri.toFilePath() : rawInput;
        final file = File(filePath);
        if (file.existsSync()) {
          return await file.readAsString();
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  Uri _parseUri(String raw) {
    if (raw.startsWith('data:')) {
      return Uri.tryParse(raw) ?? Uri.dataFromString(raw);
    }
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(raw)) {
      return Uri.file(raw);
    }
    return Uri.tryParse(raw) ?? Uri(path: raw);
  }

  Uri? _lookupVirtualUri(String rawSrc) {
    if (virtualFiles == null) return null;
    final matched = _lookupVirtualFile(rawSrc);
    if (matched != null) {
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

    if (virtualFiles!.containsKey(rawSrc)) return virtualFiles![rawSrc];
    if (virtualFiles!.containsKey(clean)) return virtualFiles![clean];
    if (virtualFiles!.containsKey(normalized)) return virtualFiles![normalized];

    for (final entry in virtualFiles!.entries) {
      final k = entry.key.replaceAll('\\', '/');
      if (k == normalized ||
          normalized.endsWith('/$k') ||
          k.endsWith('/$normalized')) {
        return entry.value;
      }
    }

    final fileName = path.basename(normalized);
    for (final entry in virtualFiles!.entries) {
      if (path.basename(entry.key.replaceAll('\\', '/')) == fileName) {
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
