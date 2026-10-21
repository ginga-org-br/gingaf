import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'gingacc.dart';

const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');

Uri resolvePathUri(
  String src, {
  String? baseDirSrc,
  Uri? baseUri,
  Map<String, String>? virtualFiles,
}) {
  final rawSrc = src.trim();
  final virtualUri = _lookupVirtualUri(rawSrc, virtualFiles);
  if (virtualUri != null) return virtualUri;

  final srcUri = _parseUri(rawSrc);
  final effectiveBaseDir = (baseDirSrc != null && !isXmlString(baseDirSrc))
      ? baseDirSrc.trim()
      : baseUri?.toString();
  if (effectiveBaseDir == null || effectiveBaseDir.isEmpty) {
    if (!_isWeb && !srcUri.hasScheme) {
      final decoded = Uri.decodeComponent(srcUri.path);
      return File(path.normalize(decoded)).absolute.uri;
    }
    if (_isWeb && !srcUri.hasScheme) {
      return Uri.base.resolveUri(srcUri);
    }
    return srcUri;
  }

  Uri resolvedBaseUri = _parseUri(effectiveBaseDir);
  if (resolvedBaseUri.isScheme('data')) {
    if (!_isWeb && !srcUri.hasScheme) {
      final decoded = Uri.decodeComponent(srcUri.path);
      return File(path.normalize(decoded)).absolute.uri;
    }
    if (_isWeb && !srcUri.hasScheme) {
      return Uri.base.resolveUri(srcUri);
    }
    return srcUri;
  }

  if (!_isWeb) {
    if (resolvedBaseUri.isScheme('file')) {
      final filePath = resolvedBaseUri.toFilePath();
      bool isDir = false;
      try {
        isDir = Directory(filePath).existsSync();
      } catch (_) {}
      if (isDir && !resolvedBaseUri.path.endsWith('/')) {
        resolvedBaseUri = Uri.directory(filePath);
      }
    } else if (!resolvedBaseUri.hasScheme) {
      final decodedBase = Uri.decodeComponent(resolvedBaseUri.path);
      bool isDir = decodedBase.endsWith('/') || decodedBase.endsWith('\\');
      if (!isDir) {
        try {
          isDir = Directory(decodedBase).existsSync();
        } catch (_) {}
      }
      if (isDir) {
        resolvedBaseUri = Directory(decodedBase).absolute.uri;
      } else {
        resolvedBaseUri = File(decodedBase).absolute.uri;
      }
    }
  } else {
    if (!resolvedBaseUri.hasScheme) {
      resolvedBaseUri = Uri.base.resolveUri(resolvedBaseUri);
    }
  }

  final resolved = resolvedBaseUri.resolveUri(srcUri);
  final virtualResolved =
      _lookupVirtualUri(resolved.toString(), virtualFiles);
  if (virtualResolved != null) return virtualResolved;

  if (!_isWeb && !resolved.hasScheme) {
    final decoded = Uri.decodeComponent(resolved.path);
    return File(path.normalize(decoded)).absolute.uri;
  }
  if (_isWeb && !resolved.hasScheme) {
    return Uri.base.resolveUri(resolved);
  }
  return resolved;
}

Future<String?> loadPathContent(
  dynamic srcOrUri, {
  String? baseDirSrc,
  Uri? baseUri,
  Map<String, String>? virtualFiles,
}) async {
  final String rawInput =
      (srcOrUri is Uri ? srcOrUri.toString() : srcOrUri.toString()).trim();
  if (rawInput.isEmpty) return null;

  if (isXmlString(rawInput)) {
    return rawInput;
  }

  if (rawInput.startsWith('data:')) {
    return _decodeDataUri(rawInput);
  }

  final Uri uri = srcOrUri is Uri
      ? srcOrUri
      : resolvePathUri(rawInput,
          baseDirSrc: baseDirSrc,
          baseUri: baseUri,
          virtualFiles: virtualFiles);
  if (uri.isScheme('data')) {
    return _decodeDataUri(rawInput, uri);
  }

  if (virtualFiles != null && virtualFiles.isNotEmpty) {
    final matched = _lookupVirtualFile(rawInput, virtualFiles) ??
        (uri.isScheme('file')
            ? _lookupVirtualFile(uri.toFilePath(), virtualFiles)
            : null) ??
        _lookupVirtualFile(uri.path, virtualFiles) ??
        (uri.pathSegments.isNotEmpty
            ? _lookupVirtualFile(uri.pathSegments.last, virtualFiles)
            : null);
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

  if (_isWeb && !uri.hasScheme) {
    final webUri = Uri.base.resolveUri(uri);
    if (isHttpUri(webUri)) {
      return await _fetchHttp(webUri);
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

String? loadPathContentSync(
  dynamic srcOrUri, {
  String? baseDirSrc,
  Uri? baseUri,
  Map<String, String>? virtualFiles,
}) {
  final String rawInput =
      (srcOrUri is Uri ? srcOrUri.toString() : srcOrUri.toString()).trim();
  if (rawInput.isEmpty) return null;

  if (isXmlString(rawInput)) {
    return rawInput;
  }

  if (rawInput.startsWith('data:')) {
    return _decodeDataUri(rawInput);
  }

  final Uri uri = srcOrUri is Uri
      ? srcOrUri
      : resolvePathUri(rawInput,
          baseDirSrc: baseDirSrc,
          baseUri: baseUri,
          virtualFiles: virtualFiles);
  if (uri.isScheme('data')) {
    return _decodeDataUri(rawInput, uri);
  }

  if (virtualFiles != null && virtualFiles.isNotEmpty) {
    final matched = _lookupVirtualFile(rawInput, virtualFiles) ??
        (uri.isScheme('file')
            ? _lookupVirtualFile(uri.toFilePath(), virtualFiles)
            : null) ??
        _lookupVirtualFile(uri.path, virtualFiles) ??
        (uri.pathSegments.isNotEmpty
            ? _lookupVirtualFile(uri.pathSegments.last, virtualFiles)
            : null);
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

Uri? _lookupVirtualUri(String rawSrc, Map<String, String>? virtualFiles) {
  if (virtualFiles == null || virtualFiles.isEmpty) return null;
  final matched = _lookupVirtualFile(rawSrc, virtualFiles);
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

String? _lookupVirtualFile(
    String rawSrc, Map<String, String>? virtualFiles) {
  if (virtualFiles == null || virtualFiles.isEmpty) return null;
  final clean = rawSrc.trim().split('?')[0].split('#')[0];
  final normalized = clean.replaceAll('\\', '/');
  final decodedNormalized = Uri.decodeComponent(normalized);

  if (virtualFiles.containsKey(rawSrc)) return virtualFiles[rawSrc];
  if (virtualFiles.containsKey(clean)) return virtualFiles[clean];
  if (virtualFiles.containsKey(normalized)) return virtualFiles[normalized];
  if (virtualFiles.containsKey(decodedNormalized)) {
    return virtualFiles[decodedNormalized];
  }

  for (final entry in virtualFiles.entries) {
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
  for (final entry in virtualFiles.entries) {
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

class GingaAppPrivateBase {
  final String applicationId;
  final GingaCC? gingacc;
  final Map<String, String> _virtualFiles = {};
  Uri? baseUri;

  GingaAppPrivateBase({
    required this.applicationId,
    this.gingacc,
    Map<String, String>? virtualFiles,
    this.baseUri,
  }) {
    if (virtualFiles != null) {
      _virtualFiles.addAll(virtualFiles);
    }
  }

  Map<String, String>? get virtualFiles =>
      _virtualFiles.isEmpty ? null : Map.unmodifiable(_virtualFiles);

  void setVirtualFiles(Map<String, String>? files) {
    _virtualFiles.clear();
    if (files != null) {
      _virtualFiles.addAll(files);
    }
  }

  GingaAppPrivateBase scoped({String? baseDir, Uri? baseUri}) {
    final effectiveBaseUri =
        baseUri ?? (baseDir != null ? resolveUri(baseDir) : this.baseUri);
    return GingaAppPrivateBase(
      applicationId: applicationId,
      gingacc: gingacc,
      virtualFiles: _virtualFiles,
      baseUri: effectiveBaseUri,
    );
  }

  Uri resolveUri(String src, [String? baseDirSrc]) => resolvePathUri(
        src,
        baseDirSrc: baseDirSrc,
        baseUri: baseUri,
        virtualFiles: _virtualFiles,
      );

  Future<String?> loadContent(dynamic srcOrUri, [String? baseDirSrc]) =>
      loadPathContent(
        srcOrUri,
        baseDirSrc: baseDirSrc,
        baseUri: baseUri,
        virtualFiles: _virtualFiles,
      );

  String? loadContentSync(dynamic srcOrUri, [String? baseDirSrc]) =>
      loadPathContentSync(
        srcOrUri,
        baseDirSrc: baseDirSrc,
        baseUri: baseUri,
        virtualFiles: _virtualFiles,
      );
}
