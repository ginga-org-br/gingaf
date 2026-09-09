import 'dart:convert';

import 'src_resolver.dart' as src_resolver;

class GingaConfig {
  static const List<String> supportedGroups = [
    'system.',
    'user.',
    'default.',
    'service.',
    'si.',
    'channel.',
    'shared.',
  ];

  String? appSrc;
  final String? mainAvSrc;
  String? usersDataSrc;
  final bool enableCCWS;
  final Map<String, String> envVariables;

  GingaConfig({
    this.appSrc,
    this.enableCCWS = true,
    this.usersDataSrc,
    this.mainAvSrc,
    Map<String, String>? envVariables,
  }) : envVariables = envVariables ?? {} {
    this.envVariables.putIfAbsent('system.language', () => 'por');
  }

  Map<String, String> getGroup(String group) {
    final prefix = group.endsWith('.') ? group : '$group.';
    final result = <String, String>{};
    for (final entry in envVariables.entries) {
      if (entry.key.startsWith(prefix)) {
        result[entry.key.substring(prefix.length)] = entry.value;
      }
    }
    return result;
  }

  static Future<GingaConfig> fromJson(
    String jsonOrSrc, [
    String? baseDirSrc,
  ]) async {
    final trimmed = jsonOrSrc.trim();
    if (trimmed.isEmpty) {
      return GingaConfig();
    }
    String jsonString;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      jsonString = trimmed;
    } else {
      final uri = src_resolver.resolveUri(trimmed, baseDirSrc);
      final loaded = (await src_resolver.loadContent(uri)) ??
          (await src_resolver.loadContent(trimmed));
      if (loaded == null) {
        throw FormatException('Failed to load GingaConfig from $jsonOrSrc');
      }
      jsonString = loaded.trim();
    }
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object for GingaConfig');
    }

    final Map<String, String> envVars = {};

    void extractFromMap(Map map, [String prefix = '']) {
      for (final entry in map.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        final fullKey = prefix.isEmpty ? key : '$prefix$key';
        if (value is Map) {
          extractFromMap(value, '$fullKey.');
        } else if (value != null) {
          envVars[fullKey] = value.toString();
        }
      }
    }

    final rawEnv = decoded['envVariables'] ??
        decoded['systemVariables'] ??
        decoded['systemProperties'];
    if (rawEnv is Map) {
      extractFromMap(rawEnv);
    }

    for (final group in supportedGroups) {
      final groupName = group.substring(0, group.length - 1);
      final val = decoded[groupName] ?? decoded[group];
      if (val is Map) {
        extractFromMap(val, group);
      }
    }

    for (final entry in decoded.entries) {
      final key = entry.key.toString();
      for (final group in supportedGroups) {
        if (key.startsWith(group) &&
            entry.value != null &&
            entry.value is! Map) {
          envVars[key] = entry.value.toString();
        }
      }
    }

    return GingaConfig(
      appSrc: (decoded['appSrc'] ?? decoded['app']) as String?,
      mainAvSrc: (decoded['mainAvSrc'] ?? decoded['mainAv']) as String?,
      usersDataSrc: (decoded['usersDataSrc'] ??
          decoded['usersData'] ??
          decoded['userDataSrc'] ??
          decoded['userData']) as String?,
      enableCCWS: (decoded['enableCCWS'] ?? decoded['ccws']) as bool? ?? true,
      envVariables: envVars.isNotEmpty ? envVars : null,
    );
  }

  @override
  String toString() {
    return 'GingaConfig(appSrc: $appSrc, mainAvSrc: $mainAvSrc, enableCCWS: $enableCCWS, usersDataSrc: $usersDataSrc, envVariables: $envVariables)';
  }
}

typedef NclDocConfig = GingaConfig;
typedef NclDocumentConfig = GingaConfig;
