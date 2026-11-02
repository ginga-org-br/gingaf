import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gingacc/gingacc.dart';

class CatalogExample {
  final String key;
  final String mainFile;
  final String category;
  final String description;
  final List<String> otherEditableFiles;

  const CatalogExample({
    required this.key,
    required this.mainFile,
    this.category = 'general',
    this.description = '',
    this.otherEditableFiles = const [],
  });

  factory CatalogExample.fromJson(String key, Map<String, dynamic> json) {
    return CatalogExample(
      key: key,
      mainFile: json['mainFile'] as String? ?? key,
      category: json['category'] as String? ?? 'general',
      description: json['description'] as String? ?? '',
      otherEditableFiles: ((json['otherEditbleFiles'] ??
                  json['otherEditableFiles']) as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

List<CatalogExample> parseCatalog(dynamic jsonInput) {
  Map<String, dynamic> data;
  if (jsonInput is String) {
    try {
      data = jsonDecode(jsonInput) as Map<String, dynamic>;
    } catch (_) {
      return [];
    }
  } else if (jsonInput is Map<String, dynamic>) {
    data = jsonInput;
  } else if (jsonInput is Map) {
    data = Map<String, dynamic>.from(jsonInput);
  } else {
    return [];
  }

  final examplesMap = data['examples'];
  if (examplesMap is! Map) return [];

  final list = <CatalogExample>[];
  for (final entry in examplesMap.entries) {
    if (entry.value is Map) {
      list.add(CatalogExample.fromJson(
        entry.key.toString(),
        Map<String, dynamic>.from(entry.value as Map),
      ));
    }
  }
  return list;
}

Future<List<CatalogExample>> loadCatalogExamples({
  GingaCC? gingacc,
  Map<String, dynamic>? customCatalogData,
  String? catalogJsonContent,
}) async {
  if (customCatalogData != null) {
    return parseCatalog(customCatalogData);
  }
  if (catalogJsonContent != null) {
    return parseCatalog(catalogJsonContent);
  }

  if (gingacc != null) {
    try {
      final content = await gingacc.loadContent('examples/catalog.json') ??
          await gingacc.loadContent('catalog.json');
      if (content != null && content.isNotEmpty) {
        final parsed = parseCatalog(content);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}
  }

  if (!kIsWeb) {
    const candidatePaths = [
      'examples/catalog.json',
      'catalog.json',
      '../examples/catalog.json',
    ];
    for (final path in candidatePaths) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          final content = f.readAsStringSync();
          final parsed = parseCatalog(content);
          if (parsed.isNotEmpty) return parsed;
        }
      } catch (_) {}
    }
  }

  final fallbackCc = GingaCC();
  try {
    final content = await fallbackCc.loadContent('catalog.json') ??
        await fallbackCc.loadContent('examples/catalog.json');
    if (content != null && content.isNotEmpty) {
      final parsed = parseCatalog(content);
      if (parsed.isNotEmpty) return parsed;
    }
  } catch (_) {}

  return [];
}

Future<String?> loadExampleContent(
  String mainFile, {
  GingaCC? gingacc,
}) async {
  final cc = gingacc ?? GingaCC();
  try {
    final loaded = await cc.loadContent('examples/$mainFile') ??
        await cc.loadContent(mainFile);
    if (loaded != null && loaded.isNotEmpty) {
      return loaded;
    }
  } catch (_) {}

  if (!kIsWeb) {
    final paths = [
      'examples/$mainFile',
      mainFile,
      '../examples/$mainFile',
    ];
    for (final p in paths) {
      try {
        final f = File(p);
        if (f.existsSync()) {
          return f.readAsStringSync();
        }
      } catch (_) {}
    }
  }

  return null;
}
