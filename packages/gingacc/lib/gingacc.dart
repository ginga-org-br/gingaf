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
    final Uri srcUri;
    if (rawSrc.startsWith('data:')) {
      srcUri = Uri.tryParse(rawSrc) ?? Uri.dataFromString(rawSrc);
    } else if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(rawSrc)) {
      srcUri = Uri.file(rawSrc);
    } else {
      srcUri = Uri.tryParse(rawSrc) ?? Uri(path: rawSrc);
    }

    if (baseDirSrc == null || baseDirSrc.isEmpty) {
      return srcUri;
    }

    final Uri baseUri;
    final trimmedBase = baseDirSrc.trim();
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(trimmedBase)) {
      baseUri = Uri.file(trimmedBase);
    } else {
      baseUri = Uri.tryParse(trimmedBase) ?? Uri(path: trimmedBase);
    }

    if (baseUri.isScheme('data')) {
      return srcUri;
    }

    return baseUri.resolveUri(srcUri);
  }

  Future<String?> loadContent(dynamic srcOrUri) async {
    final String rawInput =
        (srcOrUri is Uri ? srcOrUri.toString() : srcOrUri.toString()).trim();
    if (rawInput.isEmpty) return null;

    if (rawInput.startsWith('<')) {
      return rawInput;
    }

    if (rawInput.startsWith('data:')) {
      try {
        final uriData = UriData.parse(rawInput);
        return uriData.contentAsString();
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
    }

    final Uri uri = srcOrUri is Uri ? srcOrUri : resolveUri(rawInput);

    if (uri.isScheme('data')) {
      final dataStr = uri.data?.contentAsString();
      if (dataStr != null) return dataStr;
      final commaIndex = rawInput.indexOf(',');
      if (commaIndex != -1) {
        return Uri.decodeComponent(rawInput.substring(commaIndex + 1));
      }
    }

    if (virtualFiles != null) {
      final matched = _lookupVirtualFile(rawInput);
      if (matched != null) return matched;
      if (uri.hasScheme && uri.scheme == 'file') {
        try {
          final filePath = uri.toFilePath();
          final fileMatched = _lookupVirtualFile(filePath);
          if (fileMatched != null) return fileMatched;
        } catch (_) {}
      }
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          return response.body;
        }
      } catch (e) {
        return null;
      }
      return null;
    }

    if (scheme == 'file' || (!uri.hasScheme && !_isWeb)) {
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

  String? _lookupVirtualFile(String rawSrc) {
    if (virtualFiles == null) return null;
    final normalized = rawSrc.replaceAll('\\', '/');

    if (virtualFiles!.containsKey(rawSrc)) return virtualFiles![rawSrc];
    if (virtualFiles!.containsKey(normalized)) return virtualFiles![normalized];

    for (final entry in virtualFiles!.entries) {
      if (entry.key.replaceAll('\\', '/') == normalized) {
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

  File? resolveLocalFile(String src, [String? baseDirSrc]) {
    try {
      final uri = resolveUri(src, baseDirSrc);
      if (uri.isScheme('file')) {
        final file = File(uri.toFilePath());
        if (file.existsSync()) return file.absolute;
      }
    } catch (_) {}

    try {
      final directFile = File(src);
      if (directFile.existsSync()) return directFile.absolute;
    } catch (_) {}

    if (baseDirSrc != null) {
      try {
        final joined = File(path.join(baseDirSrc, src));
        if (joined.existsSync()) return joined.absolute;
      } catch (_) {}
    }

    try {
      final fileName = path.basename(src);
      if (fileName.isNotEmpty) {
        final baseNameFile = File(fileName);
        if (baseNameFile.existsSync()) return baseNameFile.absolute;
      }
    } catch (_) {}

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
