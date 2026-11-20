import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'gingacc.dart';

const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');

Uri resolvePathUri(
  String src, {
  String? baseDirSrc,
  Uri? baseUri,
}) {
  final rawSrc = src.trim();
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
      : resolvePathUri(rawInput, baseDirSrc: baseDirSrc, baseUri: baseUri);
  if (uri.isScheme('data')) {
    return _decodeDataUri(rawInput, uri);
  }

  if (isHttpUri(uri)) {
    final res = await _fetchHttp(uri);
    if (res != null) return res;
  }

  if (_isWeb && !uri.hasScheme) {
    final webUri = Uri.base.resolveUri(uri);
    if (isHttpUri(webUri)) {
      final res = await _fetchHttp(webUri);
      if (res != null) return res;
    }
  }

  if (uri.isScheme('file') || (!uri.hasScheme && !_isWeb)) {
    final filePath =
        uri.isScheme('file') ? uri.toFilePath() : Uri.decodeComponent(uri.path);
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
      : resolvePathUri(rawInput, baseDirSrc: baseDirSrc, baseUri: baseUri);
  if (uri.isScheme('data')) {
    return _decodeDataUri(rawInput, uri);
  }

  if (uri.isScheme('file') || (!uri.hasScheme && !_isWeb)) {
    final filePath =
        uri.isScheme('file') ? uri.toFilePath() : Uri.decodeComponent(uri.path);
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        return file.readAsStringSync();
      }
    } catch (_) {}
  }

  return null;
}

Uint8List? loadPathBytesSync(
  dynamic srcOrUri, {
  String? baseDirSrc,
  Uri? baseUri,
}) {
  final String rawInput =
      (srcOrUri is Uri ? srcOrUri.toString() : srcOrUri.toString()).trim();
  if (rawInput.isEmpty) return null;

  if (rawInput.startsWith('data:')) {
    return _decodeDataUriBytes(rawInput);
  }

  final Uri uri = srcOrUri is Uri
      ? srcOrUri
      : resolvePathUri(rawInput, baseDirSrc: baseDirSrc, baseUri: baseUri);
  if (uri.isScheme('data')) {
    return _decodeDataUriBytes(rawInput, uri);
  }

  if (uri.isScheme('file') || (!uri.hasScheme && !_isWeb)) {
    final filePath =
        uri.isScheme('file') ? uri.toFilePath() : Uri.decodeComponent(uri.path);
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        return file.readAsBytesSync();
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
      try {
        return Uri.decodeComponent(dataPart);
      } catch (_) {
        return dataPart;
      }
    }
  }
  return null;
}

Uint8List? _decodeDataUriBytes(String rawInput, [Uri? uri]) {
  if (uri?.data != null) {
    return uri!.data!.contentAsBytes();
  }
  try {
    return UriData.parse(rawInput).contentAsBytes();
  } catch (_) {
    final commaIndex = rawInput.indexOf(',');
    if (commaIndex != -1) {
      final encodingPart = rawInput.substring(0, commaIndex);
      final dataPart = rawInput.substring(commaIndex + 1);
      if (encodingPart.contains(';base64')) {
        return Uint8List.fromList(base64.decode(dataPart));
      }
      try {
        return Uint8List.fromList(utf8.encode(Uri.decodeComponent(dataPart)));
      } catch (_) {
        return Uint8List.fromList(utf8.encode(dataPart));
      }
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

Future<Uint8List?> _fetchHttpBytes(Uri uri) async {
  try {
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
  } catch (_) {}
  return null;
}

class GingaAppContext {
  final String appContextId;
  final GingaCC? gingacc;
  final Map<String, String> _virtualFiles;
  Uri? baseUri;

  String get applicationId => appContextId;

  GingaAppContext({
    String? appContextId,
    String? applicationId,
    this.gingacc,
    Map<String, String>? virtualFiles,
    this.baseUri,
  })  : assert(appContextId != null || applicationId != null),
        appContextId = appContextId ?? applicationId!,
        _virtualFiles =
            virtualFiles != null ? Map<String, String>.from(virtualFiles) : {};

  GingaAppContext._scoped({
    required this.appContextId,
    required this.gingacc,
    required this.baseUri,
    required Map<String, String> sharedVirtualFiles,
  }) : _virtualFiles = sharedVirtualFiles;

  Map<String, String>? get virtualFiles =>
      _virtualFiles.isEmpty ? null : Map.unmodifiable(_virtualFiles);

  void setVirtualFiles(Map<String, String>? files) {
    _virtualFiles.clear();
    if (files != null) {
      _virtualFiles.addAll(files);
    }
  }

  void dispose() {
    _virtualFiles.clear();
  }

  GingaAppContext scoped({String? baseDir, Uri? baseUri}) {
    final effectiveBaseUri =
        baseUri ?? (baseDir != null ? resolveUri(baseDir) : this.baseUri);
    return GingaAppContext._scoped(
      appContextId: appContextId,
      gingacc: gingacc,
      baseUri: effectiveBaseUri,
      sharedVirtualFiles: _virtualFiles,
    );
  }

  Uri resolveUri(String src, [String? baseDirSrc]) => resolvePathUri(
        src,
        baseDirSrc: baseDirSrc,
        baseUri: baseUri,
      );

  static String _normalizePath(String raw) {
    var clean = raw.trim().split('?').first.split('#').first;
    if (clean.startsWith('http://') ||
        clean.startsWith('https://') ||
        clean.startsWith('file:')) {
      final parsed = Uri.tryParse(clean);
      if (parsed != null) {
        clean = parsed.isScheme('file') ? parsed.toFilePath() : parsed.path;
      }
    }
    try {
      clean = Uri.decodeComponent(clean);
    } catch (_) {}
    clean = clean.replaceAll('\\', '/');
    while (clean.startsWith('./')) {
      clean = clean.substring(2);
    }
    return clean;
  }

  String? _lookupVirtualFile(dynamic srcOrUri, [String? baseDirSrc]) {
    if (_virtualFiles.isEmpty) return null;
    final raw = srcOrUri.toString().trim();
    if (raw.isEmpty || isXmlString(raw) || raw.startsWith('data:')) {
      return null;
    }

    if (_virtualFiles.containsKey(raw)) return _virtualFiles[raw];
    final cleanRaw = _normalizePath(raw);
    if (_virtualFiles.containsKey(cleanRaw)) return _virtualFiles[cleanRaw];

    final Uri uri = srcOrUri is Uri ? srcOrUri : resolveUri(raw, baseDirSrc);
    final reqPath = _normalizePath(uri.toString());
    if (reqPath.isEmpty) return null;

    for (final entry in _virtualFiles.entries) {
      final keyPath = _normalizePath(entry.key);
      if (keyPath.isNotEmpty && reqPath == keyPath) {
        return entry.value;
      }
    }

    String? bestMatch;
    int bestLen = -1;
    for (final entry in _virtualFiles.entries) {
      final keyPath = _normalizePath(entry.key);
      if (keyPath.isEmpty ||
          keyPath.startsWith('/') ||
          RegExp(r'^[a-zA-Z]:/').hasMatch(keyPath)) {
        continue;
      }
      if (reqPath.endsWith('/$keyPath') && keyPath.length > bestLen) {
        bestLen = keyPath.length;
        bestMatch = entry.value;
      }
    }
    return bestMatch;
  }

  bool hasVirtualFile(dynamic srcOrUri, [String? baseDirSrc]) =>
      _lookupVirtualFile(srcOrUri, baseDirSrc) != null;

  Future<String?> loadContent(dynamic srcOrUri, [String? baseDirSrc]) async {
    final matched = _lookupVirtualFile(srcOrUri, baseDirSrc);
    if (matched != null) {
      if (matched.startsWith('data:')) {
        return _decodeDataUri(matched);
      }
      return matched;
    }
    return loadPathContent(
      srcOrUri,
      baseDirSrc: baseDirSrc,
      baseUri: baseUri,
    );
  }

  String? loadContentSync(dynamic srcOrUri, [String? baseDirSrc]) {
    final matched = _lookupVirtualFile(srcOrUri, baseDirSrc);
    if (matched != null) {
      if (matched.startsWith('data:')) {
        return _decodeDataUri(matched);
      }
      return matched;
    }
    return loadPathContentSync(
      srcOrUri,
      baseDirSrc: baseDirSrc,
      baseUri: baseUri,
    );
  }

  Uint8List? loadBytesSync(dynamic srcOrUri, [String? baseDirSrc]) {
    final matched = _lookupVirtualFile(srcOrUri, baseDirSrc);
    if (matched != null) {
      if (matched.startsWith('data:')) {
        return _decodeDataUriBytes(matched);
      }
      return Uint8List.fromList(utf8.encode(matched));
    }
    return loadPathBytesSync(
      srcOrUri,
      baseDirSrc: baseDirSrc,
      baseUri: baseUri,
    );
  }

  Future<Uint8List?> loadBytes(dynamic srcOrUri, [String? baseDirSrc]) async {
    final syncBytes = loadBytesSync(srcOrUri, baseDirSrc);
    if (syncBytes != null) return syncBytes;
    final rawInput =
        (srcOrUri is Uri ? srcOrUri.toString() : srcOrUri.toString()).trim();
    if (rawInput.isEmpty) return null;
    final uri = srcOrUri is Uri ? srcOrUri : resolveUri(rawInput, baseDirSrc);
    if (isHttpUri(uri)) {
      return await _fetchHttpBytes(uri);
    }
    if (_isWeb && !uri.hasScheme) {
      final webUri = Uri.base.resolveUri(uri);
      if (isHttpUri(webUri)) {
        return await _fetchHttpBytes(webUri);
      }
    }
    return null;
  }

  static bool _isExplicitFsPath(String raw) {
    final s = raw.trim();
    return s.startsWith('/') ||
        s.startsWith('file:') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(s);
  }

  bool existsOnDiskSync(String src, [String? baseDirSrc]) {
    if (_isWeb) return false;
    final clean = src.trim();
    if (clean.isEmpty || clean.startsWith('data:') || isHttpUri(clean)) {
      return false;
    }
    final uri = resolvePathUri(
      clean,
      baseDirSrc: baseDirSrc,
      baseUri: baseUri,
    );
    if (!uri.isScheme('file') && uri.hasScheme) return false;
    final filePath =
        uri.isScheme('file') ? uri.toFilePath() : Uri.decodeComponent(uri.path);
    try {
      return File(filePath).existsSync() || Directory(filePath).existsSync();
    } catch (_) {
      return false;
    }
  }

  bool writeBytesSync(
    String targetSrc,
    List<int> bytes, {
    String? baseDirSrc,
    String mimeType = 'application/octet-stream',
  }) {
    final cleanTarget = targetSrc.trim();
    if (cleanTarget.isEmpty) return false;

    final targetOnDisk = existsOnDiskSync(cleanTarget, baseDirSrc);
    final baseOnDisk = (baseDirSrc != null &&
            baseDirSrc.isNotEmpty &&
            existsOnDiskSync(baseDirSrc)) ||
        (baseUri != null && existsOnDiskSync(baseUri.toString()));
    final useVirtual = _isWeb ||
        isHttpUri(cleanTarget) ||
        hasVirtualFile(cleanTarget, baseDirSrc) ||
        (!targetOnDisk && !_isExplicitFsPath(cleanTarget) && !baseOnDisk);

    if (useVirtual) {
      final key = cleanTarget.replaceAll('\\', '/');
      final existingKey = _virtualFiles.keys.firstWhere(
        (k) => k.replaceAll('\\', '/') == key,
        orElse: () => key,
      );
      _virtualFiles[existingKey] =
          'data:$mimeType;base64,${base64.encode(bytes)}';
      return true;
    }

    final uri = resolvePathUri(
      cleanTarget,
      baseDirSrc: baseDirSrc,
      baseUri: baseUri,
    );
    if (!uri.isScheme('file') && uri.hasScheme) {
      return false;
    }
    final filePath =
        uri.isScheme('file') ? uri.toFilePath() : Uri.decodeComponent(uri.path);
    try {
      final file = File(filePath);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool existsSync(String src, [String? baseDirSrc]) {
    if (hasVirtualFile(src, baseDirSrc)) return true;
    return existsOnDiskSync(src, baseDirSrc);
  }

  String? _findVirtualFileKey(String targetSrc, [String? baseDirSrc]) {
    if (_virtualFiles.isEmpty) return null;
    final raw = targetSrc.trim();
    if (raw.isEmpty) return null;
    if (_virtualFiles.containsKey(raw)) return raw;
    final cleanRaw = _normalizePath(raw);
    if (_virtualFiles.containsKey(cleanRaw)) return cleanRaw;

    final uri = resolveUri(raw, baseDirSrc);
    final reqPath = _normalizePath(uri.toString());
    if (reqPath.isEmpty) return null;

    for (final key in _virtualFiles.keys) {
      final keyPath = _normalizePath(key);
      if (keyPath.isNotEmpty && (keyPath == cleanRaw || keyPath == reqPath)) {
        return key;
      }
    }

    String? bestKey;
    int bestLen = -1;
    for (final key in _virtualFiles.keys) {
      final keyPath = _normalizePath(key);
      if (keyPath.isEmpty ||
          keyPath.startsWith('/') ||
          RegExp(r'^[a-zA-Z]:/').hasMatch(keyPath)) {
        continue;
      }
      if (reqPath.endsWith('/$keyPath') && keyPath.length > bestLen) {
        bestLen = keyPath.length;
        bestKey = key;
      }
    }
    return bestKey;
  }

  bool removeEntrySync(String targetSrc, {String? baseDirSrc}) {
    final cleanTarget = targetSrc.trim();
    if (cleanTarget.isEmpty) return false;

    final virtualKey = _findVirtualFileKey(cleanTarget, baseDirSrc);
    if (virtualKey != null) {
      _virtualFiles.remove(virtualKey);
      return true;
    }

    if (_isWeb || isHttpUri(cleanTarget) || cleanTarget.startsWith('data:')) {
      return false;
    }

    final uri = resolvePathUri(
      cleanTarget,
      baseDirSrc: baseDirSrc,
      baseUri: baseUri,
    );
    if (!uri.isScheme('file') && uri.hasScheme) {
      return false;
    }
    final filePath =
        uri.isScheme('file') ? uri.toFilePath() : Uri.decodeComponent(uri.path);
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
        return true;
      }
      final dir = Directory(filePath);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
        return true;
      }
    } catch (_) {}
    return false;
  }

  List<String> listEntriesSync([String? subPath, String? baseDirSrc]) {
    final entries = <String>{};
    final rawSub = subPath?.trim() ?? '';
    final normalizedSub = rawSub.isEmpty
        ? ''
        : _normalizePath(rawSub).replaceAll(RegExp(r'/+$'), '');

    for (final key in _virtualFiles.keys) {
      final normKey = _normalizePath(key);
      if (normKey.isEmpty) continue;
      if (normalizedSub.isEmpty) {
        entries.add(normKey);
      } else if (normKey == normalizedSub) {
        entries.add(path.posix.basename(normKey));
      } else if (normKey.startsWith('$normalizedSub/')) {
        final remainder = normKey.substring(normalizedSub.length + 1);
        if (remainder.isNotEmpty) {
          entries.add(remainder);
        }
      }
    }

    if (!_isWeb) {
      final baseOnDisk = (baseDirSrc != null &&
              baseDirSrc.isNotEmpty &&
              existsOnDiskSync(baseDirSrc)) ||
          (baseUri != null && existsOnDiskSync(baseUri.toString()));
      Directory? targetDir;
      if (rawSub.isNotEmpty) {
        if (baseOnDisk || _isExplicitFsPath(rawSub)) {
          final uri = resolvePathUri(
            rawSub,
            baseDirSrc: baseDirSrc,
            baseUri: baseUri,
          );
          if (uri.isScheme('file') || !uri.hasScheme) {
            final fsPath = uri.isScheme('file')
                ? uri.toFilePath()
                : Uri.decodeComponent(uri.path);
            final candidate = Directory(fsPath);
            if (candidate.existsSync()) {
              targetDir = candidate;
            }
          }
        }
      } else if (baseOnDisk) {
        final uri = resolvePathUri(
          '.',
          baseDirSrc: baseDirSrc,
          baseUri: baseUri,
        );
        if (uri.isScheme('file') || !uri.hasScheme) {
          final fsPath = uri.isScheme('file')
              ? uri.toFilePath()
              : Uri.decodeComponent(uri.path);
          final candidate = Directory(fsPath);
          if (candidate.existsSync()) {
            targetDir = candidate;
          }
        }
      }

      if (targetDir != null) {
        try {
          for (final entity in targetDir.listSync()) {
            final name = path.basename(entity.path);
            if (name.startsWith('.')) continue;
            entries.add(name);
          }
        } catch (_) {}
      }
    }

    final sorted = entries.toList()..sort();
    return sorted;
  }
}
