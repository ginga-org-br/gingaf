import 'dart:convert';

import 'src_resolver.dart' as src_resolver;
import 'users.dart';

/// Ginga environment configuration.
///
/// Example configuration JSON:
/// ```json
/// {
///   "appSrc": "main.ncl",
///   "mainAvSrc": "video.mp4",
///   "enableCCWS": true,
///   "envVariables": {
///     "system.language": "por",
///     "user.age": "30",
///     "default.font": "sans",
///     "service.id": "1",
///     "si.ts": "2",
///     "channel.num": "10",
///     "shared.key": "val"
///   },
///   "usersDataJson": [
///     {
///       "id": "u1",
///       "name": "User 1",
///       "properties": {
///         "age": 30,
///         "closedCaptioning": true
///       }
///     }
///   ]
/// }
/// ```
///
/// Note: `"usersDataJson"` can also be a URI or file path string pointing to a JSON file (e.g. `"usersDataJson": "users.json"`).
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
  final bool enableCCWS;
  final Map<String, String> envVariables;
  final Users users;

  GingaConfig({
    this.appSrc,
    this.enableCCWS = true,
    this.mainAvSrc,
    Map<String, String>? envVariables,
    Users? users,
  })  : envVariables = {
          'system.language': 'por',
          ...?envVariables,
        },
        users = users ?? Users();

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
    final sanitizedJson = jsonString
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    final dynamic decoded = jsonDecode(sanitizedJson);
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

    final rawEnv = decoded['envVariables'];
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

    final users = Users();
    final usersObj = decoded['usersDataJson'];
    if (usersObj is String) {
      final trimmedUsers = usersObj.trim();
      if (trimmedUsers.startsWith('{') || trimmedUsers.startsWith('[')) {
        users.loadUserData(trimmedUsers);
      } else {
        final uri = src_resolver.resolveUri(trimmedUsers, baseDirSrc);
        final loaded = (await src_resolver.loadContent(uri)) ??
            (await src_resolver.loadContent(trimmedUsers));
        if (loaded != null && loaded.isNotEmpty) {
          users.loadUserData(loaded);
        }
      }
    } else if (usersObj is List) {
      users.importUsers(usersObj);
    } else if (usersObj is Map<String, dynamic>) {
      users.loadUserData(jsonEncode(usersObj));
    } else if (usersObj is Map) {
      users.loadUserData(jsonEncode(Map<String, dynamic>.from(usersObj)));
    }

    return GingaConfig(
      appSrc: decoded['appSrc'] as String?,
      mainAvSrc: decoded['mainAvSrc'] as String?,
      enableCCWS: decoded['enableCCWS'] as bool? ?? true,
      envVariables: envVars,
      users: users,
    );
  }

  @override
  String toString() {
    return 'GingaConfig(appSrc: $appSrc, mainAvSrc: $mainAvSrc, enableCCWS: $enableCCWS, envVariables: $envVariables, users: $users)';
  }
}
