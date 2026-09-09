import 'dart:convert';

import 'gingacc.dart';

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
  static const String defaultMainAvSrc =
      "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4";
  static const String defaultMainAVSrc = defaultMainAvSrc;

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
  final String mainAvSrc;
  final bool enableCCWS;
  final bool enableMainAv;
  final Map<String, String> envVariables;
  final Users users;

  GingaConfig({
    this.appSrc,
    this.enableCCWS = false,
    this.enableMainAv = false,
    this.mainAvSrc = defaultMainAvSrc,
    Map<String, String>? envVariables,
    Users? users,
  })  : envVariables = {
          'system.language': 'por',
          ...?envVariables,
        },
        users = users ?? Users();

  GingaConfig copyWith({
    String? appSrc,
    String? mainAvSrc,
    bool? enableCCWS,
    bool? enableMainAv,
    Map<String, String>? envVariables,
    Users? users,
  }) {
    return GingaConfig(
      appSrc: appSrc ?? this.appSrc,
      mainAvSrc: mainAvSrc ?? this.mainAvSrc,
      enableCCWS: enableCCWS ?? this.enableCCWS,
      enableMainAv: enableMainAv ?? this.enableMainAv,
      envVariables: envVariables ?? this.envVariables,
      users: users ?? this.users,
    );
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
    GingaCC? gingacc,
  ]) async {
    gingacc ??= GingaCC();
    final trimmed = jsonOrSrc.trim();
    if (trimmed.isEmpty) {
      return GingaConfig();
    }
    String jsonString;
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      jsonString = trimmed;
    } else {
      final uri = gingacc.resolveUri(trimmed, baseDirSrc);
      final loaded = (await gingacc.loadContent(uri)) ??
          (await gingacc.loadContent(trimmed));
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
        final uri = gingacc.resolveUri(trimmedUsers, baseDirSrc);
        final loaded = (await gingacc.loadContent(uri)) ??
            (await gingacc.loadContent(trimmedUsers));
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
      mainAvSrc: decoded['mainAvSrc'] as String? ?? defaultMainAvSrc,
      enableCCWS: decoded['enableCCWS'] as bool? ?? true,
      enableMainAv: decoded['enableMainAv'] as bool? ?? true,
      envVariables: envVars,
      users: users,
    );
  }

  @override
  String toString() {
    return 'GingaConfig(appSrc: $appSrc, mainAvSrc: $mainAvSrc, enableCCWS: $enableCCWS, enableMainAv: $enableMainAv, envVariables: $envVariables, users: $users)';
  }
}
